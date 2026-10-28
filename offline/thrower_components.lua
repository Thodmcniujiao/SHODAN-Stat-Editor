-- ThrowerComponentData (投掷器, 752 bytes): 2 formations of 376 bytes, each throwing panel_count x throwable_count
-- throwables (the minefield pods, the G-11 Caltrops) from nodes of the model. Layout from the type-library dump of
-- game 1.007.200 (Darctor/Helldivers2_RawData, ThrowerComponentData.json, 2026-10-20); unnamed fields keep the
-- dump's names (r0x: offset inside the formation). The editor already had formation 1's +40 / +44 counts, +248
-- arming time, +260 / +264 throw velocities and +280 spread (the minefield pages).
-- More panels or throwables than the model has nodes for crashes the game: the two counts only go down.
local V=require('component_view')
local R,f,vec3=V.R,V.field,V.vec3
local S={TYPE='ThrowerComponentData',KEY='thrower',SIZE=752,SLOT='ThrowerComponents',FLAG='thrower_component',
 COMPONENT={'Thrower component','投掷器组件（Thrower）','投擲器組件（Thrower）'}}
S.GROUPS={}
local L={}
local LOWER={'Lower only: more than the game\'s value crashes the game.','只能调低：超过游戏原值会使游戏崩溃。','只能調低：超過遊戲原值會使遊戲崩潰。'}
for i=1,2 do
 local base,p='formation_settings['..(i-1)..'].',i==1 and''or('f'..i..'_')
 local g={'f'..i,'f'..i..'_res','f'..i..'_effect','f'..i..'_nodes','f'..i..'_unknown'}
 local at=(i-1)*376
 local v=i==1   -- (formation 1: the fields the minefield pages had)
 f(L,base..'panel_count',at+40,'u32',g[1],'Panels','面板数','面板數',R.count,{id=p..'panels',most=true,verified=v,note=LOWER})
 f(L,base..'throwable_count',at+44,'u32',g[1],'Throwables per panel','每面板投掷物数','每面板投擲物數',R.count,{id=p..'per_panel',most=true,verified=v,note=LOWER})
 f(L,base..'throw_delay',at+240,'f32',g[1],'Throw delay (s)','抛射延迟（秒）','拋射延遲（秒）',R.sec,{id=p..'delay'})
 f(L,base..'throw_duration',at+244,'f32',g[1],'Throw duration (s)','抛射持续时间（秒）','拋射持續時間（秒）',R.sec,{id=p..'duration'})
 f(L,base..'arming_time',at+248,'f32',g[1],'Arming time (s)','解除保险时间（秒）','解除保險時間（秒）',R.sec,{id=p..'arming',verified=v})
 f(L,base..'spin_rpm',at+252,'f32',g[1],'Spin (rpm)','旋转转速（转/分）','旋轉轉速（轉/分）',R.rpm,{id=p..'spin'})
 f(L,base..'spindown_duration',at+256,'f32',g[1],'Spin-down time (s)','减速停转时间（秒）','減速停轉時間（秒）',R.sec,{id=p..'spindown'})
 f(L,base..'throw_velocity_min',at+260,'f32',g[1],'Throw velocity, min (m/s)','抛射速度最小值（米/秒）','拋射速度最小值（米/秒）',R.speed,{id=p..'velocity_min',verified=v})
 f(L,base..'throw_velocity_max',at+264,'f32',g[1],'Throw velocity, max (m/s)','抛射速度最大值（米/秒）','拋射速度最大值（米/秒）',R.speed,{id=p..'velocity_max',verified=v})
 f(L,base..'throw_pitch_offset',at+268,'f32',g[1],'Pitch offset (degrees)','俯仰偏移（度）','俯仰偏移（度）',R.deg,{id=p..'pitch'})
 f(L,base..'throw_yaw_offset',at+272,'f32',g[1],'Yaw offset (degrees)','偏航偏移（度）','偏航偏移（度）',R.deg,{id=p..'yaw'})
 f(L,base..'throw_roll_offset',at+276,'f32',g[1],'Roll offset (degrees)','滚转偏移（度）','滾轉偏移（度）',R.deg,{id=p..'roll'})
 f(L,base..'throw_spread_range',at+280,'f32',g[1],'Throw spread (degrees)','抛射散布（度）','拋射散布（度）',R.deg,{id=p..'spread',verified=v})

 f(L,base..'throwable_path',at,'u64',g[2],'Throwable (entity hash)','投掷物实体哈希','投擲物實體雜湊',R.hash,{id=p..'throwable'})
 f(L,base..'audio_node',at+12,'u32',g[2],'Audio node (hash)','音频节点（哈希）','音訊節點（雜湊）',R.hash,{id=p..'audio_node'})
 f(L,base..'spin_start_audio_event',at+16,'u32',g[2],'Spin start sound (hash)','开始旋转音效（哈希）','開始旋轉音效（雜湊）',R.hash,{id=p..'spin_start'})
 f(L,base..'spin_end_audio_event',at+20,'u32',g[2],'Spin end sound (hash)','停止旋转音效（哈希）','停止旋轉音效（雜湊）',R.hash,{id=p..'spin_end'})
 f(L,base..'mine_released_audio_event',at+24,'u32',g[2],'Released sound (hash)','投出音效（哈希）','投出音效（雜湊）',R.hash,{id=p..'released'})
 f(L,base..'mine_land_audio_event',at+28,'u32',g[2],'Landing sound (hash)','落地音效（哈希）','落地音效（雜湊）',R.hash,{id=p..'land'})

 V.unit_effect(L,base..'on_throw_effect',at+288,g[3],'Throw effect','抛射特效','拋射特效',p..'effect')

 for k=0,47 do
  f(L,base..'nodes['..k..']',at+48+k*4,'u32',g[4],'Node '..(k+1)..' (hash)','节点 '..(k+1)..'（哈希）','節點 '..(k+1)..'（雜湊）',R.hash,{id=p..'node'..(k+1)})
 end

 f(L,base..'unk_float_r0x0008',at+8,'f32',g[5],'Unknown float +0x08','未知浮点数 +0x08','未知浮點數 +0x08',R.raw,{id=p..'unk_08'})
 f(L,base..'unk_uint32_r0x0020',at+32,'u32',g[5],'Unknown integer +0x20','未知整数 +0x20','未知整數 +0x20',R.hash,{id=p..'unk_20'})
 f(L,base..'unk_uint32_r0x0024',at+36,'u32',g[5],'Unknown integer +0x24','未知整数 +0x24','未知整數 +0x24',R.hash,{id=p..'unk_24'})
 f(L,base..'unk_uint8_r0x0150',at+336,'u8',g[5],'Unknown byte +0x150','未知字节 +0x150','未知位元組 +0x150',R.u8,{id=p..'unk_150'})
 f(L,base..'unk_uint32_r0x0154',at+340,'u32',g[5],'Unknown integer +0x154','未知整数 +0x154','未知整數 +0x154',R.hash,{id=p..'unk_154'})
 f(L,base..'unk_uint64_r0x0158',at+344,'u64',g[5],'Unknown 64-bit value +0x158','未知64位值 +0x158','未知64位值 +0x158',R.hash,{id=p..'unk_158'})
 vec3(L,base..'unk_struct_r0x0160',at+352,g[5],'Unknown vector +0x160','未知向量 +0x160','未知向量 +0x160',R.raw,p..'unk_160')
 f(L,base..'unk_enum_r0x016C',at+364,'enum',g[5],'Ability ID +0x16C','能力 ID +0x16C','能力 ID +0x16C',R.enum,{id=p..'unk_16C',enum_type='AbilityId'})
 f(L,base..'unk_enum_r0x0170',at+368,'enum',g[5],'Ability ID +0x170','能力 ID +0x170','能力 ID +0x170',R.enum,{id=p..'unk_170',enum_type='AbilityId'})
