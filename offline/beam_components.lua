-- BeamInfo: old decrypted names plus the current 112-byte type-library layout.
local M={TYPE=0xC5085606,SIZE=112}
M.GROUPS={
 basic={'Identity','标识','識別'},geometry={'Beam geometry','激光几何','雷射幾何'},
 damage={'Damage reference','伤害引用','傷害引用'},effects={'Resources and effects','资源与特效','資源與特效'},
 impact={'Impact and decals','命中与贴花','命中與貼花'},audio={'Audio','音效','音效'},
 collision={'Collision queries','碰撞查询','碰撞查詢'},explosion={'Explosion reference','爆炸引用','爆炸引用'},
 danger={'Danger level','危险等级','危險等級'},unknown={'Unknown fields','未知字段','未知欄位'},
}
M.FIELDS={
 {'type',0,'id','basic','激光 ID','雷射 ID','beam_id','beam_id'},
 {'radius',4,'f32','geometry','激光半径（米）','雷射半徑（米）'},
 {'length',8,'f32','geometry','激光长度（米）','雷射長度（米）'},
 {'damage_info_type',12,'u32','damage','伤害 ID','傷害 ID','damage_ref','damage_id'},
 {'beam_effect_path',48,'u64','effects','激光特效资源哈希','雷射特效資源雜湊'},
 {'falloff_effect_path',56,'u64','effects','衰减特效资源哈希','衰減特效資源雜湊'},
 {'beam_unit_path',64,'u64','effects','激光实体资源哈希','雷射實體資源雜湊'},
 {'decal_size',40,'f32','impact','贴花尺寸','貼花尺寸'},
 {'surface_impact_type',44,'u32','impact','表面命中效果类型','表面命中效果類型'},
 {'effect_damage_type',88,'u32','impact','命中特效伤害类型','命中特效傷害類型'},
 {'audio_trail',72,'u32','audio','激光持续音效事件 ID','雷射持續音效事件 ID'},
 {'audio_trail_stop',76,'u32','audio','激光音效停止事件 ID','雷射音效停止事件 ID'},
 {'raycast_template',80,'u32','collision','射线检测模板','射線檢測範本'},
 {'overlap_beam_query',84,'u32','collision','激光重叠碰撞查询','雷射重疊碰撞查詢'},
 {'explosion_type',96,'u32','explosion','爆炸 ID','爆炸 ID','explosion_ref','explosion_id'},
 {'danger_level',104,'u32','danger','危险等级（DangerLevel）','危險等級（DangerLevel）'},
 {'unk_float_0x0010',16,'f32','unknown','未知浮点数 +0x10','未知浮點數 +0x10'},
 {'unk_float_0x0014',20,'f32','unknown','未知浮点数 +0x14','未知浮點數 +0x14'},
 {'unk_float_0x0018',24,'f32','unknown','未知浮点数 +0x18','未知浮點數 +0x18'},
 {'unk_float_0x001C',28,'f32','unknown','未知浮点数 +0x1C','未知浮點數 +0x1C'},
 {'unk_float_0x0020',32,'f32','unknown','未知浮点数 +0x20','未知浮點數 +0x20'},
 {'unk_float_0x0024',36,'f32','unknown','未知浮点数 +0x24','未知浮點數 +0x24'},
 {'unk_float_0x005C',92,'f32','unknown','未知浮点数 +0x5C','未知浮點數 +0x5C'},
 {'unk_bool_0x0064',100,'bit0','unknown','未知标志位 +0x64','未知旗標位元 +0x64'},
 {'unk_bool_0x006C',108,'bit0','unknown','未知标志位 +0x6C','未知旗標位元 +0x6C'},
}
M.LEGACY={BeamTypeID='type',Radius='radius',Length='length',UseDamageID='damage_info_type',
 SurfaceImpactType='surface_impact_type',EffectDamageType='effect_damage_type'}
-- The old focal_shoulder_width cannot be assigned uniquely to the six new floats at +16..36.
M.UNMAPPED_LEGACY={focal_shoulder_width=true}
M.ENUM_TYPES={explosion_type='ExplosionType',danger_level='DangerLevel'}
M.LAYOUT={};M.FLOAT_OFFSETS={}
local enums={[0]=true,[12]=true,[44]=true,[80]=true,[88]=true,[96]=true,[104]=true}
for _,s in ipairs(M.FIELDS)do local off,typ=s[2],s[3]
 M.LAYOUT[#M.LAYOUT+1]={off,typ=='u64'and 8 or typ=='bit0'and 1 or 4,
  enums[off]and 16 or typ=='u64'and 7 or typ=='f32'and 8 or typ=='bit0'and 4 or 6,typ=='bit0'and 3 or 0,typ=='bit0'and 1 or 0}
 if typ=='f32'then M.FLOAT_OFFSETS[#M.FLOAT_OFFSETS+1]=off end
end
table.sort(M.LAYOUT,function(a,b)return a[1]<b[1]end)
function M.check_layout(schemas)
 local t=schemas and schemas[M.TYPE];local a=t and t.members and t.members[1];local r=a and schemas[a.type]
 if not t or t.size~=16 or #t.members~=1 or a.atom~=1 or a.storage~=20 or not r or r.size~=M.SIZE or #r.members~=#M.LAYOUT then return nil end
 for i,e in ipairs(M.LAYOUT)do local m=r.members[i]
  if m.offset~=e[1]or m.size~=e[2]or m.storage~=e[3]or m.atom~=e[4]or m.count~=e[5]then return nil end
 end
 -- Inferred display aliases are backed by the exact enum types, not their numerical values.
 return r.members[22].type==297725443 and r.members[24].type==1782498921
end
return M
