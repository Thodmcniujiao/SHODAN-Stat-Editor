-- TurretComponentData (炮塔, 76 bytes): how a turret turns (speeds, limits) and sounds. Layout from the
-- type-library dump of game 1.007.200 (Darctor/Helldivers2_RawData, TurretComponentData.json, 2026-10-20),
-- checked against the game's type library and data (74 entities). The sentries' turn speeds (+8 vertical,
-- +12 horizontal) are the same fields.
local V=require('component_view')
local R,f=V.R,V.field
local S={TYPE='TurretComponentData',KEY='turret',SIZE=76,SLOT='TurretComponents',FLAG='turret_component',
 COMPONENT={'Turret component','炮塔组件（Turret）','砲塔組件（Turret）'}}
S.GROUPS={
 {'turn','Turning','转动','轉動'},
 {'limits','Limits','转动范围','轉動範圍'},
 {'nodes','Nodes','节点','節點'},
 {'audio','Audio','音效','音效'},
}
local L={}
f(L,'turn_speed_horizontal',12,'f32','turn','Turn speed, horizontal (deg/s)','水平转速（度/秒）','水平轉速（度/秒）',R.rate,{verified=true,id='turn_h'})
f(L,'turn_speed_vertical',8,'f32','turn','Turn speed, vertical (deg/s)','垂直转速（度/秒）','垂直轉速（度/秒）',R.rate,{verified=true,id='turn_v'})
f(L,'ratio_exponent',16,'f32','turn','Speed ratio exponent','转速比例指数','轉速比例指數',R.raw)
f(L,'horizontal_limit_min',28,'f32','limits','Horizontal limit, min (degrees)','水平最小角（度）','水平最小角（度）',R.deg)
f(L,'horizontal_limit_max',32,'f32','limits','Horizontal limit, max (degrees)','水平最大角（度）','水平最大角（度）',R.deg)
f(L,'vertical_limit_min',20,'f32','limits','Vertical limit, min (degrees)','垂直最小角（度）','垂直最小角（度）',R.deg)
f(L,'vertical_limit_max',24,'f32','limits','Vertical limit, max (degrees)','垂直最大角（度）','垂直最大角（度）',R.deg)
f(L,'horizontal',4,'u32','nodes','Horizontal turning node (hash)','水平转动节点（哈希）','水平轉動節點（雜湊）',R.hash)
f(L,'vertical',0,'u32','nodes','Vertical turning node (hash)','垂直转动节点（哈希）','垂直轉動節點（雜湊）',R.hash)
f(L,'pivot_node',72,'u32','nodes','Pivot node (hash)','枢轴节点（哈希）','樞軸節點（雜湊）',R.hash)
f(L,'trigger_rotation_sound_timer',36,'f32','audio','Turning sound delay (s)','水平转动音效触发时间（秒）','水平轉動音效觸發時間（秒）',R.sec)
f(L,'trigger_pitch_sound_timer',40,'f32','audio','Pitching sound delay (s)','俯仰音效触发时间（秒）','俯仰音效觸發時間（秒）',R.sec)
f(L,'rotation_start_event',44,'u32','audio','Turning start sound (hash)','水平转动开始音效（哈希）','水平轉動開始音效（雜湊）',R.hash)
f(L,'rotation_stop_event',48,'u32','audio','Turning stop sound (hash)','水平转动停止音效（哈希）','水平轉動停止音效（雜湊）',R.hash)
f(L,'unk_event_0x0034',52,'u32','audio','Unknown event +0x34 (hash)','未知事件 +0x34（哈希）','未知事件 +0x34（雜湊）',R.hash)
f(L,'unk_event_0x0038',56,'u32','audio','Unknown event +0x38 (hash)','未知事件 +0x38（哈希）','未知事件 +0x38（雜湊）',R.hash)
f(L,'pitch_start_event',60,'u32','audio','Pitching start sound (hash)','俯仰开始音效（哈希）','俯仰開始音效（雜湊）',R.hash)
f(L,'pitch_stop_event',64,'u32','audio','Pitching stop sound (hash)','俯仰停止音效（哈希）','俯仰停止音效（雜湊）',R.hash)
f(L,'warning_event',68,'u32','audio','Warning sound (hash)','警告音效（哈希）','警告音效（雜湊）',R.hash)
S.FIELDS=L
S.LAYOUT={}
for o=0,72,4 do S.LAYOUT[#S.LAYOUT+1]={o,4}end
return V.prepare(S)
