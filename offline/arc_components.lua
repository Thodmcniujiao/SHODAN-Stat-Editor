-- ArcInfo: old decrypted JSON and INI names; current 104-byte layout verified before editing.
local M={TYPE=0xAFDF0267,SIZE=104}
M.GROUP_ORDER={'basic','travel','spread','chain','damage','effects','impact','unknown'}
M.GROUPS={
 basic={'Identity','标识','識別'},travel={'Travel and range','传播与射程','傳播與射程'},
 spread={'Spread','扩散','擴散'},chain={'Chaining','连锁','連鎖'},damage={'Damage reference','伤害引用','傷害引用'},
 effects={'Resources and effects','资源与特效','資源與特效'},impact={'Hit effects and demolition','命中效果与破坏','命中效果與破壞'},
 unknown={'Unknown fields','未知字段','未知欄位'},
}
-- JSON name, offset, storage, group, Chinese names, existing stat id, reference type.
M.FIELDS={
 {'type',0,'id','basic','电弧 ID','電弧 ID','arc_id','arc_id'},
 {'speed',4,'f32','travel','传播速度（米/秒）','傳播速度（米/秒）'},
 {'distance',8,'f32','travel','射程（米）','射程（米）','arc_range'},
 {'distance_at_max_angle_spread',12,'f32','spread','最大扩散角对应距离（米）','最大擴散角對應距離（米）'},
 {'distance_at_max_angle_spread_first_shot',16,'f32','spread','首发最大扩散角对应距离（米）','首發最大擴散角對應距離（米）'},
 {'max_angle_spread',20,'f32','spread','最大扩散角（度）','最大擴散角（度）'},
 {'max_angle_spread_first_shot',24,'f32','spread','首发最大扩散角（度）','首發最大擴散角（度）'},
 {'max_chain_length',28,'u32','chain','最大连锁长度','最大連鎖長度','arc_chain'},
 {'max_chain_split',32,'u32','chain','最大连锁分叉数','最大連鎖分叉數','arc_split'},
 {'damage_info_type',36,'u32','damage','伤害 ID','傷害 ID','damage_ref','damage_id'},
 {'camera_shake_path',40,'u64','effects','镜头震动资源哈希','鏡頭震動資源雜湊'},
 {'particle_effect_path',48,'u64','effects','粒子特效资源哈希','粒子特效資源雜湊'},
 {'particle_linger_time',56,'f32','effects','粒子特效残留时间（秒）','粒子特效殘留時間（秒）'},
 {'explosion_effect_path',64,'u64','effects','爆炸特效资源哈希','爆炸特效資源雜湊'},
 {'bolt_path',80,'u64','effects','电弧实体资源哈希','電弧實體資源雜湊'},
 {'hit_effect_damage_type',72,'u32','impact','命中特效伤害类型','命中特效傷害類型'},
 {'hit_audio_event',76,'u32','impact','命中音效事件 ID','命中音效事件 ID'},
 {'demolition_strength',88,'u32','impact','电弧破坏力','電弧破壞力'},
 {'unk_bool_0x005C',92,'bit0','unknown','未知标志位 +0x5C','未知旗標位元 +0x5C'},
 {'unk_uint32_0x0060',96,'u32','unknown','未知整数 +0x60','未知整數 +0x60'},
 {'unk_bool_0x0064',100,'bit0','unknown','未知标志位 +0x64','未知旗標位元 +0x64'},
}
M.LEGACY={ArcTypeID='type',Speed='speed',Distance='distance',MaxAngleSpreadDistance='distance_at_max_angle_spread',
 FirstShotMaxAngleSpreadDistance='distance_at_max_angle_spread_first_shot',MaxAngleSpread='max_angle_spread',
 FirstShotMaxAngleSpread='max_angle_spread_first_shot',MaxChainLength='max_chain_length',MaxChainSplit='max_chain_split',
 UseDamageID='damage_info_type',HitEffectType='hit_effect_damage_type',DemolitionStrength='demolition_strength'}
M.LAYOUT={};M.FLOAT_OFFSETS={}
for _,s in ipairs(M.FIELDS)do
 local off,typ=s[2],s[3]
 M.LAYOUT[#M.LAYOUT+1]={off,typ=='u64'and 8 or typ=='bit0'and 1 or 4,
  (off==0 or off==36 or off==72)and 16 or typ=='u64'and 7 or typ=='f32'and 8 or typ=='bit0'and 4 or 6,
  typ=='bit0'and 3 or 0,typ=='bit0'and 1 or 0}
 if typ=='f32'then M.FLOAT_OFFSETS[#M.FLOAT_OFFSETS+1]=off end
end
table.sort(M.LAYOUT,function(a,b)return a[1]<b[1]end)
function M.check_layout(schemas)
 local t=schemas and schemas[M.TYPE];local a=t and t.members and t.members[1];local r=a and schemas[a.type]
 if not t or t.size~=16 or #t.members~=1 or a.atom~=1 or a.storage~=20 or not r or r.size~=M.SIZE or #r.members~=#M.LAYOUT then return nil end
 for i,e in ipairs(M.LAYOUT)do local m=r.members[i]
  if m.offset~=e[1]or m.size~=e[2]or m.storage~=e[3]or m.atom~=e[4]or m.count~=e[5]then return nil end
 end
 return true
end
return M
