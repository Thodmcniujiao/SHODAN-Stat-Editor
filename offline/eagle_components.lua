-- EagleComponentData (飞鹰组件, 336 bytes): how an Eagle strike approaches, fires or drops bombs, strafes,
-- evades and plays audio/effects. Layout from the game's type library and Darctor/Helldivers2_RawData
-- (EagleComponentData.json, 2026-10-20, 11 entities), with 2024 descriptions from shalzuth/HelldiversData.
local V=require('component_view')
local R,f,vec3=V.R,V.field,V.vec3
local S={TYPE='EagleComponentData',KEY='eagle',SIZE=336,HASH=0x556FF68B,SLOT='EagleComponents',FLAG='eagle_component',
 COMPONENT={'Eagle component','飞鹰组件（Eagle）','飛鷹組件（Eagle）'}}
S.NAMES={
 ['23A60681DD4383EC']='Eagle Strafing Run',
 ['2EA01CB1676ACA29']='Eagle Airstrike',
 ['1B3BCADABC7EF8D6']='Eagle Smoke Strike',
 ['E44B691DC039A505']='Eagle 500kg Bomb',
 ['9D4F7CB4EB34515D']='Eagle Cluster Bomb',
 ['2A275BB78BB20148']='Eagle Fly BY',
 ['DBB286AD7ED9DF96']='Eagle Gas Airstrike',
 ['0BD0F9D59048E9D1']='(Not Used) Additional Strafing Runs',
 ['DFBB9A0D8FA27D85']='(Not Used) Air-TO-Air Missles',
 ['27BB558C893383CC']='Eagle Napalm Airstrike',
 ['397792815583DA29']='Eagle 110mm Rocket Pods',
}
S.OPEN_ENUMS=true
S.ENUMS={
 e0656AA08={
  [0]={'None','无（None）','無（None）'},
  [1]={'DoubleStrafe','双机扫射（DoubleStrafe）','雙機掃射（DoubleStrafe）'},
  [2]={'Strafe','机枪扫射（Strafe）','機槍掃射（Strafe）'},
  [3]={'Missile','空对空导弹（Missile）','空對空導彈（Missile）'},
  [4]={'Rocket','火箭巢（Rocket）','火箭巢（Rocket）'},
  [5]={'Airstrike','空袭投弹（Airstrike）','空襲投彈（Airstrike）'},
  [6]={'CarpetBombing','地毯式轰炸（CarpetBombing）','地毯式轟炸（CarpetBombing）'},
 },
 e50E28C2A={
  [0]={'6Z','6枚Z字（6Z）','6枚Z字（6Z）'},
  [1]={'Smoke_6Z','烟雾6枚Z字（Smoke_6Z）','煙霧6枚Z字（Smoke_6Z）'},
  [2]={'8Z','8枚Z字（8Z）','8枚Z字（8Z）'},
  [3]={'8line_ClusterBomb','8枚集束直线（Cluster）','8枚集束直線（Cluster）'},
  [4]={'4line_Napalm_MK1','4枚直线 MK1（Napalm_MK1）','4枚直線 MK1（Napalm_MK1）'},
  [5]={'5line_Napalm_MK2','5枚直线 MK2（Napalm_MK2）','5枚直線 MK2（Napalm_MK2）'},
  [6]={'5line_Napalm_MK3','5枚直线 MK3 / 500kg','5枚直線 MK3 / 500kg'},
  [7]={'Single','单枚投弹（Single）','單枚投彈（Single）'},
 },
}
S.GROUPS={
 {'attack','Payload and attack','载荷与攻击','載荷與攻擊'},
 {'approach','Approach and flight','进场与飞行','進場與飛行'},
 {'targeting','Targeting and strafing run','索敌与扫射航线','索敵與掃射航線'},
 {'effects','Audio and effects','音效与特效','音效與特效'},
 {'0x19CCA20E','Unnamed struct 0x19CCA20E (+0x8C)','未命名结构 0x19CCA20E（+0x8C）','未命名結構 0x19CCA20E（+0x8C）'},
 {'0x2308DBEC','Unnamed struct 0x2308DBEC (+0xA8)','未命名结构 0x2308DBEC（+0xA8）','未命名結構 0x2308DBEC（+0xA8）'},
 {'0x2C2D1CF9','Unnamed struct 0x2C2D1CF9 (+0xFC)','未命名结构 0x2C2D1CF9（+0xFC）','未命名結構 0x2C2D1CF9（+0xFC）'},
 {'unknown','Unknown fields','未知字段','未知欄位'},
}
local L={}
-- Payload and attack
f(L,'payload',16,'enum','attack','Payload type','载荷类型','載荷類型',R.enum,
 {id='payload',enum='e0656AA08',enum_type='EaglePayload',desc='Type of payload.'})
