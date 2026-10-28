-- StratagemInfo (StratagemType enum + stable record id), current 400-byte layout.
-- Descriptors are checked against the installed game's type library. Reference INIs may contain
-- out-of-bounds button/payload reads; only the serialized array counts are authoritative.
local M={SIZE=400,TYPE=0x7BD60854}
M.NAMES={
 StratagemTypeID={'StratagemTypeID','战备类型 ID','戰備類型 ID'},
 Name={'Name','战备名称（调试名）','戰備名稱（偵錯名）'},
 button_combination={'Call-in code','战备指令','戰備指令'},
 Category={'Category','战备类别','戰備類別'}, Uses={'Uses','使用次数（-1 为无限）','使用次數（-1 為無限）'},
 SpawnTime={'SpawnTime','投放前倒计时（秒）','投放前倒數時間（秒）'},
 SpawnRadius={'SpawnRadius','生成半径（米）','生成半徑（米）'},
 BeaconingTime={'BeaconingTime','信标持续时间（秒）','信標持續時間（秒）'},
 ExtraTravelTime={'ExtraTravelTime','额外运输时间（秒）','額外運輸時間（秒）'},
 Cooldown={'Cooldown','冷却时间（秒）','冷卻時間（秒）'},
 CooldownIfFail={'CooldownIfFail','呼叫失败冷却（秒）','呼叫失敗冷卻（秒）'},
 OriginType={'OriginType','发射来源类型','發射來源類型'}, CallInType={'CallInType','呼叫方式类型','呼叫方式類型'},
 ObjectiveRequirement={'ObjectiveRequirement','目标投放条件','目標投放條件'},
 StratagemFlags={'StratagemFlags','呼叫逻辑标志','呼叫邏輯旗標'},
 CooldownType={'CooldownType','冷却共享类型','冷卻共用類型'},
 PayloadSpawnPosition={'PayloadSpawnPosition','载荷数量（旧字段名）','載荷數量（舊欄位名）'},
 Package={'Package','资源包哈希','資源包雜湊'}, Icon={'Icon','图标资源哈希','圖示資源雜湊'},
 HUDType={'HUDType','HUD 显示类型','HUD 顯示類型'}, Cost={'Cost','消耗点数','消耗點數'},
 IsEnabled={'IsEnabled','启用战备','啟用戰備'},
 DependsOnStratagemID={'DependsOnStratagemID','依赖战备 ID','依賴戰備 ID'},
 AdditionalStratagemID={'AdditionalStratagemID','附加战备 ID','附加戰備 ID'},
 MaxInLoadout={'MaxInLoadout','装备栏携带上限','裝備欄攜帶上限'},
 BeaconColor={'BeaconColor','信标颜色','信標顏色'},
 ShipLaserPointer={'ShipLaserPointer','舰船激光指示','艦船雷射指示'},
 AltCooldown={'AltCooldown','使用备用冷却','使用備用冷卻'},
 ExtraHellpods={'ExtraHellpods','额外地狱潜舱数量','額外地獄潛艙數量'},
 RecordID={'RecordID','记录标识 ID','記錄識別 ID'}, VideoID={'VideoID','演示视频 ID','示範影片 ID'},
 NameUpperTextID={'NameUpperTextID','大写名称文本 ID','大寫名稱文字 ID'},
 NameCasedTextID={'NameCasedTextID','常规名称文本 ID','一般名稱文字 ID'},
 DescriptionTextID={'DescriptionTextID','说明文本 ID','說明文字 ID'},
 FluffTextID={'FluffTextID','背景描述文本 ID','背景描述文字 ID'},
 LoadingTextID={'LoadingTextID','加载提示文本 ID','載入提示文字 ID'},
 MissionSpecific={'MissionSpecific','任务专用标志','任務專用旗標'}, Selectable={'Selectable','允许选择','允許選擇'},
 TriggersWar={'TriggersWar','触发战争状态','觸發戰爭狀態'},
 ReadyVO={'ReadyVO','准备就绪语音 ID','準備就緒語音 ID'}, DeniedVO={'DeniedVO','呼叫拒绝语音 ID','呼叫拒絕語音 ID'},
 ConfirmationVOOwner={'ConfirmationVOOwner','持有者确认语音 ID','持有者確認語音 ID'},
 CalloutVO={'CalloutVO','呼叫提示语音 ID','呼叫提示語音 ID'}, DamageDealer={'DamageDealer','伤害归属实体哈希','傷害歸屬實體雜湊'},
 MatchingSupportWeapon={'MatchingSupportWeapon','关联支援武器 ID','關聯支援武器 ID'},
 DLCPackID={'DLCPackID','DLC 资源包 ID','DLC 資源包 ID'},
 IsClanStratagem={'IsClanStratagem','公会战备标志','公會戰備旗標'},
 InfoFlags={'InfoFlags','战备信息标志','戰備資訊旗標'},
 SpottableVOLine={'SpottableVOLine','标记语音 ID','標記語音 ID'},
 SharedStratagemUpgradesType={'SharedStratagemUpgradesType','共享升级的战备类型','共用升級的戰備類型'},
 SharedStratagemUpgradesCategories={'SharedStratagemUpgradesCategories','共享升级类别标志','共用升級類別旗標'},
 HellpodTargetOffset={'HellpodTargetOffset','潜舱目标偏移数组','潛艙目標偏移陣列'},
 HellpodAdditionalRotationInTau={'HellpodAdditionalRotationInTau','潜舱额外旋转数组（圈）','潛艙額外旋轉陣列（圈）'},
 EquipmentTags={'EquipmentTags','装备标签数组','裝備標籤陣列'},
 Customizations={'Customizations','自定义项数组','自訂項目陣列'},
 AllowForButtonOverlap={'AllowForButtonOverlap','允许指令重叠','允許指令重疊'},
 DeployOnNavmeshOnly={'DeployOnNavmeshOnly','仅在导航网格上部署','僅在導航網格上部署'},
 PayloadUnitCustomization={'PayloadUnitCustomization','载荷单位外观类型','載荷單位外觀類型'},
}
function M.names(name)
 if M.NAMES[name]then return M.NAMES[name]end
 local n=name:match('^Button(%d+)$')
 if n then return{name,'指令方向 '..n,'指令方向 '..n}end
 n=name:match('^Payload(%d+)$')
 if n then return{name,'载荷 '..n..'（实体哈希）','載荷 '..n..'（實體雜湊）'}end
 local off,bit=name:match('^Field_(%d+)_Bit(%d+)$')
 if off then return{'Unknown bit +'..off..':'..bit,'未知位 +'..off..':'..bit,'未知位元 +'..off..':'..bit}end
 off=name:match('^Field_(%d+)$')
 if off then return{'Unknown field +'..off,'未知字段 +'..off,'未知欄位 +'..off}end
 return{name,name,name}
