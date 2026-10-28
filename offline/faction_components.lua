-- FactionComponentData (阵营, 152 bytes): which side an entity is on (up to 3 factions), how it is targeted
-- (node, size, priority), its influence on enemy spawning, and unit types its targeting ignores. Layout from the
-- type-library dump of game 1.007.200 (Darctor/Helldivers2_RawData, FactionComponentData.json, 2026-10-20),
-- checked against the game's type library and data (533 entities).
local V=require('component_view')
local R,f=V.R,V.field
local S={TYPE='FactionComponentData',KEY='faction',SIZE=152,SLOT='FactionComponents',FLAG='faction_component',
 COMPONENT={'Faction component','阵营组件（Faction）','陣營組件（Faction）'}}
S.GROUPS={
 {'faction','Factions','阵营','陣營'},
 {'target','Being targeted','被瞄准','被瞄準'},
 {'spawn','Spawn influence','生成影响','生成影響'},
 {'nodes','Complex targeting nodes','复杂瞄准节点','複雜瞄準節點'},
 {'ignored','Ignored units','瞄准时忽略的单位','瞄準時忽略的單位'},
 {'unknown','Unknown fields','未知字段','未知欄位'},
}
-- FactionType (its values are bits: 1, 2, 4, ...)
S.ENUMS={faction={[0]={'None','无','無'},[1]={'Super Earth','超级地球','超級地球'},[2]={'Terminids','虫族','蟲族'},
 [4]={'Illuminate','光能者','光能者'},[8]={'Automatons','机器人','機器人'},[16]={'Wildlife','野生动物','野生動物'},
 [32]={'Citizens','平民','平民'}}}
local L={}
for i=0,2 do
 f(L,'factions['..i..'].faction',i*4,'enum','faction','Faction '..(i+1),'阵营 '..(i+1),'陣營 '..(i+1),R.enum,
  {id='faction'..(i+1),enum='faction',enum_type='FactionType'})
end
f(L,'targeting_node',12,'u32','target','Targeting node (hash)','瞄准节点（哈希）','瞄準節點（雜湊）',R.hash)
f(L,'half_width',64,'f32','target','Half width (m)','目标半宽（米）','目標半寬（米）',R.m)
f(L,'half_forward_size',68,'f32','target','Half length (m)','目标前后半长（米）','目標前後半長（米）',R.m)
f(L,'priority',72,'f32','target','Target priority','目标优先级','目標優先級',R.raw)
f(L,'spawn_influence_radius',76,'f32','spawn','Spawn influence radius (m)','生成影响半径（米）','生成影響半徑（米）',R.m)
f(L,'spawn_influence',80,'f32','spawn','Spawn influence','生成影响强度','生成影響強度',R.raw)
for k=0,15 do
 f(L,'complex_targeting_nodes['..k..']',84+k*4,'u32','nodes','Node '..(k+1)..' (hash)','节点 '..(k+1)..'（哈希）','節點 '..(k+1)..'（雜湊）',R.hash,{id='complex_node'..(k+1)})
end
for k=0,5 do
 f(L,'targeting_ignored_unit_paths['..k..']',16+k*8,'u64','ignored','Ignored unit '..(k+1)..' (resource hash)','忽略的单位 '..(k+1)..'（资源哈希）','忽略的單位 '..(k+1)..'（資源雜湊）',R.hash,{id='ignored'..(k+1)})
end
f(L,'unk_bool_about_seeker',148,'flag','unknown','Unknown switch +0x94 (seeker related)','未知开关 +0x94（与追踪有关）','未知開關 +0x94（與追蹤有關）',R.flag,
 {note={'Named after seekers in the dump; meaning not confirmed.','dump 认为与追踪弹有关，含义未确认。','dump 認為與追蹤彈有關，含義未確認。'}})
S.FIELDS=L
S.LAYOUT={{0,12},{12,4},{16,48},{64,4},{68,4},{72,4},{76,4},{80,4},{84,64},{148,1}}
S.NESTED={[0]={size=4,layout={{0,4}}}}
return V.prepare(S)