f(L,'airstrike_pattern',20,'enum','attack','Airstrike drop pattern','空袭投弹排列','空襲投彈排列',R.enum,
 {id='airstrike_pattern',enum='e50E28C2A',enum_type='EagleAirstrikePattern',desc='Type of pattern to use for airstrike payloads.'})
f(L,'projectile_type',24,'enum','attack','Projectile ID','射弹 ID','射彈 ID',R.enum,
 {id='projectile_type',enum_type='ProjectileType',ref='projectile_id',desc='Type of projectile for payloads that use one.'})
f(L,'fire_duration',52,'f32','attack','Fire duration (s)','开火持续时间（秒）','開火持續時間（秒）',R.sec,
 {id='eagle_fire_time',verified=true,desc='Fire duration for weapons-based attacks (strafe, gunpods, rockets).'})
f(L,'bomb_interval',56,'f32','attack','Time between bombs (s)','投弹间隔（秒）','投彈間隔（秒）',R.sec,
 {id='eagle_bomb_gap',verified=true,desc='Time between bombs are dropped after the first, and then successive ones.'})
f(L,'bomb_prediction_interval',60,'f32','attack','Bomb prediction interval (s)','投弹预测重算间隔（秒）','投彈預測重算間隔（秒）',R.sec,
 {id='bomb_prediction_interval',desc='Time between re-evaluations on the bomb drop logic.'})

-- Approach and flight
f(L,'target_angle',40,'f32','approach','Approach target angle (degrees)','进场目标角度（度）','進場目標角度（度）',R.deg,
 {id='target_angle',desc='Approach angle. 0 is front-to-back, 180 is back-to-front, relative to the stratagem ball and the helldiver.'})
f(L,'approach_min_distance',64,'f32','approach','Approach min distance (m)','最小进场距离（米）','最小進場距離（米）',{0,10000,10,100},
 {id='eagle_approach',verified=true,desc='Minimum approach distance.'})
f(L,'approach_max_distance',68,'f32','approach','Approach max distance (m)','最大进场距离（米）','最大進場距離（米）',{0,10000,10,100},
 {id='eagle_approach_2',verified=true,desc='Maximum approach distance.'})
f(L,'approach_max_height',72,'f32','approach','Approach max height (m)','最大进场高度（米）','最大進場高度（米）',{0,10000,10,100},
 {id='approach_max_height',desc='Maximum approach height.'})
f(L,'num_angles_to_try',76,'f32','approach','Angles to try per height','每高度尝试进场角度数','每高度嘗試進場角度數',R.raw,
 {id='num_angles_to_try',desc='Number of angles to try per height.'})
f(L,'num_heights_to_try',84,'f32','approach','Heights to try','尝试进场高度层数','嘗試進場高度層數',R.raw,
 {id='num_heights_to_try',desc='Number of heights to try (from min to max, evenly spaced).'})
f(L,'attack_movespeed',92,'f32','approach','Speed until it has fired (m/s)','攻击飞行速度（米/秒）','攻擊飛行速度（米/秒）',{0,5000,10,50},
 {id='eagle_speed',verified=true,desc='Speed of the eagle until it is done firing.'})
f(L,'evade_movespeed',96,'f32','approach','Evade speed after firing (m/s)','脱离飞行速度（米/秒）','脫離飛行速度（米/秒）',{0,5000,10,50},
 {id='evade_movespeed',desc='Speed of the eagle after it is done firing.'})
