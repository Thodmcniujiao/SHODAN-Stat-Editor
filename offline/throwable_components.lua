-- ThrowableComponentData (投掷物, 360 bytes): what a grenade page's Throwable rows are (+16 max throw distance,
-- +100 / +104 / +108 starting / max carried / from resupply). Layout from the type-library dump of game 1.007.200
-- (Darctor/Helldivers2_RawData, ThrowableComponentData.json, 2026-10-20); unnamed fields keep the dump's names.
local V=require('component_view')
local R,f,vec3=V.R,V.field,V.vec3
local S={TYPE='ThrowableComponentData',KEY='throwable',SIZE=360,SLOT='ThrowableComponents',FLAG='throwable_component',
 COMPONENT={'Throwable component','投掷物组件（Throwable）','投擲物組件（Throwable）'}}
S.GROUPS={
 {'throw','Throwing','投掷','投擲'},
 {'amount','Carried amount','携带数量','攜帶數量'},
 {'trigger','Sticking and triggering','粘附与触发','黏附與觸發'},
 {'fuse','Fuses','引信','引信'},
 {'actor','Actor and animation','实体与动画','實體與動畫'},
 {'effects','Audio and trail effect','音效与尾迹特效','音效與尾跡特效'},
 {'unknown','Unknown fields','未知字段','未知欄位'},
}
local L={}
f(L,'throw_distance_min',12,'f32','throw','Min throw distance (m)','最小投掷距离（米）','最小投擲距離（米）',R.m)
f(L,'throw_distance_max',16,'f32','throw','Max throw distance (m)','最大投掷距离（米）','最大投擲距離（米）',R.m,{verified=true,id='throw_distance'})
f(L,'thrower_velocity_addition',72,'f32','throw','Thrower velocity added','叠加投掷者速度','疊加投擲者速度',R.raw)
f(L,'thrower_velocity_subtraction',76,'f32','throw','Thrower velocity subtracted','扣除投掷者速度','扣除投擲者速度',R.raw)
f(L,'thrower_velocity_deadzone',80,'f32','throw','Thrower velocity dead zone','投掷者速度死区','投擲者速度死區',R.raw)
f(L,'use_angular_velocity',20,'flag','throw','Use angular velocity','使用角速度','使用角速度',R.flag)
f(L,'angular_velocity_in_motion_space',21,'flag','throw','Angular velocity in motion space','角速度按运动方向','角速度按運動方向',R.flag)
vec3(L,'custom_angular_velocity_min',24,'throw','Angular velocity min','最小角速度','最小角速度',R.raw)
vec3(L,'custom_angular_velocity_max',36,'throw','Angular velocity max','最大角速度','最大角速度',R.raw)

f(L,'start_amount',100,'u32','amount','Starting count','初始数量','初始數量',R.count,{verified=true,id='throw_start'})
f(L,'max_amount',104,'u32','amount','Max carried','最大携带','最大攜帶',R.count,{verified=true,id='throw_max'})
f(L,'refill_amount',108,'u32','amount','From supply','来自补给','來自補給',R.count,{verified=true,id='throw_supply'})
f(L,'max_spawned_amount',172,'i32','amount','Max placed at once (-1: no limit)','同时存在上限（-1 为不限）','同時存在上限（-1 為不限）',R.i32)

f(L,'sticky',84,'flag','trigger','Sticks','会粘附','會黏附',R.flag)
f(L,'sticky_delay',88,'f32','trigger','Stick delay (s)','粘附延迟（秒）','黏附延遲（秒）',R.ssec)
f(L,'is_impact_trigger',92,'flag','trigger','Triggers on impact','撞击触发','撞擊觸發',R.flag)
f(L,'ignore_thrower_impact_trigger',93,'flag','trigger','Ignores impacts with the thrower','忽略与投掷者的撞击','忽略與投擲者的撞擊',R.flag)
f(L,'drop_on_cancelled',94,'flag','trigger','Dropped when cancelled','取消投掷时掉落','取消投擲時掉落',R.flag)
f(L,'enable_interaction_delay',96,'f32','trigger','Interaction delay (s; -1: none)','可交互延迟（秒，-1 为不可）','可互動延遲（秒，-1 為不可）',R.ssec)

for i=0,5 do
 local at,n=184+i*24,i+1
 f(L,'fuse_settings['..i..'].fuse_time',at,'f32','fuse','Fuse '..n..': time (s; -1: none)','引信 '..n..'：时间（秒，-1 为无）','引信 '..n..'：時間（秒，-1 為無）',R.ssec,{id='fuse'..n..'_time'})
 f(L,'fuse_settings['..i..'].unk_uint32_r0x0008',at+8,'u64','fuse','Fuse '..n..': unknown 64-bit value','引信 '..n..'：未知64位值','引信 '..n..'：未知64位值',R.hash,{id='fuse'..n..'_unk'})
 f(L,'fuse_settings['..i..'].unk_ability',at+16,'enum','fuse','Fuse '..n..': ability ID','引信 '..n..'：能力 ID','引信 '..n..'：能力 ID',R.enum,{id='fuse'..n..'_ability',enum_type='AbilityId'})
end

