-- Exercise the production host's Install button against an isolated game copy.
-- Seed the old payload-driven preload, then verify a payload-only install removes
-- it without editing the environment, packages, or an unrelated third-party mod.
io.stdout:setvbuf('no')
local package_app=os.getenv('SHODAN_TEST_APP')
if package_app then package.path=package_app..'/?.lua;'..package.path end
local ffi=require('ffi');local I=require('install');local G=require('gamedata')
local H=require('hostdata');local Demo=require('demolition');local PC=require('preload_components')
local Store=require('preload_store');local Assets=require('entity_assets');local S=require('engine_shim')
assert(I.home:gsub('\\','/'):sub(1,#TEST_WORK)==TEST_WORK,'use --isolated-profile and an absolute --work')
local root=TEST_WORK..'/game-copy';local game=root..'/data/game';I.mkdirs(game);I.mkdirs(I.home)
local function write(p,s)local f=assert(io.open(p,'wb'));assert(f:write(s));f:close()end
local live=TEST_GAME..'/data/game';local backups=os.getenv('SHODAN_TEST_BASELINE')
local originals={}
for _,name in ipairs(I.list_files(live,'generated_*.dl_bin'))do
 local bytes=backups and I.read(backups..'/'..name)or nil
 originals[name]=bytes or assert(I.read(live..'/'..name));write(game..'/'..name,originals[name])
end
for _,name in ipairs({'game.dll','dl_library.dl_typelib'})do write(game..'/'..name,assert(I.read(live..'/'..name)))end
local env='generated_environment_settings.dl_bin';local strat='generated_stratagem_settings.dl_bin'
assert(originals[env]and originals[strat])
I.game_running=function()return false end
local real_write=I.write_files
I.write_files=function(path,...)
 assert(path==game,'refusing to write outside the isolated game');return real_write(path,...)
end
local real_begin=Assets.begin
Assets.begin=function(path,...)
 assert(path==game,'refusing asset transaction outside the isolated game');return real_begin(path,...)
end

-- Recreate the previous automatic environment additions with the real serializer.
assert(#H.load(game,{[env]=originals[env]})==0)
local f=H.files[env];local bytes=ffi.string(f.p,f.n)
local lib,n=assert(G.open_sealed(assert(I.read(game..'/dl_library.dl_typelib'))))
local schemas=Demo.schemas(ffi.string(lib,n));G.free(lib)
local old=Store.new({load=function()error('environment-only seed must not read packages')end})
old.cfg.selected['78A1A2CC66B6DD09']=true
local ordinal,registered=0,0
for _,h in ipairs(G.headers(f.p,f.n))do if h.type==0x68E17506 then
 ordinal=ordinal+1
 local parsed=assert(PC.parse(bytes:sub(h.at+25,h.at+24+h.size),h.type))
 for _,a in ipairs(parsed.arrays)do
  local baseline={};for j=0,a.count-1 do
   local at=h.at+24+a.target+j*8;baseline[#baseline+1]=Demo.hex(bytes:sub(at+1,at+8))
  end
  old:register_array('seed-'..ordinal..'-'..a.offset,{file=env,root=h.type,ordinal=ordinal,offset=a.offset},baseline)
  registered=registered+1
 end
end end
assert(registered==17,'expected all 17 environments')
local changes={};old:apply_arrays(changes,H,schemas);assert(#changes==1)
local obsolete=assert(H.build(changes[1]));assert(obsolete~=originals[env])
assert(I.write_files(game,{[env]=obsolete},originals))
for _,file in pairs(H.files)do G.free(file.p)end;H.files={}
local old_assets={}
for _,archive in ipairs({'18235e0c9ec0e636','1577e917ad1f287d','9ba626afa44a3aa3'})do
 old_assets[archive..'.patch_0']='obsolete payload-derived manifest/resource bundle'
 if archive~='9ba626afa44a3aa3'then
  old_assets[archive..'.patch_0.gpu_resources']='obsolete gpu'
  old_assets[archive..'.patch_0.stream']='obsolete stream'
 end
end
local seed=Assets.begin(game,old_assets);assert(seed:activate());assert(seed:commit())
local foreign=root..'/data/0123456789abcdef.patch_5';write(foreign,'unrelated third-party patch')

-- Use the same real entity hash as the reported failure, through normal config restoration.
write(I.home..'/config.txt',table.concat({
 'changes on','lang en','updates off','cache_clear_on_exit off','arc_chains_multiplayer off',
 'several_vehicles off','stratagem_bounce off','foliage_pass_through off','sniper_crosshair off',
 'F700000000000008 strat_Payload1_lo 1394296293',
 'F700000000000008 strat_Payload1_hi 1714059527','',
},'\n'))
I.find_game=function()return game end
SHODAN_PRESET_DIRECTORY=TEST_WORK..'/program/Presets';SHODAN_OFFLINE_LANG='en'
S.w,S.h=1060,1080
local gdi=ffi.load('gdi32');S.dc=gdi.CreateCompatibleDC(nil);assert(S.dc~=nil)
local info=ffi.new('host_bitmapinfo');info.size=ffi.sizeof(info)
info.width,info.height,info.planes,info.bits=S.w,-S.h,1,32
local ptr=ffi.new('void *[1]');local dib=gdi.CreateDIBSection(S.dc,info,0,ptr,nil,0);assert(dib~=nil)
gdi.SelectObject(S.dc,dib);S.bits=ffi.cast('uint32_t *',ptr[0]);gdi.SetBkMode(S.dc,1);gdi.SetTextAlign(S.dc,24)
S.open=function()end;S.set_title=function()end
S.message_box=function(text)error(text,0)end
local phase,down=0,false;local started=tonumber(ffi.C.GetTickCount64())
S.focused=function()return phase>0 end
S.cursor=function()return 80,1055 end
S.key_down=function(vk)return vk==1 and down end
S.pump=function()
 assert(tonumber(ffi.C.GetTickCount64())-started<120000,'payload host test timed out')
 local state=rawget(_G,'ShodanStatEditor')
 if state then
  assert(state.phase~='gave_up',state.status)
  if state.phase=='ready'and phase==0 then
   local diff=H.diff();assert(#diff==1 and diff[1].name==strat,'payload edit changed another data file')
   for _,c in ipairs(diff)do G.free(c.plain)end
   phase,down=1,true
  elseif phase==1 then phase,down=2,false
  elseif phase==2 and state.host_status():find('Installed',1,true)then
   assert(I.read(game..'/'..env)==originals[env],'payload-only install retained automatic environment preload')
   assert(not next(Assets.owned()),'payload-only install retained automatic package patches');phase=3
  end
 end
 return phase<3
end
S.present=function()end
arg={[1]=package_app and package_app..'/stat_editor.lua'or TEST_ROOT..'/src/stat_editor_offline.lua'}
local host=package_app and package_app..'/host.lua'or TEST_ROOT..'/offline/host.lua'
assert(loadfile(host))()
assert(phase==3,'install never completed')
assert(I.read(game..'/'..env)==originals[env],'old automatic environment preload survived')
for name in pairs(old_assets)do assert(not I.read(root..'/data/'..name),'old payload patch survived: '..name)end
assert(I.read(foreign)=='unrelated third-party patch','unrelated mod was altered')
local installed=I.installed(game);assert(#installed==1,'payload-only install left other changed data files')
local cipher=assert(I.read(game..'/'..strat));assert(cipher~=originals[strat])
local p,size=assert(G.open_sealed(cipher));local baseline,bn=assert(G.open_sealed(originals[strat]))
assert(G.murmur64(p,size)==G.murmur64(baseline,bn),'authenticated hash differs')
local found=false
for _,h in ipairs(G.headers(p,size))do if h.type==0x30EB6399 then
 local at=p+h.at+24;local count=tonumber(ffi.cast('uint32_t *',at+8)[0])
 for j=0,count-1 do local r=at+16+j*400;if tonumber(ffi.cast('uint32_t *',r)[0])==8 then
  local off=tonumber(ffi.cast('uint64_t *',r+152)[0]);assert(tonumber(ffi.cast('uint32_t *',r+160)[0])>0)
  assert(Demo.hex(ffi.string(at+off,8))=='662A7907531B45E5','payload value was lost');found=true
 end end
end end
assert(found);G.free(p);G.free(baseline);gdi.DeleteDC(S.dc)
print('PASS: production Install preserves exact payload, restores 17 environment arrays, removes seven obsolete owned patches, preserves foreign mod; isolated game only')
