-- Entity components > Interference. Layouts are checked against the installed typelib, including byte fields
-- and padding. Only confirmed names are used: the historical Blocker schema names category/radius/start_active;
-- the original enemy editor identifies both radii and Scrambler strength/status. Remaining fields stay unknown.
local V=require('component_view')
local R,f=V.R,V.field
local M={SPECS={},SUBS={interference={}}}
local categories={
 [0]={'Close air support','近距空中支援','近距空中支援'},
 {'Orbital fire support','轨道火力支援','軌道火力支援'},
 {'Hellpod deployment','地狱舱部署','地獄艙部署'},
 {'Tactical air insertion','战术空中投送','戰術空中投送'},
 {'Special','特殊','特殊'},
 {'Orbital bombardment','轨道轰炸','軌道轟炸'},
 {'SEAF','SEAF','SEAF'},
 {'Count (no category selected)','Count（未指定类别）','Count（未指定類別）'},
}
local radius_note={
 'Distance from this entity. The original enemy editor treats zero or negative radii as unlimited, not disabled; use a small positive radius to restrict the area.',
 '以当前实体为中心的作用距离。原敌人编辑逻辑将 0 或负半径视为不限距离，而非关闭；限制范围请使用较小的正数。',
 '以目前實體為中心的作用距離。原敵人編輯邏輯將 0 或負半徑視為不限距離，而非關閉；限制範圍請使用較小的正數。',
}
local function add(s)
 s.SUB='interference';s.OPEN_ENUMS=true;s.STRICT=true
 s.ENUMS={category=categories}
 M.SPECS[#M.SPECS+1]=V.prepare(s)
 M.SUBS.interference[#M.SUBS.interference+1]=s.SLOT
end
do
 local s={TYPE='StratagemBlockerComponentData',HASH=0x8C5F8AB7,KEY='jammer',SIZE=20,SLACK=4,
  SLOT='StratagemBlockerComponents',FLAG='stratagem_blocker_component',
  COMPONENT={'Stratagem blocker component','战备干扰组件（StratagemBlocker）','戰備干擾組件（StratagemBlocker）'},
  TAB={'Stratagem blocker','战备干扰','戰備干擾'},GROUPS={
   {'range','Area and category','范围与类别','範圍與類別'},
   {'activation','Initial state','初始状态','初始狀態'},
   {'unknown','Unconfirmed fields','未确认字段','未確認欄位'},
  }}
 local fields={}
 f(fields,'category_type',0,'enum','range','Stratagem category','战备类别','戰備類別',R.enum,
  {enum='category',enum_type='StratagemCategoryType',note={
   'The historical schema describes this as the category exempt from blocking. Count (7) selects no exempt category. This interpretation is not a new in-game verification.',
   '旧版结构注释将其描述为不受干扰的战备类别；Count（7）表示未指定豁免类别。此解释尚未重新进行游戏内验证。',
   '舊版結構註釋將其描述為不受干擾的戰備類別；Count（7）表示未指定豁免類別。此解釋尚未重新進行遊戲內驗證。'}})
 f(fields,'block_radius',12,'f32','range','Jamming radius (m)','战备干扰半径（米）','戰備干擾半徑（米）',R.raw,
  {id='jam_radius',note=radius_note,verified=true})
 f(fields,'start_active',16,'u8','activation','Active on spawn (0/1)','生成时启用（0/1）','生成時啟用（0/1）',R.u8,
  {desc='If true then this stratagem blocker is active as soon as this entity exists.'})
 f(fields,'unk_enum_0x0004',4,'enum','unknown','Unknown mode +0x4','未知模式 +0x4','未知模式 +0x4',R.enum,
  {enum_type='0x5F7852C8',note={'The current enum declares 0, 1 and 2; their meanings are unknown.',
   '当前枚举声明 0、1、2，具体含义尚未确认。','目前列舉宣告 0、1、2，具體含義尚未確認。'}})
 f(fields,'unk_uint32_0x0008',8,'u32','unknown','Unknown integer +0x8','未知整数 +0x8','未知整數 +0x8',R.hash)
 s.FIELDS=fields
 s.LAYOUT={{0,4,16,0,0,0xCBDB3EC8},{4,4,16,0,0,0x5F7852C8},{8,4,6,0,0,0},
  {12,4,8,0,0,0},{16,1,4,0,0,0}}
 add(s)
end
do
 local s={TYPE='StratagemScramblerComponentData',HASH=0x595A2910,KEY='scrambler',SIZE=28,
  SLOT='StratagemScramblerComponents',FLAG='stratagem_scrambler_component',
  COMPONENT={'Stratagem scrambler component','战备扰码组件（StratagemScrambler）','戰備擾碼組件（StratagemScrambler）'},
  TAB={'Stratagem scrambler','战备扰码','戰備擾碼'},GROUPS={
   {'range','Area and category','范围与类别','範圍與類別'},
   {'effect','Scrambling effect','扰码效果','擾碼效果'},
   {'unknown','Unconfirmed fields','未确认字段','未確認欄位'},
  }}
 local fields={}
 f(fields,'category_type',0,'enum','range','Stratagem category','战备类别','戰備類別',R.enum,
  {enum='category',enum_type='StratagemCategoryType'})
 f(fields,'scramble_radius',12,'f32','range','Scrambling radius (m)','战备扰码半径（米）','戰備擾碼半徑（米）',R.raw,
  {id='scramble_radius',note=radius_note,verified=true})
 f(fields,'scramble_strength',16,'f32','effect','Scrambling strength','扰码强度','擾碼強度',R.raw,
  {note={'Strength identified by the original parser; the runtime scaling formula has not been verified.',
   '沿用原解析器确认的强度字段；运行时的换算公式尚未确认。','沿用原解析器確認的強度欄位；執行時的換算公式尚未確認。'}})
 f(fields,'status_effect',24,'i32','effect','Applied status effect ID','施加的状态效果 ID','施加的狀態效果 ID',R.i32,
  {enum_type='StatusEffectType',ref='status_effect_id',note={
   'Status applied to Helldivers in range. This is a local StatusEffectType ID, not a galactic effect ID. Double-click to open its definition.',
   '对范围内潜兵施加的状态；这是本地 StatusEffectType 编号，并非星球词条 ID。双击可打开对应定义。',
   '對範圍內潛兵施加的狀態；這是本地 StatusEffectType 編號，並非星球詞條 ID。雙擊可開啟對應定義。'}})
 f(fields,'unk_uint32_0x0004',4,'u32','unknown','Unknown integer +0x4','未知整数 +0x4','未知整數 +0x4',R.hash)
 for _,offset in ipairs({8,20,21})do
  local hex=string.format('%X',offset)
  f(fields,'unk_uint8_0x'..string.format('%04X',offset),offset,'u8','unknown',
   'Unknown byte +0x'..hex,'未知字节 +0x'..hex,'未知位元組 +0x'..hex,R.u8)
 end
 s.FIELDS=fields
 s.LAYOUT={{0,4,16,0,0,0xCBDB3EC8},{4,4,6,0,0,0},{8,1,4,0,0,0},{12,4,8,0,0,0},
  {16,4,8,0,0,0},{20,1,4,0,0,0},{21,1,4,0,0,0},{24,4,12,0,0,0x525E8B93}}
 add(s)
end
return M
