-- ProjectileSettings -> ProjectileInfo, matched against the current type library.
local M={TYPE=0xBD4042C2,SIZE=272}
M.GROUP_ORDER={'basic','flight','damage','explosion','collision','ricochet','attachment','effects','impact','audio','templates','flags1','flags2','unknown'}
M.GROUPS={
 basic={'Identity and display','标识与显示','識別與顯示'},flight={'Ballistics','弹道','彈道'},
 damage={'Damage reference','伤害引用','傷害引用'},effects={'Resources and effects','资源与特效','資源與特效'},
 explosion={'Explosion triggers','爆炸触发','爆炸觸發'},impact={'Impact and decals','命中与贴花','命中與貼花'},
 ricochet={'Ricochet','跳弹','跳彈'},audio={'Audio','音效','音效'},templates={'Effect templates','效果模板','效果範本'},
 flags1={'Projectile flags 1','射弹标志 1','射彈旗標 1'},collision={'Collision','碰撞','碰撞'},
 flags2={'Projectile flags 2','射弹标志 2','射彈旗標 2'},attachment={'Attachment offset','附着偏移','附著偏移'},
 unknown={'Unknown fields','未知字段','未知欄位'},
}
-- JSON field, offset, storage, group, Simplified Chinese, Traditional Chinese, legacy stat id, reference type.
M.FIELDS={
 {'type',0,'id','basic','射弹 ID','射彈 ID','projectile_id','projectile_id'},
 {'name_upper',4,'u32','basic','大写名称文本 ID','大寫名稱文字 ID'},
 {'name_cased',8,'u32','basic','常规名称文本 ID','一般名稱文字 ID'},
 {'short_name',12,'u32','basic','简称文本 ID','簡稱文字 ID'},
 {'hud_icon',16,'u64','basic','HUD 图标资源哈希','HUD 圖示資源雜湊'},
 {'calibre',24,'f32','flight','口径（毫米）','口徑（毫米）'},
 {'num_projectiles',28,'u32','flight','每次射击射弹数','每次射擊射彈數','pellets'},
 {'speed',32,'f32','flight','初速（米/秒）','初速（米/秒）','velocity'},
 {'mass',36,'f32','flight','质量','質量'},
 {'drag',40,'f32','flight','阻力系数','阻力係數'},
 {'gravity_multiplier',44,'f32','flight','重力系数','重力係數','gravity'},
 {'simulation_steps',48,'u32','flight','模拟步数','模擬步數'},
 {'life_time',52,'f32','flight','寿命（秒）','壽命（秒）','lifetime'},
 {'life_time_randomness',56,'f32','flight','寿命随机量（秒）','壽命隨機量（秒）'},
 {'penetration_slowdown',64,'f32','flight','穿透后速度衰减','穿透後速度衰減','pen_slowdown'},
 {'damage_info_type',60,'u32','damage','伤害 ID','傷害 ID','damage_ref','damage_id'},
 {'particle_thruster_effect_path',72,'u64','effects','推进特效资源哈希','推進特效資源雜湊'},
 {'low_ammo_particle_thruster_effect_path',80,'u64','effects','低弹药推进特效资源哈希','低彈藥推進特效資源雜湊'},
 {'particle_thruster_effect_length',88,'f32','effects','推进特效长度','推進特效長度'},
 {'particle_trail_effect_path',96,'u64','effects','尾迹特效资源哈希','尾跡特效資源雜湊'},
 {'dissipate_particle_effect_path',104,'u64','effects','消散特效资源哈希','消散特效資源雜湊'},
 {'disintegration_particle_effect_path',112,'u64','effects','解体特效资源哈希','解體特效資源雜湊'},
 {'hit_direction_hint_effect',120,'u64','effects','命中方向提示特效哈希','命中方向提示特效雜湊'},
 {'projectile_unit_path',128,'u64','effects','射弹实体资源哈希','射彈實體資源雜湊'},
 {'explosion_threshold_angle',136,'f32','explosion','爆炸触发角度（度）','爆炸觸發角度（度）','blast_angle'},
 {'can_expire_after_impact',140,'bit0','explosion','命中后允许寿命结束','命中後允許壽命結束'},
 {'explosion_type_on_impact',144,'u32','explosion','命中爆炸 ID','命中爆炸 ID','impact_explosion','explosion_id'},
 {'explosion_proximity',148,'f32','explosion','近炸距离（米）','近炸距離（米）','fuse_proximity'},
 {'explosion_delay',152,'f32','explosion','爆炸延迟（秒）','爆炸延遲（秒）','fuse_delay'},
 {'explosion_type_expire',156,'u32','explosion','寿命结束爆炸 ID','壽命結束爆炸 ID','expiry_explosion','explosion_id'},
 {'arming_distance',160,'f32','explosion','解保险距离（米）','解除保險距離（米）','arming'},
 {'decal_size',168,'f32','impact','贴花尺寸','貼花尺寸'},
 {'surface_impact_type',172,'u32','impact','表面命中效果类型','表面命中效果類型'},
 {'ricochet_impact_type',176,'u32','impact','跳弹命中效果类型','跳彈命中效果類型'},
 {'max_ricochets',180,'u32','ricochet','最大跳弹次数','最大跳彈次數'},
 {'ricochet_threshold_angle',184,'f32','ricochet','跳弹阈值角度（度）','跳彈閾值角度（度）'},
 {'ricochet_threshold_speed',188,'f32','ricochet','跳弹阈值速度（米/秒）','跳彈閾值速度（米/秒）'},
 {'ricochet_angle_loss',192,'f32','ricochet','跳弹角度损失系数','跳彈角度損失係數'},
 {'ricochet_spread_vertical',196,'f32','ricochet','跳弹垂直散布（度）','跳彈垂直散布（度）'},
 {'ricochet_spread_horizontal',200,'f32','ricochet','跳弹水平散布（度）','跳彈水平散布（度）'},
 {'audio_crack_event',204,'u32','audio','音爆音效事件 ID','音爆音效事件 ID'},
 {'audio_ricochet_event',208,'u32','audio','跳弹音效事件 ID','跳彈音效事件 ID'},
 {'audio_trail_event_start',212,'u32','audio','尾迹音效开始事件 ID','尾跡音效開始事件 ID'},
 {'audio_trail_event_stop',216,'u32','audio','尾迹音效停止事件 ID','尾跡音效停止事件 ID'},
 {'status_effect_volume_template',232,'u32','templates','状态效果区域模板','狀態效果區域範本'},
 {'effect_damage_type',236,'u32','templates','命中特效伤害类型','命中特效傷害類型'},
 {'fire_template',240,'u32','templates','火焰模板','火焰範本'},
 {'projectile_flags_1',244,'u16','flags1','射弹标志 1（原始值）','射彈旗標 1（原始值）'},
 {'raycast_template',248,'u32','collision','射线检测模板','射線檢測範本'},
 {'proximity_explosion_collision_filter',252,'u32','collision','近炸碰撞过滤器','近炸碰撞過濾器'},
 {'projectile_flags_2',256,'u8','flags2','射弹标志 2（原始值）','射彈旗標 2（原始值）'},
 {'projectile_attachment_local_offset.x',260,'f32','attachment','附着局部偏移 X（米）','附著局部偏移 X（米）'},
 {'projectile_attachment_local_offset.y',264,'f32','attachment','附着局部偏移 Y（米）','附著局部偏移 Y（米）'},
 {'projectile_attachment_local_offset.z',268,'f32','attachment','附着局部偏移 Z（米）','附著局部偏移 Z（米）'},
 {'unk_float_0x00A4',164,'f32','unknown','未知浮点数 +0xA4','未知浮點數 +0xA4'},
 {'unk_float_0x00DC',220,'f32','unknown','未知浮点数 +0xDC','未知浮點數 +0xDC'},
 {'unk_uint32_0x00E0',224,'u32','unknown','未知整数 +0xE0','未知整數 +0xE0'},
 {'unk_bool_0x00E4',228,'bit0','unknown','未知标志位 +0xE4','未知旗標位元 +0xE4'},
}
M.BITS={
 {'inherit_velocity',244,0,'flags1','继承发射源速度','繼承發射來源速度'},
 {'ignore_terminal_velocity',244,1,'flags1','忽略终端速度','忽略終端速度'},
 {'remove_thruster_effect_instantly',244,2,'flags1','立即移除推进特效','立即移除推進特效'},
 {'remove_trail_effect_instantly',244,3,'flags1','立即移除尾迹特效','立即移除尾跡特效'},
 {'projectile_unit_auto_remove',244,4,'flags1','自动移除射弹实体','自動移除射彈實體'},
 {'explosions_inherit_velocity',244,5,'flags1','爆炸继承速度','爆炸繼承速度'},
 {'project_decal',244,6,'flags1','投射贴花','投射貼花'},
 {'global_audio',244,7,'flags1','全局音效','全域音效'},
 {'audio_danger_zone',244,8,'flags1','危险区域音效','危險區域音效'},
 {'hit_only_ground',244,9,'flags1','仅命中地面','僅命中地面'},
 {'can_pass_through_shield',244,10,'flags1','允许穿过护盾','允許穿過護盾'},
 {'allow_long_distance_travel',244,11,'flags1','允许远距离飞行','允許遠距離飛行'},
 {'look_for_audio_source_hijack',244,12,'flags1','查找音源接管','尋找音源接管'},
 {'apply_stim_on_target',256,0,'flags2','对目标施加治疗针','對目標施加治療針'},
 {'projectile_auto_attach',256,1,'flags2','射弹自动附着','射彈自動附著'},
}
-- Native members, in serialization order: offset, size, storage, atom, packed count/bit index.
M.LAYOUT={}
local enum={[0]=true,[60]=true,[144]=true,[156]=true,[172]=true,[176]=true,[232]=true,[236]=true,[240]=true,[248]=true}
for _,s in ipairs(M.FIELDS)do
 local off,typ=s[2],s[3]
 if off<260 and s[1]~='projectile_flags_1'and s[1]~='projectile_flags_2' then
  M.LAYOUT[#M.LAYOUT+1]={off,typ=='u64'and 8 or typ=='bit0'and 1 or 4,enum[off]and 16 or typ=='u64'and 7 or typ=='f32'and 8 or typ=='bit0'and 4 or 6,typ=='bit0'and 3 or 0,typ=='bit0'and 1 or 0}
 end
end
for _,s in ipairs(M.BITS)do M.LAYOUT[#M.LAYOUT+1]={s[2],s[2]==244 and 2 or 1,s[2]==244 and 5 or 4,3,s[3]*256+1}end
M.LAYOUT[#M.LAYOUT+1]={260,12,20,0,0}
table.sort(M.LAYOUT,function(a,b)return a[1]==b[1]and a[5]<b[5]or a[1]<b[1]end)
M.FLOAT_OFFSETS={}
for _,s in ipairs(M.FIELDS)do if s[3]=='f32'then M.FLOAT_OFFSETS[#M.FLOAT_OFFSETS+1]=s[2]end end
function M.check_layout(schemas)
 local t=schemas and schemas[M.TYPE];local a=t and t.members and t.members[1];local r=a and schemas[a.type]
 if not t or t.size~=16 or #t.members~=1 or a.atom~=1 or a.storage~=20 or not r or r.size~=M.SIZE or #r.members~=#M.LAYOUT then return nil end
 for i,e in ipairs(M.LAYOUT)do local m=r.members[i]
  if m.offset~=e[1]or m.size~=e[2]or m.storage~=e[3]or m.atom~=e[4]or m.count~=e[5]then return nil end
 end
 local vector=schemas[r.members[#r.members].type]
 if not vector or vector.size~=12 or #vector.members~=3 then return nil end
 for i,m in ipairs(vector.members)do if m.offset~=(i-1)*4 or m.size~=4 or m.storage~=8 then return nil end end
 return true
end
return M
