-- Native armor passive records, including each modifier's operation and both
-- weapon-stat operands. Existing value IDs are retained for configs/presets.
local M={TYPE=0x63CE0FEB,MODIFIER=0xB5EE1FE9,STAT=0xD269EE03}
M.OPERATIONS={
 [0]={'Set','设置','設定'},[1]={'Add (negative values subtract)','加法（负值为减少）','加法（負值為減少）'},
 [2]={'Multiply','乘法／倍率','乘法／倍率'},[3]={'Time','时间','時間'}}
M.HELP={
 passive_bonus={{'The game uses this ID to refer to the whole armor passive. It is read-only here; it is not a strength or a multiplier.',
  '游戏用这个编号引用整条护甲词条。这里仅供查看；它不是强度，也不是倍率。',
  '遊戲用這個編號引用整條護甲詞條。這裡僅供查看；它不是強度，也不是倍率。'}},
 name_loc={{'Text-table ID for the passive name shown in the armory. Enter an existing text ID, not the name itself.',
  '军械库显示的词条名称在游戏文本表中的编号。这里填写已有文本 ID，不是直接填写名称文字。',
  '軍械庫顯示的詞條名稱在遊戲文字表中的編號。這裡填寫已有文字 ID，不是直接填寫名稱文字。'},
  {'Changes the displayed name; does not change the passive effects below.',
   '修改的是显示名称，不会改变下方词条的实际效果。','修改的是顯示名稱，不會改變下方詞條的實際效果。'}},
 icon={{'64-bit resource hash for the passive icon. Changes the picture, not the effects or their strength.',
  '词条图标所引用的 64 位资源哈希。它影响显示的图标，不控制效果类型或强度。',
  '詞條圖示所引用的 64 位資源雜湊。它影響顯示的圖示，不控制效果類型或強度。'}},
 modifier_id={{'Identifies which effect this entry modifies, such as noise, detection range or leg-injury immunity. Read-only reference.',
  '标识这一项针对什么效果，例如噪音、探测范围或腿部受伤免疫。这里只读显示。',
  '標識這一項針對什麼效果，例如噪音、探測範圍或腿部受傷免疫。這裡唯讀顯示。'},
  {'Use Operation to choose the calculation and Value to set the operand; this ID is neither of those.',
   '计算方式看“运算方式”，使用多少看“数值”；这个 ID 不代表加减乘，也不代表大小。',
   '計算方式看「運算方式」，使用多少看「數值」；這個 ID 不代表加減乘，也不代表大小。'}},
 modifier_type={{'Chooses how this effect uses the Value below. The number on the right is the operation code, not its strength.',
  '决定本项效果怎样使用下方的“数值”。右侧数字是运算编号，不是效果强度。',
  '決定本項效果怎樣使用下方的「數值」。右側數字是運算編號，不是效果強度。'},
  {'Set: replace with the entered value. Add: add it; negative values subtract. Multiply: scale by it; 1 stays unchanged.',
   '设置：直接指定数值；加法：增加该数值，负值表示减少；乘法：按倍率缩放，1 表示不变。',
   '設定：直接指定數值；加法：增加該數值，負值表示減少；乘法：按倍率縮放，1 表示不變。'},
  {'Example for a base value of 100: Set 20 -> 20; Add -20 -> 80; Multiply 0.5 -> 50.',
   '以原值 100 为例：设置 20 → 20；加法 -20 → 80；乘法 0.5 → 50。',
   '以原值 100 為例：設定 20 → 20；加法 -20 → 80；乘法 0.5 → 50。'},
  {'Time is the native time-effect mode. Its units and calculation depend on the effect and are not fully verified; it is not a subtraction mode.',
   '时间是游戏原有的时间类模式。具体单位及计算规则依效果而定，尚未完整核实；它不是“减少”模式。',
   '時間是遊戲原有的時間類模式。具體單位及計算規則依效果而定，尚未完整核實；它不是「減少」模式。'}},
 value={{'The raw operand used by Operation above. Changing the operation leaves this number untouched.',
  '与上方“运算方式”配合使用的原始数值。切换运算方式时，这个数不会自动换算。',
  '與上方「運算方式」配合使用的原始數值。切換運算方式時，這個數不會自動換算。'},
  {'For example, Multiply 0.5 means half the target parameter; Add -0.5 means reduce it by 0.5. These are different edits.',
   '例如：乘法 0.5 表示目标参数减半；加法 -0.5 表示目标参数减少 0.5，两者含义不同。',
   '例如：乘法 0.5 表示目標參數減半；加法 -0.5 表示目標參數減少 0.5，兩者含義不同。'},
  {'A larger target parameter is not always better: an incoming-damage multiplier scales damage taken.',
   '目标参数变大不一定代表效果更好，例如“受到伤害”的倍率改变的是承受的伤害。',
   '目標參數變大不一定代表效果更好，例如「受到傷害」的倍率改變的是承受的傷害。'}},
 desc_loc={{'Text-table ID for this effect\'s armory description. Changes the description text, not its numeric effect.',
  '这一项效果在军械库里的说明文字 ID。改变的是说明文字，不会把说明里的数字自动同步到实际效果。',
  '這一項效果在軍械庫裡的說明文字 ID。改變的是說明文字，不會把說明裡的數字自動同步到實際效果。'},
  {'0 omits this description line; it does not turn off the modifier. The combination writer keeps at most three described lines.',
   '0 表示不显示这一条说明，不等于关闭该项效果。护甲组合写入时最多保留三条说明。',
   '0 表示不顯示這一條說明，不等於關閉該項效果。護甲組合寫入時最多保留三條說明。'}},
 type={{'Identifies the weapon property this entry modifies, such as reload speed or recoil. This is a property ID, not the operation code.',
  '指定这一项修改哪个武器属性，例如换弹速度或后坐力。这是属性编号，不是运算方式编号。',
  '指定這一項修改哪個武器屬性，例如換彈速度或後座力。這是屬性編號，不是運算方式編號。'}},
 add_value={{'An additive operand for this weapon property. 0 adds nothing; negative values reduce it.',
  '对这个武器属性附加的加法值。0 表示不额外加减，负值表示减少。',
  '對這個武器屬性附加的加法值。0 表示不額外加減，負值表示減少。'},
  {'Independent of Multiplier below. The engine\'s ordering when both operands are used is not yet verified.',
   '它与下方“倍率”是两个独立数值。两者同时使用时，游戏内先加后乘还是先乘后加尚未核实。',
   '它與下方「倍率」是兩個獨立數值。兩者同時使用時，遊戲內先加後乘還是先乘後加尚未核實。'}},
 mul_value={{'Scales this weapon property: 1 is unchanged, 0.5 is half, 2 is double (with no additive change).',
  '这个武器属性的缩放倍率：不额外加减时，1 为不变，0.5 为一半，2 为两倍。',
  '這個武器屬性的縮放倍率：不額外加減時，1 為不變，0.5 為一半，2 為兩倍。'},
  {'The benefit depends on the property: reducing recoil differs from reducing reload speed.',
   '具体收益取决于属性本身，例如减少后坐力与降低换弹速度的意义不同。',
   '具體收益取決於屬性本身，例如減少後座力與降低換彈速度的意義不同。'}},
 unknown_0x30={{'Only its position and uint32 storage type are confirmed. There is no reliable explanation of its function yet.',
  '目前只确认了字段位置和 uint32 存储类型，暂时没有可靠的功能解释。',
  '目前只確認了欄位位置和 uint32 儲存類型，暫時沒有可靠的功能解釋。'}}}