end
-- name, offset, storage, min, max, small, big, legacy stat id (when present)
M.FIELDS={
 {'Category',60,'u32',0,32,1,1}, {'Uses',80,'i32',-1,100000,1,5,'uses'},
 {'SpawnTime',84,'f32',0,10000,.5,5,'callin'}, {'SpawnRadius',88,'f32',0,10000,1,5},
 {'BeaconingTime',96,'f32',0,10000,.5,5}, {'ExtraTravelTime',100,'f32',0,10000,.5,5},
 {'Cooldown',104,'f32',0,100000,1,10,'cooldown'}, {'CooldownIfFail',108,'f32',0,100000,1,10},
 {'OriginType',112,'u32',0,32,1,1}, {'CallInType',116,'u32',0,32,1,1},
 {'ObjectiveRequirement',124,'u32',0,1000,1,1}, {'StratagemFlags',120,'u16',0,65535,1,16},
 {'CooldownType',148,'u32',0,32,1,1}, {'HUDType',184,'u32',0,32,1,1},
 {'Cost',188,'i32',-1,1000000,1,5}, {'IsEnabled',192,'bit0',0,1,1,1},
 {'DependsOnStratagemID',196,'u32',0,100000,1,1},
 {'AdditionalStratagemID',200,'u32',0,100000,1,1,'extra'},
 {'MaxInLoadout',204,'u32',0,1000,1,1}, {'BeaconColor',212,'u32',0,32,1,1},
 {'ShipLaserPointer',216,'bit0',0,1,1,1}, {'AltCooldown',296,'bit0',0,1,1,1},
 {'ExtraHellpods',300,'u32',0,1000,1,1},
}
-- Additional fields whose semantic names are known from the schema/reference component definitions.
M.EXTRA={
 {'VideoID',8,'u32'}, {'NameUpperTextID',40,'u32'}, {'NameCasedTextID',44,'u32'},
 {'DescriptionTextID',48,'u32'}, {'FluffTextID',52,'u32'}, {'LoadingTextID',56,'u32'},
 {'Field_092',92,'f32'}, {'MissionSpecific',128,'bit0'}, {'Selectable',128,'bit1'},
 {'TriggersWar',144,'bit0'}, {'Field_208',208,'bit0'},
 {'ReadyVO',220,'u32'}, {'DeniedVO',224,'u32'}, {'ConfirmationVOOwner',228,'u32'},
 {'CalloutVO',232,'u32'}, {'MatchingSupportWeapon',248,'u32'}, {'DLCPackID',252,'u32'},
 {'IsClanStratagem',256,'bit0'}, {'InfoFlags',260,'u32'}, {'SpottableVOLine',264,'u32'},
 {'SharedStratagemUpgradesType',268,'u32'}, {'SharedStratagemUpgradesCategories',272,'u8'},
 {'Field_296_Bit1',296,'bit1'}, {'AllowForButtonOverlap',368,'bit0'},
 {'DeployOnNavmeshOnly',368,'bit1'}, {'PayloadUnitCustomization',372,'u32'}, {'Field_392',392,'u32'},
}
M.HASHES={{'Package',168},{'Icon',176},{'Field_136',136},{'DamageDealer',240}}
M.STRINGS={{'Name',16},{'Field_024',24},{'Field_032',32}}
M.ARRAYS={{'Field_280',280},{'HellpodTargetOffset',304},{'HellpodAdditionalRotationInTau',320},
          {'EquipmentTags',336},{'Customizations',352},{'Field_376',376}}
