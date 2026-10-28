-- MountComponentData (挂载, 120 bytes): up to 5 entities mounted on this one (a tank's turrets, a walker's guns,
-- a ship's parts), each 24 bytes: +0 the mounted entity (path, u64), +8 attach node, +12 side (MountSide), +16 name,
-- +20 / +21 unnamed switches. Layout from the type-library dump of game 1.007.200 (Darctor/Helldivers2_RawData,
-- MountComponentData.json, 2026-10-20), checked against the game's type library and data (164 entities).
local V=require('component_view')
local R,f=V.R,V.field
local S={TYPE='MountComponentData',KEY='mount',SIZE=120,SLOT='MountComponents',FLAG='mount_component',
 COMPONENT={'Mount component','挂载组件（Mount）','掛載組件（Mount）'}}
S.GROUPS={}
S.ENUMS={side={[0]={'Common','通用','通用'},{'Right','右侧','右側'},{'Left','左侧','左側'}}}
local CHANGE={'Another entity here may crash the game when it spawns: change it only to one of the same kind.',
 '换成其他实体可能在生成时使游戏崩溃，只建议换成同类实体。','換成其他實體可能在生成時使遊戲崩潰，只建議換成同類實體。'}
local L={}
for i=1,5 do
 local at,g,b=(i-1)*24,'slot'..i,'info['..(i-1)..'].'
 S.GROUPS[i]={g,'Mount '..i,'挂载位 '..i,'掛載位 '..i}
 f(L,b..'path',at,'u64',g,'Mounted entity','挂载的实体','掛載的實體',R.hash,{id='mount'..i..'_entity',entity=true,note=CHANGE})
 f(L,b..'attach_node',at+8,'u32',g,'Attach node (hash)','挂接节点（哈希）','掛接節點（雜湊）',R.hash,{id='mount'..i..'_node'})
 f(L,b..'mount_side',at+12,'enum',g,'Side','挂载侧','掛載側',R.enum,{id='mount'..i..'_side',enum='side',enum_type='MountSide'})
 f(L,b..'name',at+16,'u32',g,'Mount name (hash)','挂载名（哈希）','掛載名（雜湊）',R.hash,{id='mount'..i..'_name'})
 f(L,b..'unk_bool_r0x0014',at+20,'flag',g,'Unknown switch +0x14','未知开关 +0x14','未知開關 +0x14',R.flag,{id='mount'..i..'_unk14'})
 f(L,b..'unk_bool_r0x0015',at+21,'flag',g,'Unknown switch +0x15','未知开关 +0x15','未知開關 +0x15',R.flag,{id='mount'..i..'_unk15'})
end
S.FIELDS=L
S.LAYOUT={{0,120}}
S.NESTED={[0]={size=24,layout={{0,8},{8,4},{12,4},{16,4},{20,1},{21,1}},required=true}}
return V.prepare(S)
