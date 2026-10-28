-- Clones Unit resources and adds their aliases to the same packages that load the
-- original. All outputs are new, editor-owned triad patches, not changed originals.
local ffi=require('ffi')
local bit=require('bit')
local D=require('demolition')
local I=require('install')
local M={}
local UTYPE,PTYPE=D.hash_resource('unit'),D.hash_resource('package')
local p32,u32=D.p32,D.u32
local function p64(v)return p32(v%4294967296)..p32(math.floor(v/4294967296))end
local function u64(s,o)
    local lo,hi=u32(s,o),u32(s,o+4)
    assert(hi<=2097151,'asset offset too large');return lo+hi*4294967296
end
local function align(n,a)return n+(a-n%a)%a end
local function replace(s,o,b)return s:sub(1,o)..b..s:sub(o+#b+1)end
local function read(p)return I.read(p)end
local function write(p,s)local f=assert(io.open(p,'wb'));assert(f:write(s));f:close()end
local function keys(t)local a={};for k in pairs(t)do a[#a+1]=k end;table.sort(a);return a end

function M.patch_package(s,aliases)
    assert(#s>=16,'package header is truncated')
    local n=u32(s,8);assert(n<=1000000 and 16+n*16<=#s,'package dependency array is invalid')
    local present,extra={},{}
    for i=0,n-1 do present[s:sub(17+i*16,32+i*16)]=true end
    for i=0,n-1 do
        local at=16+i*16
        if s:sub(at+1,at+8)==UTYPE then
            local source=s:sub(at+9,at+16)
            for _,alias in ipairs(aliases[source]or{})do
                local item=UTYPE..alias
                if not present[item]then extra[#extra+1]=item;present[item]=true end
            end
        end
    end
    if #extra==0 then return nil,0 end
    table.sort(extra)
    return replace(s:sub(1,16+n*16),8,p32(n+#extra))..table.concat(extra)..s:sub(17+n*16),#extra
end

function M.archive(resources)
    local ids,types={},{}
    for _,r in ipairs(resources)do
        assert(#r.name==8 and #r.type==8 and type(r.main)=='string','invalid patch resource')
        local id=r.name..r.type;assert(not ids[id],'duplicate patch resource');ids[id]=true
        types[r.type]=(types[r.type]or 0)+1
    end
    table.sort(resources,function(a,b)return D.hex(a.name)..D.hex(a.type)<D.hex(b.name)..D.hex(b.type)end)
    local typeids=keys(types)
    local data_at=align(72+#typeids*32+#resources*80,16)
    local main_at,gpu_at,stream_at,pool= data_at,0,0,0
    local records,body,gpu,stream={},{},{},{}
    for index,r in ipairs(resources)do
        local gs,ss=r.gpu or'',r.stream or''
        local ma,ga,sa,pa=align(main_at,16),align(gpu_at,256),align(stream_at,16),align(pool,16)
        records[#records+1]=r.name..r.type..p64(ma)..p64(sa)..p64(ga)..p64(pa)..p64(ga)
            ..p32(#r.main)..p32(#ss)..p32(#gs)..p32(16)..p32(256)..p32(index-1)
        body[#body+1]=string.rep('\0',ma-main_at)..r.main
        gpu[#gpu+1]=string.rep('\0',ga-gpu_at)..gs
        stream[#stream+1]=string.rep('\0',sa-stream_at)..ss
        main_at,gpu_at,stream_at,pool=ma+#r.main,ga+#gs,sa+#ss,pa+#r.main
    end
    local header=p32(0xF0000011)..p32(#typeids)..p32(#resources)..string.rep('\0',20)
        ..p64(align(pool,256))..p64(align(gpu_at,256))..string.rep('\0',24)
    local ti={}
    for _,typ in ipairs(typeids)do ti[#ti+1]=p32(0)..p32(0)..typ..p32(types[typ])..p32(0)..p32(16)..p32(256)end
    local prefix=header..table.concat(ti)..table.concat(records)
    assert(#header==72 and #prefix<=data_at,'archive metadata size differs')
    return {main=prefix..string.rep('\0',data_at-#prefix)..table.concat(body),
        gpu=table.concat(gpu),stream=table.concat(stream)}
end

function M.read_archive(main,gpu,stream)
    assert(#main>=72 and u32(main,0)==0xF0000011,'unsupported triad patch format')
    local nt,n=u32(main,4),u32(main,8)
    assert(nt<=10000 and n<=1000000 and 72+nt*32+n*80<=#main,'invalid triad directory')
    local out={}
    for i=0,n-1 do
        local at=72+nt*32+i*80
        local name,typ=main:sub(at+1,at+8),main:sub(at+9,at+16)
        local mo,so,go=u64(main,at+16),u64(main,at+24),u64(main,at+32)
        local mn,sn,gn=u32(main,at+56),u32(main,at+60),u32(main,at+64)
        assert(mo+mn<=#main and so+sn<=#(stream or'') and go+gn<=#(gpu or''),'truncated triad resource')
        out[name..typ]={name=name,type=typ,main=main:sub(mo+1,mo+mn),
            stream=(stream or''):sub(so+1,so+sn),gpu=(gpu or''):sub(go+1,go+gn)}
    end
    return out
end

-- extracted: archive ID -> {units = {source hash -> resource}, packages = {hash -> resource}}
function M.plan(requests,extracted,choose_name)
    local aliases={}
    for _,r in ipairs(requests)do
        local source,alias=D.unhex(r.source_unit),D.unhex(r.alias_unit)
        aliases[source]=aliases[source]or{};table.insert(aliases[source],alias)
    end
    local writes,report,loaded_alias,copied_alias={}, {},{},{}
    local wanted_alias={}
    for _,r in ipairs(requests)do wanted_alias[D.unhex(r.alias_unit)]=true end
    for _,archive in ipairs(keys(extracted))do
        assert(archive:match('^%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x$'),'invalid source archive')
        local src=extracted[archive];local resources={};local included={}
        for source,list in pairs(aliases)do
            local r=src.units[source]
            if r then
                for _,alias in ipairs(list)do
                    resources[#resources+1]={name=alias,type=UTYPE,main=r.main,gpu=r.gpu,stream=r.stream}
                    included[alias]=true
                    copied_alias[alias]=true
                end
            end
        end
        local changed_packages=0
        for key,r in pairs(src.packages)do
            local s,n=M.patch_package(r.main,aliases)
            if s then
                resources[#resources+1]={name=key,type=PTYPE,main=s}
                changed_packages=changed_packages+1
                local count=u32(s,8)
                for i=0,count-1 do
                    local at=16+i*16
                    if s:sub(at+1,at+8)==UTYPE then
                        local alias=s:sub(at+9,at+16)
                        if wanted_alias[alias]then loaded_alias[alias]=true end
                    end
                end
            end
        end
        if #resources>0 then
            local name=choose_name(archive)
            assert(name:match('^'..archive..'%.patch_%d+$'),'invalid alias patch filename')
            local a=M.archive(resources)
            local back=M.read_archive(a.main,a.gpu,a.stream)
            for _,r in ipairs(resources)do
                local b=assert(back[r.name..r.type]);assert(b.main==r.main and b.gpu==(r.gpu or'')and b.stream==(r.stream or''),'patch read-back differs')
            end
            writes[name]=a.main
            if #a.gpu>0 then writes[name..'.gpu_resources']=a.gpu end
            if #a.stream>0 then writes[name..'.stream']=a.stream end
            report[#report+1]={archive=archive,name=name,resources=#resources,packages=changed_packages}
        end
    end
    for _,r in ipairs(requests)do
        assert(copied_alias[D.unhex(r.alias_unit)],'No Unit resource was cloned for entity '..r.entity)
        assert(loaded_alias[D.unhex(r.alias_unit)],'No package was found that loads the Unit alias for entity '..r.entity)
    end
    return writes,report
end

-- Run Filediver directly, without cmd.exe or a visible console. A cancellation leaves
-- only exported cache files; the caller has not written any game files at this point.
for _,decl in ipairs({
    'typedef struct { uint32_t n; void *descriptor; int inherit; } demo_security;',
    'typedef struct { uint32_t n; void *reserved; void *desktop; void *title; uint32_t x,y,w,h,cx,cy,fill,flags; uint16_t show,cb; void *reserved2; void *input; void *output; void *error; } demo_startup;',
    'typedef struct { void *process; void *thread; uint32_t pid,tid; } demo_process;',
    'int CreateProcessW(const uint16_t *app,uint16_t *command,void *pa,void *ta,int inherit,uint32_t flags,void *env,const uint16_t *cwd,demo_startup *startup,demo_process *process);',
    'void *CreateFileW(const uint16_t *name,uint32_t access,uint32_t sharing,demo_security *sa,uint32_t creation,uint32_t attributes,void *template_);',
    'uint32_t WaitForSingleObject(void *handle,uint32_t milliseconds);',
    'int GetExitCodeProcess(void *process,uint32_t *exit_code);',
    'int TerminateProcess(void *process,uint32_t exit_code);',
    'uint64_t GetTickCount64(void);',
    'int MultiByteToWideChar(uint32_t page,uint32_t flags,const char *text,int size,uint16_t *out,int count);',
})do pcall(ffi.cdef,decl)end
local function wide(s)
    local n=ffi.C.MultiByteToWideChar(65001,0,s,#s,nil,0);local out=ffi.new('uint16_t[?]',n+1)
    ffi.C.MultiByteToWideChar(65001,0,s,#s,out,n);return out
end
local function quoted(s)
    assert(not s:find('[\r\n]') and not s:find('\0',1,true),'invalid argument')
    return '"'..s:gsub('(\\*)"',function(bs)return bs..bs..'\\"'end):gsub('(\\+)$','%1%1')..'"'
end
-- Starts Filediver for `job` ({ args, logpath }): its output goes to job.logpath.
local function start(exe,job)
    local command={quoted(exe)};for _,arg in ipairs(job.args)do command[#command+1]=quoted(arg)end
    local sa=ffi.new('demo_security');sa.n=ffi.sizeof(sa);sa.inherit=1
    local h=ffi.C.CreateFileW(wide(job.logpath),0x40000000,3,sa,2,0x80,nil)
    assert(h~=nil and ffi.cast('intptr_t',h)~=-1,'could not create export log')
    local si=ffi.new('demo_startup');si.n=ffi.sizeof(si);si.flags=0x100;si.output=h;si.error=h
    local pi=ffi.new('demo_process')
    local ok=ffi.C.CreateProcessW(wide(exe),wide(table.concat(command,' ')),nil,nil,1,0x08000000,nil,nil,si,pi)
    ffi.C.CloseHandle(h);assert(ok~=0,'could not start Filediver')
    ffi.C.CloseHandle(pi.thread)
    job.process,job.start=pi.process,tonumber(ffi.C.GetTickCount64())
end
-- After its process ended: the job's output (an error when Filediver failed).
local function finish(job)
    local code=ffi.new('uint32_t[1]');ffi.C.GetExitCodeProcess(job.process,code);ffi.C.CloseHandle(job.process);job.process=nil
    local output=read(job.logpath)or''
    assert(code[0]==0,'Filediver failed; see '..job.logpath..'\n'..output:sub(-1500))
    return (output:gsub('\27%[[%d;]*m',''))
end
-- Runs every job, several side by side (each Filediver run is independent of the others: up to half the cores, 2-4
-- at a time). A job already done for this game build (its .ok marker in the cache) is not run again: its output is
-- read back. Each job ends with .output; a failure, a cancel (pump() false) or 180 s on one job stops them all.
local function run_all(exe,jobs,context)
    local cores=tonumber(os.getenv('NUMBER_OF_PROCESSORS')or'')or 4
    local width=math.max(2,math.min(4,math.floor(cores/2)))
    local pending,running={},{}
    for _,job in ipairs(jobs)do
        if I.exists(job.done)then
            job.output=((read(job.logpath)or''):gsub('\27%[[%d;]*m',''))
            if context.log then context.log('Entity resources: '..job.label..' (cached)')end
        else pending[#pending+1]=job end
    end
    local function stop(why)
        for _,job in ipairs(running)do
            if job.process then ffi.C.TerminateProcess(job.process,1);ffi.C.CloseHandle(job.process);job.process=nil end
        end
        error(why,0)
    end
    while #pending>0 or #running>0 do
        while #running<width and #pending>0 do
            local job=table.remove(pending,1)
            os.remove(job.done)
            local ok,why=pcall(start,exe,job)
            if not ok then stop(why)end
            running[#running+1]=job
            if context.log then context.log('Entity resources: '..job.label..' ('..#running..' running)')end
        end
        ffi.C.WaitForSingleObject(running[1].process,20)
        local now=tonumber(ffi.C.GetTickCount64())
        for k=#running,1,-1 do
            local job=running[k]
            if ffi.C.WaitForSingleObject(job.process,0)==0 then
                table.remove(running,k)
                local ok,output=pcall(finish,job)
                if not ok then stop(output)end
                job.output=output
                write(job.done,'ok\n')
            elseif now-job.start>180000 then
                stop('Filediver export timed out: '..job.label)
            end
        end
        if context.pump and context.pump()==false then stop('Filediver export cancelled or timed out')end
    end
end

local function walk(folder,out)
    out=out or{}
    local fd=ffi.new('host_find_data');local find=ffi.C.FindFirstFileA(folder..'/*',fd)
    if find==nil or ffi.cast('intptr_t',find)==-1 then return out end
    repeat
        local name=ffi.string(fd.name)
        if name~='.' and name~='..' then
            if bit.band(fd.attributes,16)~=0 then walk(folder..'/'..name,out)
            else out[#out+1]=folder..'/'..name end
        end
    until ffi.C.FindNextFileA(find,fd)==0
    ffi.C.FindClose(find);return out
end

function M.find_filediver(here)
    local configured=read(I.home..'/filediver path.txt')
    local user=os.getenv('USERPROFILE')or''
    for _,p in ipairs({os.getenv('SHODAN_FILEDIVER')or'',configured and configured:match('^%s*(.-)%s*$')or'',
        here..'../filediver.exe',here..'../tools/filediver.exe',
        user..'/Downloads/Compressed/filediver-cli/filediver.exe'})do
        if p~=''and I.exists(p)then return p end
    end
    return nil
end

-- The resource cache of a game build. Filediver's indexes and exports depend on the game's archives and the patches
-- other tools put beside them (this editor's own are left out), so the cache is kept per game.dll (time, size) and
-- those patches: an install after the first reuses it (run_all), until the game or another tool's patches change.
pcall(ffi.cdef,'typedef struct { uint32_t attributes,c1,c2,a1,a2,w1,w2,size_hi,size_lo; } ua_file_data;'..
               'int GetFileAttributesExA(const char *name,int level,ua_file_data *data);')
local function stamp(path)
    local d=ffi.new('ua_file_data')
    if ffi.C.GetFileAttributesExA(path,0,d)==0 then return 'missing' end
    return string.format('%08x%08x:%08x%08x',d.w2,d.w1,d.size_hi,d.size_lo)
end
function M.cache_dir(home,game,owned)
    local folder=game:gsub('\\','/'):gsub('/+$','')
    local data_root=folder:gsub('/game$','')
    local parts={'game.dll '..stamp(folder..'/game.dll')}
    for _,name in ipairs(I.list_files(data_root,'*.patch_*'))do
        if not(owned and owned[name])then parts[#parts+1]=name..' '..stamp(data_root..'/'..name)end
    end
    return home..'/entity-resource-cache/'..D.hex(D.hash_resource(table.concat(parts,'\n'))):lower()
end

function M.prepare(requests,context)
    if #requests==0 then return {},{} end
    local exe=assert(context.filediver,'Filediver is required for independent Unit resources. Set filediver path.txt in the editor settings folder.')
    local cache=context.cache;I.mkdirs(cache)
    local game=context.game:gsub('\\','/'):gsub('/data/game/?$','')
    local common={'--gamedir',game,'--no-pager'}
    local jobs={}
    local function job(args,label)
        local all={};for _,s in ipairs(common)do all[#all+1]=s end;for _,s in ipairs(args)do all[#all+1]=s end
        jobs[#jobs+1]={args=all,label=label,logpath=cache..'/'..label..'.log',done=cache..'/'..label..'.ok'}
        return jobs[#jobs]
    end
    local wanted,allarchives={},{}
    for _,r in ipairs(requests)do wanted[r.source_unit]=true end
    -- every Filediver run up front (none needs another's output): the indexes, each Unit, the packages
    local index_job=job({'--list','--include','*','--types','unit'},'unit-index')
    for _,source in ipairs(keys(wanted))do
        local folder=cache..'/u'..source;I.mkdirs(folder)
        job({'--include','0x'..source:lower()..'.unit','--types','unit','--model-format','raw','--raw-format','separate','--out',folder},'unit-'..source)
    end
    local package_folder=cache..'/packages';I.mkdirs(package_folder)
    job({'--include','*','--types','package','--text-format','raw','--raw-format','separate','--out',package_folder},'packages')
    local package_job=job({'--list','--include','*','--types','package'},'package-index')
    run_all(exe,jobs,context)
    local index=index_job.output
    local locations={}
    for line in index:gmatch('[^\r\n]+')do
        local hash,typ,archives=line:match('0x(%x+)%.0x(%x+)%s+<%-%s*(.*)')
        if hash and #hash==16 and typ:lower()==D.hex(UTYPE):lower()then
            local list={};for id in archives:gmatch('%x+')do if #id==16 then list[#list+1]=id:lower()end end
            locations[hash:upper()]=list
        end
    end
    local extracted={}
    for source in pairs(wanted)do
        local archives=assert(locations[source],'Unit resource not found in Filediver index: '..source)
        assert(#archives>0,'Unit has no source archives: '..source)
        local folder=cache..'/u'..source
        local main,gpu,stream
        for _,p in ipairs(walk(folder))do
            if p:match('%.unit%.main$')then main=read(p)
            elseif p:match('%.unit%.gpu$')then gpu=read(p)
            elseif p:match('%.unit%.stream$')then stream=read(p)end
        end
        assert(main,'Filediver did not export the Unit main data: '..source)
        for _,id in ipairs(archives)do
            extracted[id]=extracted[id]or{units={},packages={}}
            extracted[id].units[D.unhex(source)]={name=D.unhex(source),type=UTYPE,main=main,gpu=gpu,stream=stream}
            allarchives[id]=true
        end
    end
    local folder=package_folder
    -- A package belongs to the triads reported by Filediver's list, not to every triad.
    local packages=package_job.output
    local package_archives={}
    for line in packages:gmatch('[^\r\n]+')do
        local hash,_,archives=line:match('0x(%x+)%.0x(%x+)%s+<%-%s*(.*)')
        if hash and #hash==16 then
            local list={};for id in archives:gmatch('%x+')do if #id==16 then list[#list+1]=id:lower()end end
            package_archives[hash:upper()]=list
        end
    end
    for _,p in ipairs(walk(folder))do
        local relative=p:sub(#folder+2):gsub('\\','/')
        if relative:match('%.package%.main$')then
            local path=relative:gsub('%.package%.main$','')
            local raw=path:match('^0x(%x+)$')
            local key=raw and D.unhex(raw)or D.hash_resource(path)
            local name=D.hex(key);local data=assert(read(p))
            local affected=false
            local count=u32(data,8)
            assert(16+count*16<=#data,'exported package is truncated')
            for i=0,count-1 do
                local at=16+i*16
                if data:sub(at+1,at+8)==UTYPE and wanted[D.hex(data:sub(at+9,at+16))]then affected=true;break end
            end
            if affected then
                for _,id in ipairs(package_archives[name]or{})do
                    extracted[id]=extracted[id]or{units={},packages={}}
                    extracted[id].packages[key]={name=key,type=PTYPE,main=data}
                end
            end
        end
    end
    -- Respect resource replacements from pre-existing ordinary triad patches. Our own
    -- previous outputs are excluded because this build starts from their original inputs.
    local data_root=context.game:gsub('\\','/'):gsub('/game/?$','')
    for id,src in pairs(extracted)do
        local patchfiles=I.list_files(data_root,id..'.patch_*')
        table.sort(patchfiles,function(a,b)return (tonumber(a:match('%.patch_(%d+)$'))or-1)<(tonumber(b:match('%.patch_(%d+)$'))or-1)end)
        for _,name in ipairs(patchfiles)do
            if name:match('%.patch_%d+$')and not(context.owned and context.owned[name])then
                local resources=M.read_archive(assert(read(data_root..'/'..name)),read(data_root..'/'..name..'.gpu_resources'),read(data_root..'/'..name..'.stream'))
                for key,r in pairs(src.units)do src.units[key]=resources[key..UTYPE]or r end
                for key,r in pairs(src.packages)do src.packages[key]=resources[key..PTYPE]or r end
            end
        end
    end
    local function choose(id)
        for name in pairs(context.owned or{})do if name:match('^'..id..'%.patch_%d+$')then return name end end
        local n=0
        while I.exists(data_root..'/'..id..'.patch_'..n)or I.exists(data_root..'/'..id..'.patch_'..n..'.gpu_resources')or I.exists(data_root..'/'..id..'.patch_'..n..'.stream')do n=n+1 end
        return id..'.patch_'..n
    end
    return M.plan(requests,extracted,choose)
end

return M
