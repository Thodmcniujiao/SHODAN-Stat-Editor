local L=require('preset_library');local J=require('json_data');local Footer=require('editor_footer')
local hash='EF85D6CF58E31D70'
local files={
 ['profile/preset_01.txt']='name 旧完整方案\n'..hash..' unit_demolition 222\n',
 ['profile/enemy_preset_02.txt']='name 旧敌人方案\n'..hash..' health 333\n',
 ['profile/weapon_presets.txt']=hash..' 5 unit_demolition 444\n'..hash..' 2 -\n',
 ['profile/player_save_presets.json']='{"1":{"helmet":123}}',
 ['profile/preload_config.json']='{"version":1,"presets":{"extra/5":{"selected":{},"targets":{},"merge_enabled":false}}}',
}
local legacy={};for k,v in pairs(files)do legacy[k]=v end
local fail_write,fail_move=false,false
local io_mock={read=function(p)return files[p]end,write=function(p,s)if fail_write then return nil,'write failed'end;files[p]=s;return true end,
 move=function(a,b)if fail_move then return nil,'move failed'end;files[b]=files[a];files[a]=nil;return true end,remove=function(p)files[p]=nil end}
local library=L.new{path='profile/preset_library.json',io=io_mock}
local ok,n=library:import_legacy('profile',tonumber);assert(ok and n==6)
assert(#library:list('game')==3 and #library:list('enemy')==1 and #library:list('loadout')==1 and #library:list('preload')==1)
for k,v in pairs(legacy)do assert(files[k]==v,'legacy source rewritten')end
local count=#library:list();assert(library:import_legacy('profile',tonumber));assert(#library:list()==count,'duplicate imports')
local imported
for _,p in ipairs(library:list('game'))do if p.kind=='patch'and #p.values==1 then imported=p end end
assert(imported and imported.values[1].value==444)
local id=assert(library:create('game','中文方案😀',{values={{hash=hash,id='damage',value=1.5}}}))
assert(library:rename(id,' 新名称 ')and library:get(id).name=='新名称')
assert(not library:rename(id,'  '))
local raw=files['profile/preset_library.json'];fail_write=true
assert(not library:rename(id,'失败写入'));assert(files['profile/preset_library.json']==raw and library:get(id).name=='新名称');fail_write=false
fail_move=true;assert(not library:delete(id));assert(library:get(id));assert(files['profile/preset_library.json']==raw);fail_move=false
assert(library:replace(id,{values={{hash=hash,id='damage',value=2.75}}}));assert(library:get(id).values[1].value==2.75)
assert(library:delete(imported.id));local reopened=L.new{path='profile/preset_library.json',io=io_mock}
assert(reopened:import_legacy('profile',tonumber));assert(not reopened:get(imported.id),'deleted import resurrected')
for i=1,12 do assert(reopened:create('game','Named '..i,{values={}}))end
assert(#reopened:list('game')>5,'new library still uses five slots')
local original=files['profile/preset_library.json'];files['profile/preset_library.json']=original..' '
assert(not reopened:rename(id,'Conflicting writer'));assert(files['profile/preset_library.json']==original..' ')
local bad=J.decode(original);bad.items[1].id=bad.items[2].id;files['profile/bad.json']=J.encode(bad)
assert(not pcall(L.new,{path='profile/bad.json',io=io_mock}),'duplicate IDs accepted')
for _,size in ipairs({{1060,1080},{2048,1152},{3650,806},{960,600}})do
 local buttons=Footer.layout(size[1],size[2]);assert(#buttons==4)
 local wanted={'install','restore','presets','settings'}
 for i,b in ipairs(buttons)do
  assert(b.key==wanted[i]and b.x0>=0 and b.x1<=size[1]and b.y0>=0 and b.y1<=size[2])
  if i>1 then assert(b.x0>buttons[i-1].x1 and b.y0==buttons[1].y0 and b.y1==buttons[1].y1)end
 end
end
print('PASS: all legacy preset types imported once without source mutation; named library exceeds five entries; CRUD/reload/deletion markers; write/move/external conflict rollback; invalid schema; four-button footer at four aspect ratios')