M.LAYOUT={
 {0,4,16},{4,4,6},{8,4,6},{16,8,18},{24,8,18},{32,8,18},{40,4,6},{44,4,6},{48,4,6},{52,4,6},{56,4,6},
 {60,4,16},{64,16,16,1},{80,4,6},{84,4,8},{88,4,8},{92,4,8},{96,4,8},{100,4,8},{104,4,8},{108,4,8},
 {112,4,16},{116,4,16},{120,2,20},{124,4,16},{128,1,4,3},{128,1,4,3},{136,8,7},{144,1,4,3},
 {148,4,16},{152,16,7,1},{168,8,7},{176,8,7},{184,4,16},{188,4,6},{192,1,4,3},{196,4,16},{200,4,16},
 {204,4,6},{208,1,4,3},{212,4,16},{216,1,4,3},{220,4,6},{224,4,6},{228,4,6},{232,4,6},{240,8,7},
 {248,4,6},{252,4,6},{256,1,4,3},{260,4,20},{264,4,6},{268,4,16},{272,1,20},{280,16,20,1},
 {296,1,4,3},{296,1,4,3},{300,4,6},{304,16,20,1},{320,16,8,1},{336,16,6,1},{352,16,6,1},
 {368,1,4,3},{368,1,4,3},{372,4,16},{376,16,20,1},{392,4,16},
}
function M.check_layout(schemas)
 local row=schemas and schemas[M.TYPE]
 if not row or row.size~=M.SIZE or #row.members~=#M.LAYOUT then return nil,'StratagemInfo layout differs from the verified 400-byte record'end
 for i,e in ipairs(M.LAYOUT)do
  local a=row.members[i]
  if a.offset~=e[1]or a.size~=e[2]or a.storage~=e[3]or a.atom~=(e[4]or 0)then
   return nil,'StratagemInfo member '..i..' differs from the verified layout'
  end
  if a.atom==3 and a.count~=(i>1 and M.LAYOUT[i-1][1]==e[1]and 257 or 1)then
   return nil,'StratagemInfo bitfield packing differs'
  end
 end
 return true
end
-- Decimal unsigned 64-bit input -> two exact uint32 halves. No conversion through a Lua double.
function M.parse_u64(text)
 if type(text)~='string'or not text:match('^%d+$')then return nil,'Enter an unsigned decimal integer.'end
 local lo,hi=0,0
 for d in text:gmatch('.')do
  local n=lo*10+tonumber(d);lo=n%4294967296;hi=hi*10+math.floor(n/4294967296)
  if hi>4294967295 then return nil,'Value exceeds uint64 (18446744073709551615).'end
 end
 return lo,hi
end
function M.u64_text(lo,hi)
 local digits={0}
 for _,v in ipairs({hi,lo})do
  local carry=v
  for i=1,#digits do local n=digits[i]*4294967296+carry;digits[i]=n%10;carry=math.floor(n/10)end
  while carry>0 do digits[#digits+1]=carry%10;carry=math.floor(carry/10)end
 end
 local out={};for i=#digits,1,-1 do out[#out+1]=tostring(digits[i])end
 return table.concat(out)
end
return M