f(L,'damaged_movespeed',100,'f32','approach','Damaged move speed (m/s)','受损飞行速度（米/秒）','受損飛行速度（米/秒）',{0,5000,10,50},
 {id='damaged_movespeed',desc='Speed of the eagle when damaged.'})
f(L,'acceleration',104,'f32','approach','Acceleration','飞行加速度','飛行加速度',R.raw,
 {id='acceleration',desc='Acceleration of the eagle.'})
f(L,'deceleration',108,'f32','approach','Deceleration','飞行减速度','飛行減速度',R.raw,
 {id='deceleration',desc='Deceleration of the eagle.'})
f(L,'damage_cooldown',112,'f32','approach','Damaged repair cooldown (s)','受损强制维修冷却（秒）','受損強制維修冷卻（秒）',R.sec,
 {id='damage_cooldown',desc='When the eagle dies (takes a lot of damage), it gets an additional cooldown for repairs of this many seconds.'})

-- Targeting and strafing run
f(L,'search_radius',48,'f32','targeting','Target search radius (m)','目标搜索半径（米）','目標搜索半徑（米）',R.m,
 {id='search_radius',desc='Radius in which to search for targets. Not used for the dive bomb.'})
f(L,'master_target_position_adjustment',116,'f32','targeting','Master target position adjustment (m)','主目标位置最大修正距离（米）','主目標位置最大修正距離（米）',R.m,
 {id='master_target_position_adjustment',desc='How far away from the stratagem ball can we go in order to find a better mass target?'})
f(L,'master_target_enemy_count',120,'f32','targeting','Master target enemy count','主目标修正所需敌人数','主目標修正所需敵人數',R.raw,
 {id='master_target_enemy_count',desc='Between how many enemies should we be trying to adjust the master target?'})
f(L,'strafing_run_length',124,'f32','targeting','Strafing run length (m)','扫射航线长度（米）','掃射航線長度（米）',R.m,
 {id='eagle_run_length',verified=true,desc='The length of the strafing run in meters. It starts half the length before the stratagem\'s location.'})
f(L,'strafing_run_target_adjustment',128,'f32','targeting','Strafing run target adjustment (m)','扫射航线横向修正距离（米）','掃射航線橫向修正距離（米）',R.m,
 {id='strafing_run_target_adjustment',desc='How many meters can we strafe away from the strafing run in order to hit an enemy?'})
f(L,'strafing_run_target_bias_time',132,'f32','targeting','Strafing run target bias time (s)','扫射目标提前量时间（秒）','掃射目標提前量時間（秒）',R.sec,
 {id='strafing_run_target_bias_time'})
f(L,'strafing_run_fire_distance',136,'f32','targeting','Strafing run fire distance (m)','扫射开火距离（米）','掃射開火距離（米）',R.m,
 {id='strafing_run_fire_distance'})

-- Audio and effects
f(L,'flyby_event',0,'u32','effects','Fly-by audio event (hash)','掠过音效事件（哈希）','掠過音效事件（雜湊）',R.hash,
 {id='flyby_event',desc='(Wwise sound) Fly-by audio event.'})
f(L,'strafing_fire_over_event',4,'u32','effects','Strafing fire-over audio event (hash)','扫射结束音效事件（哈希）','掃射結束音效事件（雜湊）',R.hash,
 {id='strafing_fire_over_event',desc='(Wwise sound) For air support and other strafe eagles.'})
f(L,'flyby_distance',8,'f32','effects','Fly-by audio trigger distance (m)','触发掠过音效距离（米）','觸發掠過音效距離（米）',R.m,
 {id='flyby_distance',desc='When the eagle gets inside this distance, trigger the fly-by audio event.'})
f(L,'flyby_cooldown',12,'f32','effects','Fly-by audio cooldown (s)','掠过音效最小间隔（秒）','掠過音效最小間隔（秒）',R.sec,
 {id='flyby_cooldown',desc='Minimum time between fly-by audio events.'})