M.LAYOUT={
 [M.TYPE]={56,{{0,4,16,0},{4,4,6,0},{8,8,7,0},{16,16,20,1,M.MODIFIER},{32,16,20,1,M.STAT},{48,4,6,0}}},
 [M.MODIFIER]={16,{{0,4,6,0},{4,4,16,0},{8,4,8,0},{12,4,6,0}}},
 [M.STAT]={12,{{0,4,16,0},{4,4,8,0},{8,4,8,0}}}}
function M.check_layout(schemas)
 for typ,spec in pairs(M.LAYOUT)do
  local actual=schemas and schemas[typ]
  if not actual or actual.size~=spec[1]or #actual.members~=#spec[2]then return false end
  for i,want in ipairs(spec[2])do local m=actual.members[i]
   if m.offset~=want[1]or m.size~=want[2]or m.storage~=want[3]or m.atom~=want[4]
     or(want[5]and m.type~=want[5])then return false end
  end
 end
 return true
end
local function u32(b,o)
 if o<0 or o+4>#b then return end
 local a,c,d,e=b:byte(o+1,o+4);return a+c*256+d*65536+e*16777216
end
function M.parse(blob,address,header,schemas)
 if #blob<56 or(schemas and not M.check_layout(schemas))then return nil,'passive layout does not match this build'end
 local id,mc,sc=u32(blob,0),u32(blob,24),u32(blob,40)
 if u32(blob,28)~=0 or u32(blob,44)~=0 then return nil,'invalid passive array header'end
 local function array(at,count,stride)
  if count==0 then return 0 end
  local lo,hi=u32(blob,at),u32(blob,at+4)
  local offset=lo+hi*4294967296-(address or 0)-(header or 24)
  if offset<56 or count>math.floor((#blob-56)/stride)or offset+count*stride>#blob then return end
  return offset
 end
 local mo,so=array(16,mc,16),array(32,sc,12)
 if not mo or not so then return nil,'passive array outside record'end
 if mc>0 and sc>0 and mo<so+sc*12 and so<mo+mc*16 then return nil,'overlapping passive arrays'end
 local index={id=id,name=u32(blob,4),mods={},stats={}}
 for k=0,mc-1 do local off=mo+k*16
  index.mods[#index.mods+1]={id=u32(blob,off),type=u32(blob,off+4),record_offset=off,
   type_offset=off+4,offset=off+8,description_offset=off+12}
 end
 for k=0,sc-1 do local off=so+k*12
  index.stats[#index.stats+1]={stat=u32(blob,off),record_offset=off,add_offset=off+4,offset=off+8}
 end
 return index,mc+sc
end

function M.build(entry,index,c)
 local tx,part=c.text,c.part
 local sections={['Passive definition']={'Passive definition','词条定义','詞條定義'},
  ['Passive']={'Passive','被动','被動'},['Weapon stats']={'Weapon stats','武器属性','武器屬性'},
  ['Other fields']={'Other fields','其他字段','其他欄位'}}
 local function label_text(label)return type(label)=='function'and label()or label end
 local function decorate(row,label)
  row.label_of=function()return label_text(label)end
  row.section_of=function()return tx(sections[row.section])end
 end
 local function tip(row,path,offset,storage,extra)
  row.armor_passive_path=path
  row.tip_of=function()
   local lines={}
   for _,note in ipairs(M.HELP[path:match('%.([^%.]+)$')or path]or{})do lines[#lines+1]=tx(note)end
   if extra then for _,s in ipairs(extra())do lines[#lines+1]=s end end
   lines[#lines+1]=tx({'Original field: ','原始字段：','原始欄位：'})..path
   lines[#lines+1]=string.format('HelldiverCustomizationPassiveBonusSettings +0x%X · %s',offset,storage)
   return lines
  end
 end
 local function editable(section,id,label,offset,storage,small)
  local r=c.add(entry,section,id,label_text(label),storage,{part(id,entry.passive,offset,storage,4294967295)},
   0,storage=='f32'and 3.4028234663852886e38 or 4294967295,small or 1,storage=='f32'and 1 or 10)
  decorate(r,label)
  return r
 end
 local function identity(section,id,label,value,path,offset)
  local r=c.add(entry,section,id,label_text(label),'u32',{},0,4294967295,1,1)
  decorate(r,label);r.empty=true;r.readonly_text=tostring(value)
  tip(r,path,offset,'u32',function()return{tx({'Record identity (read-only)','记录标识（只读）','記錄標識（唯讀）'})}end)
  return r
 end
 local definition='Passive definition'
 identity(definition,'passive_id',function()return tx({'Passive ID','词条 ID','詞條 ID'})end,index.id,'passive_bonus',0)
 local name=editable(definition,'passive_name_loc',function()return tx({'Name text ID','名称文本 ID','名稱文字 ID'})end,4,'u32')
 tip(name,'name_loc',4,'u32')
 local icon=c.add(entry,definition,'passive_icon',tx({'Icon resource hash','图标资源哈希','圖示資源雜湊'}),'u64',
  {part('passive_icon_lo',entry.passive,8,'u32'),part('passive_icon_hi',entry.passive,12,'u32')},0,4294967295,1,1)
 icon.hash64=true;tip(icon,'icon',8,'u64')
 decorate(icon,function()return tx({'Icon resource hash','图标资源哈希','圖示資源雜湊'})end)
 local used={}
 for k,m in ipairs(index.mods)do
  local base=string.format('mod_%08X',m.id);local id=base
  if used[id]then id=id..'_'..k end;used[id]=true
  local function title()
   return c.translate(c.mod_names[m.id]or c.mod_names[c.joined[m.id]]or string.format('Modifier %08X',m.id))..
    (c.joined[m.id]and(' · '..string.format('%08X',m.id))or'')
  end
  local path='modifiers['..(k-1)..']'
  identity('Passive',id..'_id',function()return title()..' · ID'end,m.id,path..'.modifier_id',m.record_offset)
  local op=editable('Passive',id..'_type',function()return title()..' · '..tx({'Operation','运算方式','運算方式'})end,m.type_offset,'u32')
  op.label_of=function()
   local value=c.read(op.parts[1].field);local label=M.OPERATIONS[value]
   return title()..' · '..tx({'Operation','运算方式','運算方式'})..': '..
    (label and tx(label)or(tx({'Unknown','未确认','未確認'})..' '..tostring(value)))
  end
  tip(op,path..'.modifier_type',m.type_offset,'HelldiverCustomizationPassiveBonusModifierType (u32)',function()
   local lines={}
   for n=0,3 do lines[#lines+1]=n..' = '..tx(M.OPERATIONS[n])end
   lines[#lines+1]=tx({'Changing the operation keeps the raw value.','切换运算方式时保留原数值。','切換運算方式時保留原數值。'})
   return lines
  end)
  local v=editable('Passive',id,function()return title()..' · '..tx({'Value','数值','數值'})end,m.offset,'f32',.1)
  tip(v,path..'.value',m.offset,'f32',function()return{op.label_of()}end)
  local desc=editable('Passive',id..'_desc',function()return title()..' · '..tx({'Description text ID','说明文本 ID','說明文字 ID'})end,m.description_offset,'u32')
  tip(desc,path..'.desc_loc',m.description_offset,'u32',function()
   local id=c.read(desc.parts[1].field);return{id and c.game_text and c.game_text(id)or''}
  end)
 end
 used={}
 for k,st in ipairs(index.stats)do
  local id='stat_'..st.stat;if used[id]then id=id..'_'..k end;used[id]=true
  local function title()return c.translate(c.stat_names[st.stat]or('Stat '..st.stat))end
  local path='stat_modifiers['..(k-1)..']'
  identity('Weapon stats',id..'_id',function()return title()..' · ID'end,st.stat,path..'.type',st.record_offset)
  local add=editable('Weapon stats',id..'_add',function()return title()..' · '..tx({'Addend','加法值','加法值'})end,st.add_offset,'f32',.1)
  tip(add,path..'.add_value',st.add_offset,'f32')
  local mul=editable('Weapon stats',id,function()return title()..' · '..tx({'Multiplier','倍率','倍率'})end,st.offset,'f32',.05)
  tip(mul,path..'.mul_value',st.offset,'f32')
 end
 local unknown=editable('Other fields','passive_unknown_0x30',
  function()return tx({'Unknown uint32 +0x30','未知 uint32 +0x30','未知 uint32 +0x30'})end,48,'u32')
 tip(unknown,'unknown_0x30',48,'u32',function()return{tx({'Meaning unconfirmed; location/type verified against the current type library.',
  '含义尚未确认；位置与类型已按当前类型库核对。','含義尚未確認；位置與類型已按目前類型庫核對。'})}end)
end
return M