end
S.FIELDS=L
-- groups: each kind for formation 1, then formation 2
for k,t in ipairs({{'','',''},{': resources and audio','：资源与音效','：資源與音效'},{': throw effect','：抛射特效','：拋射特效'},
 {': throw nodes','：抛射节点','：拋射節點'},{': unknown fields','：未知字段','：未知欄位'}})do
 for i=1,2 do
  local key='f'..i..({'','_res','_effect','_nodes','_unknown'})[k]
  S.GROUPS[#S.GROUPS+1]={key,'Formation '..i..t[1],'编队 '..i..t[2],'編隊 '..i..t[3]}
 end
end
-- the record: one member (formation_settings[2]); a formation, as laid out in the type library
local FORMATION={{0,8},{8,4},{12,4},{16,4},{20,4},{24,4},{28,4},{32,4},{36,4},{40,4},{44,4},{48,192},{240,4},{244,4},
 {248,4},{252,4},{256,4},{260,4},{264,4},{268,4},{272,4},{276,4},{280,4},{288,48},{336,1},{340,4},{344,8},{352,12},
 {364,4},{368,4}}
S.LAYOUT={{0,752}}
S.NESTED={[0]={size=376,layout=FORMATION,required=true,
 nested={[288]={size=48,layout=V.UNIT_EFFECT.layout,nested={[8]=V.VEC3,[20]=V.VEC3}},[352]=V.VEC3}}}
return V.prepare(S)
