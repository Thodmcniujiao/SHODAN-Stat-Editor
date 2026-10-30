-- StatusEffectInfo: old decrypted names, current record and nested layouts.
local M={TYPE=0xC63E0B22,SIZE=160}
M.GROUP_ORDER={'basic','parameters','damage','modifiers','terrain','effects','scripts','animation','audio','flags','unknown'}
M.GROUPS={
 basic={'Identity and name','标识与名称','識別與名稱'},parameters={'Strength and duration','强度与持续时间','強度與持續時間'},
 damage={'Damage reference','伤害引用','傷害引用'},effects={'Shading and particles','着色与粒子特效','著色與粒子特效'},
 scripts={'Script and notification events','脚本与通知事件','腳本與通知事件'},audio={'Audio','音效','音效'},
 animation={'Animation events','动画事件','動畫事件'},terrain={'Terrain','地形','地形'},
 flags={'Status flags','状态标志','狀態旗標'},modifiers={'Stat multipliers','属性倍率','屬性倍率'},unknown={'Unknown fields','未知字段','未知欄位'},
}
M.FIELDS={
 {'type',0,'id','basic','状态效果 ID','狀態效果 ID','status_effect_id','status_effect_id'},
 {'debug_name',8,'string','basic','调试名称（只读）','偵錯名稱（唯讀）'},
 {'strength',36,'f32','parameters','状态强度','狀態強度'},
 {'duration',40,'f32','parameters','持续时间（秒）','持續時間（秒）'},
 {'damage_info_type',44,'u32','damage','伤害 ID','傷害 ID','damage_ref','damage_id'},
 {'damage_ignore_avatar_armor',48,'bit0','damage','伤害忽略玩家护甲','傷害忽略玩家護甲'},
 {'shader_variable_preset',16,'u32','effects','着色器变量预设','著色器變數預設'},
 {'shading_environment',24,'u64','effects','着色环境资源哈希','著色環境資源雜湊'},
 {'shading_environment_fade_time',32,'f32','effects','着色环境渐变时间（秒）','著色環境漸變時間（秒）'},
 {'particle_effect_path',56,'u64','effects','粒子特效资源哈希','粒子特效資源雜湊'},
 {'script_event_start',64,'u32','scripts','脚本开始事件 ID','腳本開始事件 ID'},
 {'script_event_stop',68,'u32','scripts','脚本停止事件 ID','腳本停止事件 ID'},
 {'notify_event_on_added',128,'u32','scripts','添加时通知事件 ID','加入時通知事件 ID'},
 {'notify_event_on_removed',132,'u32','scripts','移除时通知事件 ID','移除時通知事件 ID'},
 {'wwise_state',72,'u32','audio','Wwise 音频状态（原始值）','Wwise 音訊狀態（原始值）'},
 {'audio_event_start',76,'u32','audio','音效开始事件 ID','音效開始事件 ID'},
 {'audio_event_stop',80,'u32','audio','音效停止事件 ID','音效停止事件 ID'},
 {'audio_event_enter',84,'u32','audio','音效进入事件 ID','音效進入事件 ID'},
 {'audio_event_exit',88,'u32','audio','音效退出事件 ID','音效離開事件 ID'},
 {'animation_event_start',92,'u32','animation','动画开始事件 ID','動畫開始事件 ID'},
 {'animation_event_stop',96,'u32','animation','动画停止事件 ID','動畫停止事件 ID'},
 {'difficult_terrain_amount',100,'f32','terrain','困难地形影响量','困難地形影響量'},
 {'status_flags',104,'u8','flags','状态标志（原始值）','狀態旗標（原始值）'},
 {'modified_stats_multipliers',112,'array','modifiers','属性倍率项数量（只读）','屬性倍率項數量（唯讀）'},
 {'unk_bool_0x0088',136,'bit0','unknown','未知标志位 +0x88','未知旗標位元 +0x88'},
 {'unk_uint32_0x008C',140,'u32','unknown','未知整数 +0x8C','未知整數 +0x8C'},
 {'unk_array_0x0090',144,'array','unknown','未知复合数组项数（只读）','未知複合陣列項數（唯讀）'},
}
M.BITS={
 {'unique_effect',104,0,'flags','唯一效果','唯一效果'},
 {'no_susceptibility_required',104,1,'flags','无需易感性判定','無需易感性判定'},
 {'audio_event_master_only',104,2,'flags','音效事件仅主控端','音效事件僅主控端'},
 {'block_sprint',104,3,'flags','禁止冲刺','禁止衝刺'},
}
M.ARRAYS={
 {name='modified_stats_multipliers',offset=112,stride=8,value_offsets={4},fields={
  {'type',0,'u32','属性类型（ModifiableStatType）','屬性類型（ModifiableStatType）'},
  {'value',4,'f32','属性倍率','屬性倍率'},
 }},
 {name='unk_array_0x0090',offset=144,stride=24,value_offsets={4},fields={
  {'enum_0x00',0,'u32','未知枚举 +0x00','未知列舉 +0x00'},
  {'float_0x04',4,'f32','未知浮点数 +0x04','未知浮點數 +0x04'},
  {'uint64_0x08',8,'u64','未知64位值 +0x08','未知64位值 +0x08'},
  {'uint32_0x10',16,'u32','未知整数 +0x10','未知整數 +0x10'},
  {'uint32_0x14',20,'u32','未知整数 +0x14','未知整數 +0x14'},
 }},
}
M.LEGACY={StatusEffectTypeID='type',Name='debug_name',Strength='strength',Duration='duration',UseDamageID='damage_info_type'}
M.LAYOUT={};M.FLOAT_OFFSETS={}
for _,s in ipairs(M.FIELDS)do local off,typ=s[2],s[3]
 if off~=104 then
  M.LAYOUT[#M.LAYOUT+1]={off,typ=='array'and 16 or(typ=='string'or typ=='u64')and 8 or typ=='bit0'and 1 or 4,
   off==0 and 12 or(off==16 or off==44)and 16 or typ=='string'and 18 or typ=='u64'and 7 or typ=='array'and 20 or typ=='f32'and 8 or typ=='bit0'and 4 or 6,
   typ=='array'and 1 or typ=='bit0'and 3 or 0,typ=='bit0'and 1 or 0}
 end
 if typ=='f32'then M.FLOAT_OFFSETS[#M.FLOAT_OFFSETS+1]=off end
end
for _,s in ipairs(M.BITS)do M.LAYOUT[#M.LAYOUT+1]={104,1,4,3,s[3]*256+1}end
table.sort(M.LAYOUT,function(a,b)return a[1]==b[1]and a[5]<b[5]or a[1]<b[1]end)
function M.check_layout(schemas)
 local t=schemas and schemas[M.TYPE];local a=t and t.members and t.members[1];local r=a and schemas[a.type]
 if not t or t.size~=16 or #t.members~=1 or a.atom~=1 or a.storage~=20 or not r or r.size~=M.SIZE or #r.members~=#M.LAYOUT then return nil end
 local arrays={}
 for i,e in ipairs(M.LAYOUT)do local m=r.members[i]
  if m.offset~=e[1]or m.size~=e[2]or m.storage~=e[3]or m.atom~=e[4]or m.count~=e[5]then return nil end
  if m.atom==1 then arrays[m.offset]=schemas[m.type]end
 end
 local expected={
  [112]={8,{{0,4,16,923660010},{4,4,8,0}}},
  [144]={24,{{0,4,16,3111737540},{4,4,8,0},{8,8,7,0},{16,4,6,0},{20,4,6,0}}},
 }
 for off,e in pairs(expected)do local x=arrays[off]
  if not x or x.size~=e[1]or #x.members~=#e[2]then return nil end
  for i,v in ipairs(e[2])do local m=x.members[i]
   if m.offset~=v[1]or m.size~=v[2]or m.storage~=v[3]or m.type~=v[4]or m.atom~=0 then return nil end
  end
 end
 return true
end
return M