f(L,'engine_start_audio',300,'u32','effects','Engine start audio event (hash)','引擎启动音效事件（哈希）','引擎啟動音效事件（雜湊）',R.hash,
 {id='engine_start_audio',desc='(Wwise sound) Sound to trigger when the eagle spawns'})
f(L,'engine_stop_audio',304,'u32','effects','Engine stop audio event (hash)','引擎停止音效事件（哈希）','引擎停止音效事件（雜湊）',R.hash,
 {id='engine_stop_audio',desc='(Wwise sound) Sound to trigger when the eagle despawns'})
f(L,'sonic_boom_effect',312,'u64','effects','Sonic boom effect (resource hash)','音爆粒子特效（资源哈希）','音爆粒子特效（資源雜湊）',R.hash,
 {id='sonic_boom_effect',desc='(particle effect) Sonic boom particle effect.'})

-- Unnamed struct 0x19CCA20E (+140, 28 bytes)
f(L,'0x19CCA20E.unk_uint32_r0x0000',140,'u32','0x19CCA20E','Unknown integer +0x00','未知整数 +0x00','未知整數 +0x00',R.count,{id='0x19CCA20E_unk_uint32_r0x0000'})
f(L,'0x19CCA20E.unk_float_r0x0004',144,'f32','0x19CCA20E','Unknown float +0x04','未知浮点数 +0x04','未知浮點數 +0x04',R.raw,{id='0x19CCA20E_unk_float_r0x0004'})
f(L,'0x19CCA20E.unk_uint32_r0x0008',148,'u32','0x19CCA20E','Unknown integer +0x08','未知整数 +0x08','未知整數 +0x08',R.count,{id='0x19CCA20E_unk_uint32_r0x0008'})
f(L,'0x19CCA20E.unk_float_r0x000C',152,'f32','0x19CCA20E','Unknown float +0x0C','未知浮点数 +0x0C','未知浮點數 +0x0C',R.raw,{id='0x19CCA20E_unk_float_r0x000C'})
f(L,'0x19CCA20E.unk_struct_r0x0010.x',156,'f32','0x19CCA20E','Unknown vector +0x10 X','未知向量 +0x10 X','未知向量 +0x10 X',R.raw,{id='0x19CCA20E_unk_struct_r0x0010_x'})
f(L,'0x19CCA20E.unk_struct_r0x0010.y',160,'f32','0x19CCA20E','Unknown vector +0x10 Y','未知向量 +0x10 Y','未知向量 +0x10 Y',R.raw,{id='0x19CCA20E_unk_struct_r0x0010_y'})
f(L,'0x19CCA20E.unk_uint32_r0x0018',164,'u32','0x19CCA20E','Unknown integer +0x18','未知整数 +0x18','未知整數 +0x18',R.count,{id='0x19CCA20E_unk_uint32_r0x0018'})

-- Unnamed struct 0x2308DBEC (+168, 84 bytes: 7 vectors of 12 bytes)
for i,ro in ipairs({0x00,0x0C,0x18,0x24,0x30,0x3C,0x48})do
 local hex=string.format('0x%04X',ro)
 local short=string.format('+0x%X',ro)
 vec3(L,'0x2308DBEC.unk_struct_r'..hex,168+ro,'0x2308DBEC','Unknown vector '..short,'未知向量 '..short,'未知向量 '..short,R.raw,'0x2308DBEC_unk_struct_r'..hex)
end

-- Unnamed struct 0x2C2D1CF9 (+252, 40 bytes: 3 vectors of 12 bytes + 1 flag at +0x24)
for i,ro in ipairs({0x00,0x0C,0x18})do
 local hex=string.format('0x%04X',ro)
 local short=string.format('+0x%X',ro)
 vec3(L,'0x2C2D1CF9.unk_struct_r'..hex,252+ro,'0x2C2D1CF9','Unknown vector '..short,'未知向量 '..short,'未知向量 '..short,R.raw,'0x2C2D1CF9_unk_struct_r'..hex)
