-- Run each phase in a fresh Lua process with the same isolated profile/game copy.
io.stdout:setvbuf('no')
local app=os.getenv('SHODAN_TEST_APP');if app then package.path=app..'/?.lua;'..package.path;SHODAN_DATA_DIRECTORY=nil;SHODAN_PRESET_DIRECTORY=nil end
local ffi=require('ffi');local I=require('install');local G=require('gamedata');local H=require('hostdata')
local Assets=require('entity_assets');local S=require('engine_shim')
local mode=assert(os.getenv('SHODAN_CACHE_TEST_PHASE'))
assert(I.home:gsub('\\','/'):sub(1,#TEST_WORK)==TEST_WORK,'use an isolated profile and absolute --work')
local root=TEST_WORK..'/game-copy';local game=root..'/data/game';I.mkdirs(game);I.mkdirs(I.home)
local function write(p,s)local f=assert(io.open(p,'wb'));assert(f:write(s));f:close()end
if mode=='install'then
 local backups=assert(os.getenv('SHODAN_TEST_BASELINE'))
 for _,name in ipairs(I.list_files(TEST_GAME..'/data/game','generated_*.dl_bin'))do
  write(game..'/'..name,I.read(backups..'/'..name)or assert(I.read(TEST_GAME..'/data/game/'..name)))
 end
 for _,name in ipairs({'game.dll','dl_library.dl_typelib'})do write(game..'/'..name,assert(I.read(TEST_GAME..'/data/game/'..name)))end
 write(I.home..'/config.txt',table.concat({'changes on','lang en','updates off','cache_clear_on_exit on',
  'arc_chains_multiplayer off','several_vehicles off','stratagem_bounce off','foliage_pass_through off','sniper_crosshair off',
  'FFFFFFF800000001 health 99999',''},'\n'))
elseif mode=='cached'then
 local cfg=assert(I.read(I.home..'/config.txt'))
 write(I.home..'/config.txt',cfg..'FFFFFFF800000001 health 77777\n')
end
I.find_game=function()return game end;I.game_running=function()return false end
local original_write=I.write_files
I.write_files=function(path,...)
 assert(path==game,'refusing live game write')
 if mode=='restore_failed'then return nil,'forced restore failure'end
 return original_write(path,...)
end
local original_assets=Assets.begin
Assets.begin=function(path,...)assert(path==game,'refusing live asset write');return original_assets(path,...)end
local panel=app and app..'/stat_editor.lua'or TEST_ROOT..'/src/stat_editor_offline.lua'
local original_loadfile=loadfile
loadfile=function(path,...)
 if path==panel then
  local f=assert(io.open(path,'rb'));local source=f:read('*a');f:close()
  return loadstring(source..'\nTEST_CACHE_EDITOR={by_hash=by_hash,tables=tables,row_value=row_value,default_of=default_of,change=change,reset_row=reset_row,save=save_config,click=click}\n','@'..path)
 end
 return original_loadfile(path,...)
end
S.w,S.h=1060,1080
local gdi=ffi.load('gdi32');S.dc=gdi.CreateCompatibleDC(nil);assert(S.dc~=nil)
local info=ffi.new('host_bitmapinfo');info.size=ffi.sizeof(info);info.width,info.height,info.planes,info.bits=S.w,-S.h,1,32
local bits=ffi.new('void *[1]');local dib=gdi.CreateDIBSection(S.dc,info,0,bits,nil,0);assert(dib~=nil)
gdi.SelectObject(S.dc,dib);S.bits=ffi.cast('uint32_t *',bits[0]);gdi.SetBkMode(S.dc,1);gdi.SetTextAlign(S.dc,24)
S.open=function()end;S.set_title=function()end;S.message_box=function(text)error(text,0)end;S.present=function()end
if not app then SHODAN_PRESET_DIRECTORY=TEST_WORK..'/program/Presets'end;SHODAN_OFFLINE_LANG='en'
require('portable_io_guard')
local phase,down=0,false;local started=tonumber(ffi.C.GetTickCount64());local saw_reload=false
S.focused=function()return phase>0 end
S.cursor=function()return mode:match('^restore')and 400 or 80,1055 end
S.key_down=function(vk)return vk==1 and down end
local disk_offset
local function disk_health()
 local p,n=assert(G.open_sealed(assert(I.read(game..'/generated_entities.dl_bin'))))
 assert(disk_offset and disk_offset+4<=n);local v=tonumber(ffi.cast('int32_t *',p+disk_offset)[0]);G.free(p);return v
end
S.pump=function()
 assert(tonumber(ffi.C.GetTickCount64())-started<90000,'cache lifecycle timeout')
 local state=rawget(_G,'ShodanStatEditor')
 if state then
  assert(state.phase~='gave_up',state.status)
  if state.phase=='ready'and phase==0 then
   local e=assert(TEST_CACHE_EDITOR);local w=assert(e.by_hash.FFFFFFF800000001);local part=assert(w.by_id.health)
   disk_offset=e.tables[part.field.kind].copies[1]+24+part.field.offset-tonumber(ffi.cast('uintptr_t',H.files['generated_entities.dl_bin'].p))
   assert(e.default_of(part.field)==125,'original reset baseline was lost')
   local expected=(mode=='verify_reset'or mode=='pending_reset'or mode=='restore_empty')and 125 or mode=='cached'and 77777 or 99999
   assert(e.row_value(part.row)==expected,'unexpected health on '..mode..': '..tostring(e.row_value(part.row)))
   if mode~='install'then assert(disk_health()==((mode=='verify_reset'or mode=='restore_empty')and 125 or 99999),'disk changed before install')end
   if mode=='reset'or mode=='stage_reset'then
    e.reset_row(w,part.row);assert(e.row_value(part.row)==125)
    assert(e.save());assert(I.read(I.home..'/config.txt'):find(' health 125',1,true),'pending reset was not saved')
    if mode=='stage_reset'then e.click('set:cache_clear_on_exit:off')end
   elseif mode=='pending_reset'then
    e.click('set:cache_clear_on_exit:on')
   elseif mode=='dirty'then e.change(part.row,0,false,54321);assert(e.row_value(part.row)==54321)
   elseif mode=='clear'then
    e.change(part.row,0,false,54321);e.click('cache_clear');e.click('cache_clear')
    assert(e.row_value(part.row)==99999,'clear cache did not return to installed value')
   elseif mode:match('^restore')then
    e.change(part.row,0,false,54321)
    for _,key in ipairs({'vehicles','bounce','foliage','reticle'})do e.click('set:'..key..':on')end
   end
   if mode=='install'or mode=='reset'or mode:match('^restore')then phase,down=1,true else phase=3 end
  elseif phase==1 then phase,down=2,false
  elseif phase==2 and mode=='restore_failed'then
   assert(state.phase=='ready','failed restore triggered reload')
   if state.host_status():find('Not restored:',1,true)then
    local e=TEST_CACHE_EDITOR;assert(e.row_value(e.by_hash.FFFFFFF800000001.by_id.health.row)==54321,'failed restore discarded edits')
    assert(disk_health()==99999);phase=3
   end
  elseif phase==2 and mode:match('^restore')then
   if state.phase~='ready'then saw_reload=true
   elseif saw_reload then
    assert(state.ui_errors==0,'reload produced a drawing error')
    local e=assert(TEST_CACHE_EDITOR);local w=assert(e.by_hash.FFFFFFF800000001)
    assert(e.row_value(w.by_id.health.row)==125,'restore did not refresh the visible health')
    local diff=H.diff();assert(#diff==0,'restore reload reapplied staged game edits')
    assert(#I.installed(game)==0,'restored files remain marked installed')
    phase=3
   end
  elseif phase==2 and state.host_status():find('Installed',1,true)then phase=3 end
 end
 return phase<3
end
arg={[1]=panel};assert(loadfile(app and app..'/host.lua'or TEST_ROOT..'/offline/host.lua'))()
loadfile=original_loadfile
assert(phase==3)
local expected
if mode=='reset'or mode=='verify_reset'or mode=='restore'or mode=='restore_empty'then expected=125 else expected=99999 end
assert(disk_health()==expected,'closing changed installed health')
local cfg=assert(I.read(I.home..'/config.txt'))
if mode=='stage_reset'then
 assert(cfg:find('cache_clear_on_exit off',1,true)and cfg:find(' health 125',1,true),'pending reset cache was lost')
else assert(cfg:find('cache_clear_on_exit on',1,true)and not cfg:find(' health ',1,true),'closing retained numeric cache')end
gdi.DeleteDC(S.dc)
print('PASS cache lifecycle:',mode,'disk health',expected,mode=='stage_reset'and'pending reset retained'or'numeric cache empty')
