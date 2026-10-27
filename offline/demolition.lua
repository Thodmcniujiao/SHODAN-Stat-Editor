-- Entity demolition authoring. Original tiers are immutable; overrides receive private
-- settings and templates. An ECS entity also receives a cloned Unit resource, so siblings
-- using the same model never silently inherit its override. No game files are written here.
local ffi = require('ffi')
local bit = require('bit')
local G = require('gamedata')
local M = {}
local DT, TM, HM = 0xD6A11545, 0xFB45E243, 0x49795156
local ENT, DEST = 'generated_entities.dl_bin', 'generated_destruction_settings.dl_bin'
local ZERO = string.rep('\0', 8)
local MAX = 4294967295

local function fail(s) error('Entity demolition: ' .. s, 0) end
local function check(ok, s) if not ok then fail(s) end end
local function n32(s, o)
    check(o >= 0 and o + 4 <= #s, 'u32 outside the file')
    local a,b,c,d = s:byte(o+1,o+4)
    return a+b*256+c*65536+d*16777216
end
local function p32(v)
    check(type(v)=='number' and v==v and v%1==0 and v>=0 and v<=MAX, 'expected an unsigned 32 bit integer')
    local a={}
    for i=1,4 do a[i]=string.char(v%256);v=math.floor(v/256) end
    return table.concat(a)
end
local function n64(s,o)
    local lo,hi=n32(s,o),n32(s,o+4)
    check(hi<=2097151, 'array offset or count is too large')
    return lo+hi*4294967296
end
local function p64(v) return p32(v%4294967296)..p32(math.floor(v/4294967296)) end
local function put(s,o,b)
    check(o>=0 and o+#b<=#s,'replacement outside the record')
    return s:sub(1,o)..b..s:sub(o+#b+1)
end
local function hex(key)
    return (key:reverse():gsub('.',function(c)return string.format('%02X',c:byte()) end))
end
local function unhex(h)
    check(type(h)=='string' and #h==16 and not h:find('[^%x]'),'invalid resource hash')
    return (h:gsub('..',function(a)return string.char(tonumber(a,16))end)):reverse()
end
local function dh(s)
    local h=5381
    for i=1,#s do h=(h*33+s:byte(i))%4294967296 end
    return (h-5381)%4294967296
end
local function hash_resource(s)
    local h=ffi.new('uint64_t',#s)*0xC6A4A7935BD1E995ULL
    local p=ffi.cast('const uint8_t *',s)
    local whole=#s-#s%8
    for o=0,whole-1,8 do
        local k=ffi.cast('const uint64_t *',p+o)[0]*0xC6A4A7935BD1E995ULL
        k=bit.bxor(k,bit.rshift(k,47));k=k*0xC6A4A7935BD1E995ULL
        h=bit.bxor(h,k)*0xC6A4A7935BD1E995ULL
    end
    if whole<#s then
        local t=0ULL
        for i=whole,#s-1 do t=bit.bor(t,bit.lshift(ffi.new('uint64_t',s:byte(i+1)),8*(i-whole))) end
        h=bit.bxor(h,t)*0xC6A4A7935BD1E995ULL
    end
    h=bit.bxor(h,bit.rshift(h,47))*0xC6A4A7935BD1E995ULL
    return G.le64(bit.bxor(h,bit.rshift(h,47)))
end
M.hex,M.unhex,M.hash_resource,M.u32,M.p32 = hex,unhex,hash_resource,n32,p32

function M.schemas(s)
    check(s:sub(1,4)=='LTLD' and n32(s,4)==4,'unsupported type library')
    local nt,ne=n32(s,8),n32(s,12)
    local ts=36+4*(nt+ne)
    local ms=ts+36*nt+32*ne
    local out={}
    for i=0,nt-1 do
        local at=ts+36*i
        local t={size=n32(s,at+12),members={}}
        local count,first=n32(s,at+24),n32(s,at+28)
        for j=first,first+count-1 do
            local m=ms+72*j
            t.members[#t.members+1]={atom=s:byte(m+13),storage=s:byte(m+14),
                count=s:byte(m+15)+s:byte(m+16)*256,type=n32(s,m+16),
                size=n32(s,m+24),offset=n32(s,m+40)}
        end
        out[n32(s,36+4*i)]=t
    end
    return out
end

function M.entity_blocks(s)
    local out,by_type,pos={}, {},0
    while pos<#s do
        if s:sub(pos+5,pos+8)~='LDLD' then pos=pos+4 end
        check(s:sub(pos+5,pos+8)=='LDLD','entity container layout differs')
        local typ=n32(s,pos)
        check(n32(s,pos+12)==typ and n32(s,pos+8)==1 and s:byte(pos+21)==1,'invalid entity header')
        local size=n32(s,pos+16)
        local b={header=pos+4,payload=pos+28,size=size,type=typ}
        check(b.payload+size<=#s,'truncated component block')
        out[#out+1],by_type[typ]=b,b
        pos=b.payload+size
    end
    check(pos==#s,'trailing entity bytes')
    return out,by_type
end

local function keyed(s,blocks,schemas,name)
    local t=schemas[dh(name)];local b=blocks[dh(name)]
    check(t and b and #t.members==2,name..' is unavailable')
    local map,array=t.members[1],t.members[2]
    local row=schemas[array.type]
    check(map.atom==2 and array.atom==2 and row and row.size>0,'unsupported '..name..' layout')
    check(map.offset+map.size<=b.size and array.offset+array.size<=b.size,'component array outside the block')
    local out,users={},{}
    for i=0,map.count-1 do
        local at=b.payload+map.offset+i*16
        local key=s:sub(at+1,at+8)
        if key~=ZERO then
            local index=n32(s,at+8)
            check(index<array.count,'component record index outside the array')
            check(not out[key],'duplicate component resource')
            out[key]={index=index,offset=b.payload+array.offset+index*row.size}
            users[index]=(users[index] or 0)+1
        end
    end
    return out,{block=b,array=array,map=map,row=row,users=users}
end

local function block(h,payload)
    return put(h,12,p32(#payload))..payload
end

function M.parse_destruction(s)
    local count=n32(s,0);check(count>0 and count<=100000,'invalid settings count')
    local out={settings={},templates={},mapping={},buckets={},count=count}
    local pos=4
    for i=0,count+1 do
        check(s:sub(pos+1,pos+4)=='LDLD' and n32(s,pos+4)==1 and s:byte(pos+17)==1,'invalid destruction header')
        local typ,size=n32(s,pos+8),n32(s,pos+12)
        check(pos+24+size<=#s,'truncated destruction block')
        local b={header=s:sub(pos+1,pos+24),payload=s:sub(pos+25,pos+24+size),at=pos,type=typ}
        if i<count then
            check(typ==DT and size>=168,'unexpected settings layout');out.settings[#out.settings+1]=b
        elseif typ==TM then
            check(not out.template_block,'duplicate template table');out.template_block=b
            local rel,n=n64(b.payload,0),n64(b.payload,8)
            check(n>0 and n<=1000000 and rel>=16 and rel+16*n<=#b.payload,'invalid template array')
            for k=0,n-1 do
                local bytes=b.payload:sub(rel+16*k+1,rel+16*(k+1))
                local id=n32(bytes,0)
                check(not out.templates[id],'duplicate template type')
                out.templates[id]={id=id,value=n32(bytes,4),bytes=bytes}
            end
            out.template_count=n
        elseif typ==HM then
            check(not out.map_block,'duplicate destruction map');out.map_block=b
            local rel,n=n64(b.payload,0),n64(b.payload,8)
            check(n>0 and n<=1000000 and rel>=16 and rel+16*n<=#b.payload,'invalid map array')
            out.capacity=n
            for k=0,n-1 do
                local at=rel+16*k
                local key=b.payload:sub(at+1,at+8)
                if key~=ZERO then
                    local index=n32(b.payload,at+8)
                    check(index<count and n32(b.payload,at+12)==0,'invalid destruction map index')
                    check(not out.mapping[key],'duplicate destruction resource')
                    out.mapping[key]=index;out.buckets[k]=key
                end
            end
        else fail('unknown trailing destruction table') end
        pos=pos+24+size
    end
    check(pos==#s and out.map_block and out.template_block,'incomplete destruction container')
    return out
end

local function levels(d,index)
    local bytes=d.settings[index+1].payload
    local out={}
    for level=0,2 do
        local normal=n32(bytes,48*level+24)
        for _,hit in ipairs({false,true}) do
            local offset=48*level+(hit and 40 or 24)
            local id=n32(bytes,offset)
            local inherited=hit and id==0
            local source=inherited and normal or id
            local t=d.templates[source]
            if source~=0 and source~=10 and t then
                out[#out+1]={key=level..(hit and ':hit' or ':normal'),level=level,hit=hit,
                    inherited=inherited,source_type=source,type=id,value=t.value,offset=offset}
            end
        end
    end
    return out
end

function M.new(entity_string,destruction_string,type_string,names)
    local self={entities=entity_string,destruction=destruction_string,schemas=M.schemas(type_string),names=names or {},
                targets={},by_id={}}
    self.groups,self.blocks=M.entity_blocks(entity_string)
    self.units,self.unit_layout=keyed(entity_string,self.blocks,self.schemas,'UnitComponentData')
    self.data=M.parse_destruction(destruction_string)
    local unit_users={}
    for key,rec in pairs(self.units) do
        local unit=entity_string:sub(rec.offset+1,rec.offset+8)
        unit_users[unit]=unit_users[unit] or {};table.insert(unit_users[unit],hex(key))
    end
    self.unit_users=unit_users
    for key,rec in pairs(self.units) do
        local unit=entity_string:sub(rec.offset+1,rec.offset+8)
        local index=self.data.mapping[unit]
        if index==nil then index=self.data.mapping[key] end
        local id='E'..hex(key)
        local path=self.names[hex(key)] or hex(key)
        local t={id=id,hash=hex(key),name=path:match('([^/]+)$')or path,path=path,unit=hex(unit),unit_key=unit,entity_key=key,
            index=index,record=rec,shared=#unit_users[unit],scope='entity',
            why=index==nil and 'No destruction settings mapped to this entity or its Unit' or nil}
        if self.unit_layout.users[rec.index]~=1 then t.why='The Unit component record is shared; cannot isolate this build' end
        t.levels=index~=nil and levels(self.data,index) or {}
        self.targets[#self.targets+1],self.by_id[id]=t,t
    end
    for key,index in pairs(self.data.mapping) do
        if not unit_users[key] then
            local id='U'..hex(key);local path=self.names[hex(key)] or hex(key)
            local t={id=id,hash=hex(key),name=path:match('([^/]+)$')or path,path=path,unit=hex(key),unit_key=key,index=index,
                shared=1,scope='unit',levels=levels(self.data,index)}
            self.targets[#self.targets+1],self.by_id[id]=t,t
        end
    end
    table.sort(self.targets,function(a,b)return a.name:lower()<b.name:lower() end)
    return setmetatable(self,{__index=M})
end

function M:validate(overrides)
    check(type(overrides)=='table','invalid overrides')
    for id,values in pairs(overrides) do
        local t=self.by_id[id];check(t and not t.why,'target unavailable: '..tostring(id))
        local allowed={};for _,l in ipairs(t.levels)do allowed[l.key]=l end
        check(type(values)=='table','invalid target overrides')
        for key,v in pairs(values) do
            check(allowed[key],'destruction stage unavailable: '..id..' '..tostring(key))
            p32(v)
        end
    end
    return true
end

local function sorted_keys(t)
    local out={};for k in pairs(t)do out[#out+1]=k end;table.sort(out);return out
end

function M:build(overrides,entity_string,destruction_string)
    self:validate(overrides)
    local entities=entity_string or self.entities
    local d=M.parse_destruction(destruction_string or self.destruction)
    local next_type=0
    for id in pairs(d.templates)do next_type=math.max(next_type,id+1) end
    local aliases,report,entity_edits={},{},{}
    local original_templates={}
    for id,t in pairs(d.templates)do original_templates[id]=t.bytes end
    for _,id in ipairs(sorted_keys(overrides)) do
        local t,values=self.by_id[id],overrides[id]
        if next(values)then
            local source_index=d.mapping[t.unit_key]
            if source_index==nil then source_index=d.mapping[t.entity_key] end
            check(source_index~=nil,'mapping disappeared: '..id)
            local parent=d.settings[source_index+1]
            local payload=parent.payload
            local actual={};for _,l in ipairs(levels(d,source_index))do actual[l.key]=l end
            for _,key in ipairs(sorted_keys(values))do
                local l=actual[key];check(l,'stage changed while editing: '..id..' '..key)
                local base=d.templates[l.source_type]
                local private=next_type;next_type=next_type+1
                check(private<=MAX,'too many private templates')
                local bytes=put(put(base.bytes,0,p32(private)),4,p32(values[key]))
                d.templates[private]={id=private,value=values[key],bytes=bytes}
                payload=put(payload,l.offset,p32(private))
                -- Serialized pointer slots remain unlinked; the game resolves the new type.
                payload=put(payload,l.offset-8,string.rep('\255',8))
            end
            local mapping_key=t.unit_key
            if t.scope=='entity' then
                mapping_key=hash_resource('shodan/entity_demolition/'..t.hash:lower())
                check(mapping_key~=ZERO and mapping_key~=t.unit_key and not d.mapping[mapping_key],'Unit alias collision')
                check(entities:sub(t.record.offset+1,t.record.offset+8)==t.unit_key,'Unit reference changed while editing')
                entity_edits[#entity_edits+1]={offset=t.record.offset,bytes=mapping_key}
                aliases[#aliases+1]={entity=t.hash,source_unit=t.unit,alias_unit=hex(mapping_key)}
            end
            local new_index=#d.settings
            d.settings[#d.settings+1]={header=parent.header,payload=payload,type=DT}
            d.mapping[mapping_key]=new_index
            report[#report+1]={id=id,unit=hex(mapping_key),settings_index=new_index,values=values}
        end
    end
    table.sort(entity_edits,function(a,b)return a.offset<b.offset end)
    local entity_chunks,cursor={},0
    for _,e in ipairs(entity_edits)do
        check(e.offset>=cursor,'overlapping Unit component edits')
        entity_chunks[#entity_chunks+1]=entities:sub(cursor+1,e.offset)
        entity_chunks[#entity_chunks+1]=e.bytes;cursor=e.offset+#e.bytes
    end
    entity_chunks[#entity_chunks+1]=entities:sub(cursor+1)
    entities=table.concat(entity_chunks)
    -- Keep existing template IDs and bytes exactly, including none and Count.
    local template_ids=sorted_keys(d.templates)
    local templates={}
    for _,id in ipairs(template_ids)do
        if original_templates[id]then check(d.templates[id].bytes==original_templates[id],'shared template changed') end
        templates[#templates+1]=d.templates[id].bytes
    end
    local template_payload=p64(16)..p64(#templates)..table.concat(templates)
    local keys=sorted_keys(d.mapping)
    local capacity=d.capacity
    while #keys*2>capacity do capacity=capacity*2 end
    local buckets={}
    for _,key in ipairs(keys)do
        local at=n32(key,0)%capacity
        while buckets[at]do at=(at+1)%capacity end
        buckets[at]=key
    end
    local entries={}
    for i=0,capacity-1 do
        local key=buckets[i]
        entries[#entries+1]=key and (key..p32(d.mapping[key])..p32(0)) or string.rep('\0',16)
    end
    local map_payload=p64(16)..p64(capacity)..table.concat(entries)
    local chunks={p32(#d.settings)}
    for _,s in ipairs(d.settings)do chunks[#chunks+1]=block(s.header,s.payload) end
    chunks[#chunks+1]=block(d.template_block.header,template_payload)
    chunks[#chunks+1]=block(d.map_block.header,map_payload)
    local destruction=table.concat(chunks)
    local verified=M.parse_destruction(destruction)
    for _,r in ipairs(report)do
        local index=verified.mapping[unhex(r.unit)]
        check(index==r.settings_index,'private mapping did not round-trip')
        local found={};for _,l in ipairs(levels(verified,index))do found[l.key]=l.value end
        for key,value in pairs(r.values)do check(found[key]==value,'private threshold did not round-trip') end
    end
    return {entities=entities,destruction=destruction,aliases=aliases,report=report,
        original_template_count=self.data.template_count,template_count=#templates,
        original_settings_count=self.data.count,settings_count=#d.settings}
end

function M.read_names(path)
    local out={};local f=io.open(path,'rb')
    if not f then return out end
    for line in f:lines()do
        local key,name=line:match('^(%x+)%s+(.+)$')
        if key and #key==16 then out[key:upper()]=name end
    end
    f:close();return out
end

function M.entity_hash_slot(s,schemas)
    local _,blocks=M.entity_blocks(s)
    local _,layout=keyed(s,blocks,schemas,'WeaponWindUpComponentData')
    local row=layout.row
    check(#row.members>=2,'wind-up schema is incomplete')
    for i=1,2 do
        local m=row.members[i]
        check(m.atom==0 and m.storage==8 and m.size==4 and m.offset==(i-1)*4,'unused correction fields are not floats')
    end
    for index=0,layout.array.count-1 do
        local at=layout.block.payload+layout.array.offset+index*row.size
        if not layout.users[index]and at%8==0 then
            return {host=at,knob=layout.block.header+17,index=index,layout=layout}
        end
    end
    fail('this build has no unreferenced aligned numeric correction record')
end

function M.load_overrides(path)
    local out={};local f=io.open(path,'rb')
    if not f then return out end
    for line in f:lines()do
        local id,key,value=line:match('^([EU]%x+)%s+(%d+:%a+)%s+(%d+)$')
        if id and #id==17 then out[id]=out[id]or{};out[id][key]=tonumber(value) end
    end
    f:close();return out
end

function M.save_overrides(path,overrides)
    local lines={'# SHODAN independent entity demolition overrides v1'}
    for _,id in ipairs(sorted_keys(overrides))do
        for _,key in ipairs(sorted_keys(overrides[id]))do lines[#lines+1]=id..' '..key..' '..string.format('%.0f',overrides[id][key]) end
    end
    local f,why=io.open(path..'.new','wb');if not f then return nil,why end
    f:write(table.concat(lines,'\n')..'\n');f:close()
    local kernel=ffi.load('kernel32')
    pcall(ffi.cdef,'int MoveFileExA(const char *a,const char *b,uint32_t flags);')
    if kernel.MoveFileExA(path..'.new',path,9)==0 then return nil,'could not replace override settings' end
    return true
end

-- Install integration: build against all other panel edits, never against relocated host pointers.
function M:changes(changes,overrides,hostdata)
    if not next(overrides)then return {},nil end
    local by_name={};for _,c in ipairs(changes)do by_name[c.name]=c end
    local function plain(name)
        local c=by_name[name]
        if c then return ffi.string(c.plain,c.n) end
        local f=hostdata.files[name];check(f,'required game file not loaded: '..name)
        local p,n=G.open_sealed(f.cipher);check(p,'could not decrypt '..name)
        G.clear_correction(p,n);local s=ffi.string(p,n);G.free(p);return s
    end
    local result=self:build(overrides,plain(ENT),plain(DEST))
    for _,item in ipairs({{ENT,result.entities},{DEST,result.destruction}})do
        local name,s=item[1],item[2];local c=by_name[name]
        if c then G.free(c.plain) else
            local f=hostdata.files[name];c={name=name,hash=f.hash,bytes=0,floats={}};changes[#changes+1]=c
        end
        c.plain,c.n,c.bytes,c.floats=G.alloc(#s),#s,#s,{}
        ffi.copy(c.plain,s,#s)
        if name==ENT then c.demolition_schemas=self.schemas end
    end
    return result.aliases,result
end

return M
