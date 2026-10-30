-- ExplosionInfo: old decrypted definitions supply known names; current typelib supplies layout.
local M={TYPE=0x2AEA2592,SIZE=152}
M.GROUP_ORDER={'basic','damage','radius','shrapnel','status','arc','shake','effects','impact','templates','flags','unknown'}
M.GROUPS={
 basic={'Identity','标识','識別'},damage={'Damage reference','伤害引用','傷害引用'},
 radius={'Radius and shape','半径与形状','半徑與形狀'},shake={'Camera shake','镜头震动','鏡頭震動'},
 effects={'Effects and audio','特效与音效','特效與音效'},impact={'Surface impact','表面命中效果','表面命中效果'},
 shrapnel={'Shrapnel','破片','破片'},templates={'Templates','效果模板','效果範本'},
 status={'Persistent status volume','持续状态区域','持續狀態區域'},flags={'Explosion flags','爆炸标志','爆炸旗標'},
 arc={'Arc reference','电弧引用','電弧引用'},unknown={'Unknown fields','未知字段','未知欄位'},
}
-- JSON name, offset, storage, group, Chinese names, legacy stat id, semantic reference type.
M.FIELDS={
 {'type',0,'id','basic','爆炸 ID','爆炸 ID','explosion_id','explosion_id'},
 {'fallback_damage_loc_name',8,'u32','basic','备用伤害本地化名称 ID','備用傷害本地化名稱 ID'},
 {'damage_type',4,'u32','damage','伤害 ID','傷害 ID','damage_ref','damage_id'},
 {'inner_radius',16,'f32','radius','内半径（米）','內半徑（米）','inner'},
 {'outer_radius',20,'f32','radius','外半径（米）','外半徑（米）','outer'},
 {'stagger_radius',24,'f32','radius','硬直冲击波半径（米）','硬直衝擊波半徑（米）','shockwave'},
 {'cone_angle',28,'f32','radius','锥角（度）','錐角（度）','cone'},
 {'camera_shake_radius',32,'f32','shake','镜头震动半径（米）','鏡頭震動半徑（米）','shake'},
 {'shake_assets',40,'array','shake','震屏资源数量（只读）','震屏資源數量（唯讀）','shake_assets_count'},
 {'particle_effect_path',56,'u64','effects','粒子特效资源哈希','粒子特效資源雜湊'},
 {'audio_event',64,'u32','effects','爆炸音效事件 ID','爆炸音效事件 ID'},
 {'crater_type',68,'i8','impact','弹坑地形变形类型','彈坑地形變形類型'},
 {'surface_impact_type',72,'u32','impact','表面命中效果类型','表面命中效果類型'},
 {'hit_effect_damage_type',76,'u32','impact','命中特效伤害类型','命中特效傷害類型'},
 {'num_shrapnel_projectiles',80,'u32','shrapnel','破片射弹数量','破片射彈數量','shrapnel_count'},
 {'shrapnel_projectile_type',84,'u32','shrapnel','破片射弹 ID','破片射彈 ID','shrapnel_projectile','projectile_id'},
 {'noise_template',88,'u8','templates','噪声模板','噪音範本'},
 {'wind_effect_template',92,'u32','templates','风效模板','風效範本'},
 {'fire_template',96,'u32','templates','火焰模板','火焰範本'},
 {'persistent_status_volume',100,'u32','status','持续状态区域模板','持續狀態區域範本'},
 {'status_volume_effect_time',104,'f32','status','状态区域特效持续时间（秒）','狀態區域特效持續時間（秒）'},
 {'status_volume_effect_audio_play',108,'u32','status','状态区域音效播放事件 ID','狀態區域音效播放事件 ID'},
 {'status_volume_effect_audio_stop',112,'u32','status','状态区域音效停止事件 ID','狀態區域音效停止事件 ID'},
 {'explosion_flags',116,'u8','flags','爆炸标志（原始值）','爆炸旗標（原始值）'},
 {'arc_type',120,'u32','arc','电弧 ID','電弧 ID','arc_ref','arc_id'},
 {'unk_bool_0x000C',12,'bit0','unknown','未知标志位 +0x0C','未知旗標位元 +0x0C'},
 {'unk_flags_0x007C',124,'u8','unknown','未知标志 +0x7C（原始值）','未知旗標 +0x7C（原始值）'},
 {'unk_float_0x0080',128,'f32','unknown','未知浮点数 +0x80','未知浮點數 +0x80'},
 {'unk_flags_0x0084',132,'u8','unknown','未知标志 +0x84（原始值）','未知旗標 +0x84（原始值）'},
 {'unk_float_0x0088',136,'f32','unknown','未知浮点数 +0x88','未知浮點數 +0x88'},
 {'unk_flags_0x008C',140,'u8','unknown','未知标志 +0x8C（原始值）','未知旗標 +0x8C（原始值）'},
 {'unk_enum_0x0090',144,'u32','unknown','未知枚举 +0x90','未知列舉 +0x90'},
}
M.BITS={
 {'do_knockback',116,0,'flags','启用击退','啟用擊退'},
 {'disable_default_surface_impact',116,1,'flags','禁用默认表面命中特效','停用預設表面命中特效'},
 {'is_huge_explosion',116,2,'flags','巨型爆炸','巨型爆炸'},
 {'look_for_audio_source_hijack',116,3,'flags','查找音源接管','尋找音源接管'},
 {'requires_raycast_confirmation',116,4,'flags','需要射线确认','需要射線確認'},
 {'unk_bit_0x0074_5',116,5,'flags','未知标志位 +0x74:5','未知旗標位元 +0x74:5'},
 {'unk_bit_0x007C_0',124,0,'unknown','未知标志位 +0x7C:0','未知旗標位元 +0x7C:0'},
 {'unk_bit_0x007C_1',124,1,'unknown','未知标志位 +0x7C:1','未知旗標位元 +0x7C:1'},
 {'unk_bit_0x0084_0',132,0,'unknown','未知标志位 +0x84:0','未知旗標位元 +0x84:0'},
 {'unk_bit_0x0084_1',132,1,'unknown','未知标志位 +0x84:1','未知旗標位元 +0x84:1'},
 {'unk_bit_0x008C_0',140,0,'unknown','未知标志位 +0x8C:0','未知旗標位元 +0x8C:0'},
 {'unk_bit_0x008C_1',140,1,'unknown','未知标志位 +0x8C:1','未知旗標位元 +0x8C:1'},
}
M.LEGACY={ExplosionTypeID='type',UseDamageID='damage_type',InnerRadius='inner_radius',OuterRadius='outer_radius',
 StaggerRadius='stagger_radius',ConeAngle='cone_angle',CameraShakeRadius='camera_shake_radius',CraterType='crater_type',
 SurfaceImpactType='surface_impact_type',HitEffectDamageType='hit_effect_damage_type',
 ShrapnelAmount='num_shrapnel_projectiles',ShrapnelProjectileID='shrapnel_projectile_type'}