f(L,'dynamic_actor',0,'u32','actor','Physics actor (hash)','物理体（哈希）','物理體（雜湊）',R.hash)
f(L,'delayed_dynamic_actor',4,'u32','actor','Delayed physics actor (hash)','延迟物理体（哈希）','延遲物理體（雜湊）',R.hash)
f(L,'delayed_dynamic_actor_duration',8,'f32','actor','Delayed actor duration (s)','延迟物理体时长（秒）','延遲物理體時長（秒）',R.sec)
f(L,'vo_release',48,'u32','actor','Release voice line (hash)','投出语音（哈希）','投出語音（雜湊）',R.hash)
f(L,'animation_event_arm',52,'u32','actor','Arm animation event (hash)','举起动画事件（哈希）','舉起動畫事件（雜湊）',R.hash)
f(L,'animation_event',56,'u32','actor','Throw animation event (hash)','投掷动画事件（哈希）','投擲動畫事件（雜湊）',R.hash)
f(L,'animation_event_short',60,'u32','actor','Short throw animation event (hash)','短投动画事件（哈希）','短投動畫事件（雜湊）',R.hash)
f(L,'unk_ability',64,'enum','actor','Ability ID','能力 ID','能力 ID',R.enum,{enum_type='AbilityId'})

f(L,'on_thrown_audio_event',112,'u32','effects','Thrown sound (hash)','投出音效（哈希）','投出音效（雜湊）',R.hash)
f(L,'on_deflect_audio_event',116,'u32','effects','Deflect sound (hash)','弹开音效（哈希）','彈開音效（雜湊）',R.hash)
V.unit_effect(L,'thrown_trail_effect',120,'effects','Trail','尾迹','尾跡','trail')
f(L,'destroy_thrown_trail_effect_on_attach',168,'flag','effects','Trail removed on sticking','粘附时移除尾迹','黏附時移除尾跡',R.flag)

f(L,'unk_uint32_0x0044',68,'u32','unknown','Unknown integer +0x44','未知整数 +0x44','未知整數 +0x44',R.hash)
f(L,'0x62C74EDA.unk_enum_r0x0000',176,'enum','unknown','Unknown enum +0xB0','未知枚举 +0xB0','未知列舉 +0xB0',R.enum,{id='unk_enum_0x00B0',enum_type='0x62CD8710'})
f(L,'0x62C74EDA.unk_enum_r0x0004',180,'enum','unknown','Unknown enum +0xB4','未知枚举 +0xB4','未知列舉 +0xB4',R.enum,{id='unk_enum_0x00B4',enum_type='0x62CD8710'})
f(L,'unk_event_0x0148',328,'u32','unknown','Unknown event +0x148 (hash)','未知事件 +0x148（哈希）','未知事件 +0x148（雜湊）',R.hash)
f(L,'unk_event_0x014C',332,'u32','unknown','Unknown event +0x14C (hash)','未知事件 +0x14C（哈希）','未知事件 +0x14C（雜湊）',R.hash)
f(L,'unk_event_0x0150',336,'u32','unknown','Unknown event +0x150 (hash)','未知事件 +0x150（哈希）','未知事件 +0x150（雜湊）',R.hash)
-- (the dump names this unk_bool_0x0155, but the type library and the game's data put it at +0x154)
f(L,'unk_bool_0x0155',340,'flag','unknown','Unknown switch +0x154','未知开关 +0x154','未知開關 +0x154',R.flag,{id='unk_bool_0x0154',
 note={'The dump calls it +0x155; the type library and the game data put it at +0x154.','dump 中名为 +0x155，类型库与游戏数据确认在 +0x154。','dump 中名為 +0x155，類型庫與遊戲資料確認在 +0x154。'}})
f(L,'unk_enum_0x0158',344,'enum','unknown','Unknown enum +0x158','未知枚举 +0x158','未知列舉 +0x158',R.enum,{enum_type='0xC60F6AF4'})
f(L,'unk_float_0x015C',348,'f32','unknown','Unknown float +0x15C','未知浮点数 +0x15C','未知浮點數 +0x15C',R.raw)
f(L,'unk_bool_0x0160',352,'flag','unknown','Unknown switch +0x160','未知开关 +0x160','未知開關 +0x160',R.flag)
f(L,'unk_uint32_0x0164',356,'u32','unknown','Unknown integer +0x164','未知整数 +0x164','未知整數 +0x164',R.hash)
S.FIELDS=L
-- the record's members in the type library: offset, bytes (vectors, the trail effect, the 8-byte struct at +176
-- and the fuse array are one member each)
S.LAYOUT={{0,4},{4,4},{8,4},{12,4},{16,4},{20,1},{21,1},{24,12},{36,12},{48,4},{52,4},{56,4},{60,4},{64,4},{68,4},
 {72,4},{76,4},{80,4},{84,1},{88,4},{92,1},{93,1},{94,1},{96,4},{100,4},{104,4},{108,4},{112,4},{116,4},{120,48},
 {168,1},{172,4},{176,8},{184,144},{328,4},{332,4},{336,4},{340,1},{344,4},{348,4},{352,1},{356,4}}
S.NESTED={
 [24]=V.VEC3,[36]=V.VEC3,
 [120]={size=48,layout=V.UNIT_EFFECT.layout,nested={[8]=V.VEC3,[20]=V.VEC3}},
 [176]={size=8,layout={{0,4},{4,4}}},
 [184]={size=24,layout={{0,4},{8,8},{16,4}}},
}
return V.prepare(S)