end
f(L,'0x2C2D1CF9.unk_bool_0x0024',288,'flag','0x2C2D1CF9','Unknown switch +0x24','未知开关 +0x24','未知開關 +0x24',R.flag,{id='0x2C2D1CF9_unk_bool_0x0024'})

-- Unknown top-level fields
f(L,'unk_uint64_0x0020',32,'u64','unknown','Unknown 64-bit value +0x20','未知64位值 +0x20','未知64位值 +0x20',R.hash,{id='unk_uint64_0x0020'})
f(L,'unk_bool_0x002C',44,'flag','unknown','Unknown switch +0x2C','未知开关 +0x2C','未知開關 +0x2C',R.flag,{id='unk_bool_0x002C'})
f(L,'unk_float_0x0050',80,'f32','unknown','Unknown float +0x50','未知浮点数 +0x50','未知浮點數 +0x50',R.raw,{id='unk_float_0x0050'})
f(L,'unk_float_0x0058',88,'f32','unknown','Unknown float +0x58','未知浮点数 +0x58','未知浮點數 +0x58',R.raw,{id='unk_float_0x0058'})
f(L,'unk_float_0x0124',292,'f32','unknown','Unknown float +0x124','未知浮点数 +0x124','未知浮點數 +0x124',R.raw,{id='unk_float_0x0124'})
f(L,'unk_float_0x0128',296,'f32','unknown','Unknown float +0x128','未知浮点数 +0x128','未知浮點數 +0x128',R.raw,{id='unk_float_0x0128'})
f(L,'unk_float_0x0140',320,'f32','unknown','Unknown float +0x140','未知浮点数 +0x140','未知浮點數 +0x140',R.raw,{id='unk_float_0x0140'})
f(L,'unk_float_0x0144',324,'f32','unknown','Unknown float +0x144','未知浮点数 +0x144','未知浮點數 +0x144',R.raw,{id='unk_float_0x0144'})
f(L,'unk_float_0x0148',328,'f32','unknown','Unknown float +0x148','未知浮点数 +0x148','未知浮點數 +0x148',R.raw,{id='unk_float_0x0148'})
f(L,'unk_bool_0x014C',332,'flag','unknown','Unknown switch +0x14C','未知开关 +0x14C','未知開關 +0x14C',R.flag,{id='unk_bool_0x014C'})
f(L,'unk_bool_0x014D',333,'flag','unknown','Unknown switch +0x14D','未知开关 +0x14D','未知開關 +0x14D',R.flag,{id='unk_bool_0x014D'})
f(L,'unk_bool_0x014E',334,'flag','unknown','Unknown switch +0x14E','未知开关 +0x14E','未知開關 +0x14E',R.flag,{id='unk_bool_0x014E'})

S.FIELDS=L
S.LAYOUT={{0,4},{4,4},{8,4},{12,4},{16,4},{20,4},{24,4},{32,8},{40,4},{44,1},{48,4},{52,4},{56,4},{60,4},{64,4},{68,4},
 {72,4},{76,4},{80,4},{84,4},{88,4},{92,4},{96,4},{100,4},{104,4},{108,4},{112,4},{116,4},{120,4},{124,4},{128,4},{132,4},
 {136,4},{140,28},{168,84},{252,40},{292,4},{296,4},{300,4},{304,4},{312,8},{320,4},{324,4},{328,4},{332,1},{333,1},{334,1}}
S.NESTED={
 [140]={size=28,required=true,layout={{0,4},{4,4},{8,4},{12,4},{16,8},{24,4}},nested={[16]={size=8,required=true,layout={{0,4},{4,4}}}}},
 [168]={size=84,required=true,layout={{0,12},{12,12},{24,12},{36,12},{48,12},{60,12},{72,12}},
  nested={[0]=V.VEC3,[12]=V.VEC3,[24]=V.VEC3,[36]=V.VEC3,[48]=V.VEC3,[60]=V.VEC3,[72]=V.VEC3}},
 [252]={size=40,required=true,layout={{0,12},{12,12},{24,12},{36,1}},
  nested={[0]=V.VEC3,[12]=V.VEC3,[24]=V.VEC3}},
}
return V.prepare(S)
