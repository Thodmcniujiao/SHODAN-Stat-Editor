-- Exercise the real original editor, its config queue, controls and presets together
-- with the new page. Game files are only read; the profile and all output are isolated.
io.stdout:setvbuf('no')
local ffi=require('ffi');local G=require('gamedata');local H=require('hostdata')
local D=require('demolition');local P=require('demolition_panel');local B=require('demolition_bridge')
local I=require('install');local S=require('engine_shim')
local function read(path)local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s end
local function write(path,s)local f=assert(io.open(path,'wb'));assert(f:write(s));f:close()end
I.mkdirs(I.home);I.mkdirs(TEST_WORK)
local entity=read(TEST_FIXTURES..'/generated_entities.dl_bin')
local destruction=read(TEST_FIXTURES..'/generated_destruction_settings.dl_bin')
local types=read(TEST_FIXTURES..'/dl_library.dl_typelib')
local original={}
for name,s in pairs({['generated_entities.dl_bin']=entity,['generated_destruction_settings.dl_bin']=destruction})do
 original[name]=G.seal(ffi.cast('const uint8_t *',s),#s)
end
assert(#H.load(TEST_GAME,original)==0)
local headers={}
for _,file in pairs(H.files)do
 local base=tonumber(ffi.cast('uintptr_t',file.p))
 for _,header in ipairs(G.headers(file.p,file.n))do headers[base+header.at]=true end
end
SHODAN_OFFLINE_TABLE_ADDRESS=function(address)return headers[address]==true end
local model=D.new(entity,destruction,types)
local id='EEF85D6CF58E31D70';local hash='EF85D6CF58E31D70'
write(I.home..'/config.txt','changes on\nlang en\n'..hash..' unit_demolition 10\n')
assert(D.save_overrides(I.home..'/entity_demolition.txt',{[id]={['0:normal']=20,['0:hit']=20}}))
local state
local panel=P.new(model,{path=I.home..'/entity_demolition.txt',
 enabled=function()return not state or state.entity_demolition_enabled()end,
 changed=function()if state then state.writes=state.writes+1;state.sync_demolition()end end})
local bridge=B.new(panel,{config_path=I.home..'/config.txt',log=print})
SHODAN_DEMOLITION_BRIDGE=bridge
SHODAN_DEMOLITION_UNIT=function(key)local r=model.units[key];return r and model.entities:sub(r.offset+1,r.offset+8)end
S.w,S.h,S.version=1060,1080,1
local gdi=ffi.load('gdi32');S.dc=gdi.CreateCompatibleDC(nil);assert(S.dc~=nil)
SHODAN_OFFLINE=true;SHODAN_OFFLINE_LANG='en';stingray=S.engine();update=function()end
-- Append test accessors in the source's scope; no test hooks are shipped in the editor.
local source=read(TEST_ROOT..'/src/stat_editor_offline.lua')
source=source..[[
TEST_EDITOR={weapons=weapons,by_hash=by_hash,row_value=row_value,change=change,
reset_row=reset_row,reset_weapon=reset_weapon,reset_all=reset_all,settings=settings,
ui=ui,save_config=save_config,presets=presets,modified=modified,MOD=MOD,
overrides=function()return overrides end,handle_table=handle_table,after_pass=after_pass,tick=tick}
]]
assert(loadstring(source,'@'..TEST_ROOT..'/src/stat_editor_offline.lua'))()
state=assert(ShodanStatEditor)
local E=assert(TEST_EDITOR)
-- Feed the host's known tables through the real parsers. This test is about editing,
-- not scanning the Python interpreter's unrelated allocations for table signatures.
for _,file in pairs(H.files)do
 local base=tonumber(ffi.cast('uintptr_t',file.p))
 for _,header in ipairs(G.headers(file.p,file.n))do
  E.handle_table(base+header.at,header.type,header.size,ffi.string(file.p+header.at+24,header.size))
 end
end
E.after_pass(1,true)
local stop=tonumber(ffi.C.GetTickCount64())+90000
repeat
 E.tick()
 assert(state.phase~='gave_up',state.status)
 assert(tonumber(ffi.C.GetTickCount64())<stop,'editor startup timeout: '..tostring(state.phase)..' '..tostring(state.status))
until state.phase=='ready'
local weapon=assert(E.by_hash[hash]);local normal=assert(weapon.by_id.unit_demolition)
local hit=assert(weapon.by_id.unit_demolition_hit,'inherited Direct hits must also be editable on the original page')
E.ui.weapon=weapon
local function value(part)return E.row_value(part.row)end
assert(value(normal)==20 and value(hit)==20,'canonical 20 must beat legacy 10 on first load')
assert(bridge.migration_backup and read(bridge.migration_backup..'/config.txt'):find('unit_demolition 10',1,true))
assert(not read(I.home..'/config.txt'):find('unit_demolition',1,true),'legacy duplicate must be removed')
assert(#H.diff()==0,'migration must not edit any raw game table')
assert(E.modified(weapon),'canonical changes must mark the original weapon as modified')
local defaults={}
for _,l in ipairs(model.by_id[id].levels)do defaults[l.key]=l.value end
-- Original controls -> new page; arbitrary integers, rather than selecting a shared tier.
E.change(normal.row,0,false,12345)
assert(value(normal)==12345 and panel.values[id]['0:normal']==12345)
assert(value(hit)==20,'an explicit direct-hit override must remain independent')
assert(panel:set(id,'0:normal',999))
assert(value(normal)==999,'new page -> original page must read the same live value')
local row_index;for i,row in ipairs(weapon.rows)do if row==normal.row then row_index=i end end
E.ui.value={weapon=weapon,n=row_index,text='555'}
assert(state.commit_value()and panel.values[id]['0:normal']==555,'page switch/install must commit the original input buffer')
E.ui.value={weapon=weapon,n=row_index,text='not a number'}
assert(not state.commit_value()and panel.values[id]['0:normal']==555);E.ui.value=nil
for i,target in ipairs(panel.list)do if target.id==id then panel.selected=i end end
panel:edit(1);panel.buffer='999';assert(panel:commit()and value(normal)==999,'page switch/install must commit the new input buffer')
-- Clearing the direct override restores inheritance on both pages.
assert(panel:set(id,'0:hit',nil));assert(value(hit)==999)
E.change(normal.row,0,false,777);assert(value(normal)==777 and value(hit)==777)
E.change(hit.row,0,false,defaults['0:hit'])
assert(value(hit)==defaults['0:hit'] and panel.values[id]['0:hit']==defaults['0:hit'],
 'typing the hit baseline must keep an explicit override when Normal has another value')
E.presets.save_weapon_preset(weapon,2)
E.reset_row(weapon,hit.row);assert(value(hit)==777)
E.presets.load_weapon_preset(weapon,2)
assert(panel.values[id]['0:hit']==defaults['0:hit'],'presets must retain an explicit hit baseline')
E.change(hit.row,0,false,888);assert(panel.values[id]['0:hit']==888 and value(normal)==777)
E.reset_row(weapon,hit.row);assert(value(hit)==777 and not panel.values[id]['0:hit'])
-- Presets include the canonical cache, without creating a second persistent config value.
E.presets.save_weapon_preset(weapon,1)
E.change(normal.row,0,false,456)
E.presets.load_weapon_preset(weapon,1)
assert(value(normal)==777 and panel.values[id]['0:normal']==777)
E.presets.new_full_preset();local full=E.presets.chosen();assert(full)
E.change(normal.row,0,false,987)
E.presets.load_full_preset(full);assert(value(normal)==777)
-- Changes off changes the displayed/effective value, never deletes saved overrides.
E.settings.set_changes(false)
assert(value(normal)==defaults['0:normal'] and panel:value(model.by_id[id],model.by_id[id].levels[1])==defaults['0:normal'])
assert(panel.values[id]['0:normal']==777)
E.settings.set_changes(true);assert(value(normal)==777)
assert(E.save_config());assert(not read(I.home..'/config.txt'):find('unit_demolition',1,true))
local reload=P.new(model,{path=I.home..'/entity_demolition.txt'})
assert(reload.values[id]['0:normal']==777,'restart must use the canonical saved value')
-- The real installation builder must see only canonical overrides, preserving other entities.
assert(#H.diff()==0,'old controls must never write shared destruction/death fields')
local prepared=H.diff()
local aliases,result=model:changes(prepared,panel:overrides(true),H)
assert(#aliases==1 and result.report[1].values['0:normal']==777)
local checked=D.new(result.entities,result.destruction,types)
assert(checked.by_id[id].levels[1].value==777)
assert(checked.by_id.E7FF0FD4572F5996F.levels[1].value==model.by_id.E7FF0FD4572F5996F.levels[1].value)
assert(checked.data.templates[4].bytes==model.data.templates[4].bytes)
local sealed_plain={}
for _,change in ipairs(prepared)do
 local sealed,why=H.build(change);assert(sealed,why)
 local p,n=G.open_sealed(sealed);assert(p and G.murmur64(p,n)==change.hash)
 sealed_plain[change.name]=ffi.string(p,n);G.free(p)
end
local installed=D.new(sealed_plain['generated_entities.dl_bin'],sealed_plain['generated_destruction_settings.dl_bin'],types)
assert(installed.by_id[id].levels[1].value==777,'authenticated installation output must match both pages')
E.reset_row(weapon,normal.row);assert(not panel.values[id] and value(normal)==defaults['0:normal'])
E.change(normal.row,0,false,0);assert(value(normal)==0 and value(hit)==0)
E.change(normal.row,0,false,4294967295);assert(value(normal)==4294967295)
E.reset_row(weapon,normal.row)
assert(panel:set(id,'0:normal',999));E.reset_weapon(weapon);assert(not panel.values[id])
assert(panel:set(id,'0:normal',999));E.reset_all();assert(not next(panel.values))
assert(#H.diff()==0)
gdi.DeleteDC(S.dc)
print('PASS: real original editor + canonical page; migration/conflicts, bidirectional controls, inherited/explicit hits, presets, changes toggle, resets, restart and installation output; no game writes')