M.LAYOUT={};M.FLOAT_OFFSETS={}
local enums={[0]=true,[4]=true,[72]=true,[76]=true,[84]=true,[92]=true,[96]=true,[100]=true,[120]=true,[144]=true}
local packed={[116]=true,[124]=true,[132]=true,[140]=true}
for _,s in ipairs(M.FIELDS)do
 local off,typ=s[2],s[3]
 if not packed[off]then
  M.LAYOUT[#M.LAYOUT+1]={off,typ=='array'and 16 or typ=='u64'and 8 or(typ=='i8'or typ=='u8'or typ=='bit0')and 1 or 4,
   enums[off]and 16 or typ=='array'and 7 or typ=='u64'and 7 or typ=='i8'and 10 or typ=='u8'and 14 or typ=='bit0'and 4 or typ=='f32'and 8 or 6,
   typ=='array'and 1 or typ=='bit0'and 3 or 0,typ=='bit0'and 1 or 0}
 end
 if typ=='f32'then M.FLOAT_OFFSETS[#M.FLOAT_OFFSETS+1]=off end
end
for _,s in ipairs(M.BITS)do M.LAYOUT[#M.LAYOUT+1]={s[2],1,4,3,s[3]*256+1}end
table.sort(M.LAYOUT,function(a,b)return a[1]==b[1]and a[5]<b[5]or a[1]<b[1]end)
function M.check_layout(schemas)
 local t=schemas and schemas[M.TYPE];local a=t and t.members and t.members[1];local r=a and schemas[a.type]
 if not t or t.size~=16 or #t.members~=1 or a.atom~=1 or a.storage~=20 or not r or r.size~=M.SIZE or #r.members~=#M.LAYOUT then return nil end
 for i,e in ipairs(M.LAYOUT)do local m=r.members[i]
  if m.offset~=e[1]or m.size~=e[2]or m.storage~=e[3]or m.atom~=e[4]or m.count~=e[5]then return nil end
 end
 return true
end
return M
