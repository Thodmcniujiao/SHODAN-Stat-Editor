-- The four-digit catalogue is a wire namespace. Keep explicit icon/effect pairs
-- and verified local references visible, without flattening them into one owner.
local G=require('galactic_effects')
local J=require('json_data')
local D=require('demolition')
local PLANETS=require('planet_effect_view')
local M={titles={}}
local FIELD_TEXT={
 gameplayEffectId32={'Internal gameplay identifier (unconfirmed)','内部效果标识（用途待确认）'},
 effectType={'Effect category','效果类别'},flags={'Raw flags (bits unconfirmed)','原始标志（位含义待确认）'},
 nameHash={'Name text hash','名称文本哈希'},descriptionFluffHash={'Flavour text hash','背景说明文本哈希'},
 descriptionGamePlayLongHash={'Long effect-description hash','完整效果说明文本哈希'},
 descriptionGamePlayShortHash={'Short effect-description hash','简短效果说明文本哈希'},
 valueTypes={'Payload types','载荷类型'},values={'Effect payload','实际效果载荷'}}
local FIELD_HELP={
 effectType='决定如何解释载荷，例如 32 临时战备、40 敌群标签、71 银河表现。不是星球编号。',
 flags='原响应的位标志；具体位用途尚未确认，不是给星球启用词条的开关。',
 gameplayEffectId32='原响应的内部效果标识；具体关联机制尚未确认，不用于选择目标星球。',
 nameHash='引用名称文字，不会把词条添加到星球，也不控制实际玩法。',
 descriptionFluffHash='引用背景说明文字；零值表示此响应没有提供这项引用。',
 descriptionGamePlayLongHash='引用完整效果说明文字；不决定效果是否在某颗星球启用。',
 descriptionGamePlayShortHash='引用简短效果说明文字；不是效果编号。',
 valueTypes='描述 values 各项的载荷类型；不是组件 TypeID 的局部索引。',
 values='实际参数随效果类别不同，可包含资源引用、数量或倍率。添加现有词条到星球无需修改此项。'}
local TYPES={
 [21]={'Extraction timing','撤离时间'},[23]={'Eagle rearm','飞鹰重新武装'},
 [24]={'Vehicle fuel','载具燃油'},[25]={'Starting ammunition','起始弹药'},
 [32]={'Temporary stratagem','临时战备'},[36]={'Stratagem cooldown','战备冷却'},
 [40]={'Enemy tag / variant effect','敌群标签／变种生效'},[56]={'Ammunition pickup','弹药拾取'},
 [61]={'Starting stims','起始治疗针'},[69]={'Reinforcements','增援'},
 [71]={'Galactic presence / visual definition','银河表现／图标定义'},
 [72]={'Enemy spawn adjustment','敌人生成调整'},[73]={'Gloom','阴霾'},
 [77]={'Regeneration override','再生覆盖'},[80]={'Stim capacity','治疗针容量'},
 [83]={'Booster','强化资源'},[87]={'DSS tactical action','DSS 战术动作'},
 [94]={'Local modifier definition','本地修饰定义'}}
local function plain(s)return(s or''):gsub('<[^>]*>',''):gsub('[\r\n]+',' ')end
local function title(entry,lang)
 local zh=lang=='zh-Hans'or lang=='zh-Hant'
 local name=entry[zh and'name_zh'or'name_en']
 if not name or name==''then
  -- Historical names can embed old magnitudes. Payload numbers below are current.
  name=entry.reference_name and entry.reference_name:gsub('%b()',''):gsub('（.-）','')
  if name and(name:match('^未知')or name=='')then name=nil end
 end
 return plain(name or(zh and'未确认名称的词条'or'Unnamed effect'))
end
function M.translate_name(name,lang)
 local f=M.titles[name];return f and f(lang)
end
function M.reload()
 local fresh=G.new()
 if fresh.error then M.model.error=fresh.error;return nil,fresh.error end
 M.model.cfg,M.model.stale,M.model.error=fresh.cfg,fresh.stale,nil
 M.model.revision=M.model.revision+1
 return true
end
function M.build(c,page,txt,pages)
 local model=G.new();M.model=model;M.titles={};M.by_id={}
 M.assignment_model=require('planet_effects').new()
 if model.error and c.log then c.log(model.error)end
 local locals,modifiers={},{}
 for _,p in ipairs(pages.PlanetSpace or{})do if p.planet_root==4177128510 then
  local debug=p.name:match('^GalacticPresenceSettings · (.-) %[#%d+%]')
  if debug then
   local key=tonumber(D.hex(D.hash_resource(debug)):sub(1,8),16)
   locals[key]=locals[key]or{};locals[key][#locals[key]+1]=p
  end
 end end
 for _,p in ipairs(pages.PlanetModifiers or{})do if p.modifier_id then modifiers[p.modifier_id]=p end end
 local function local_targets(kind,values)
  return(kind==71 and locals[values[1]]or kind==94 and modifiers[values[1]]and{modifiers[values[1]]})or{}
 end
 local function row(p,id,label,section)
  local r={id=id,label=id,label_of=label,parts={},storage='u32',min=0,max=4294967295,section=section,
   section_of=function()return txt(section,({['Wire definition']='网络词条定义',['Identity']='编号与实际作用',
    ['Linked local definitions']='关联的本地定义',['Planet assignment']='星球词条分配'})[section]or section)end,
   component='GalacticWarEffect',component_of=function()return txt('GalacticWarEffects definition','银河词条定义（GalacticWarEffects）')end}
  p.rows[#p.rows+1]=r;return r
 end
 local function info(p,id,label,value,section)
  local r=row(p,id,label,section or'Identity');r.empty=true;r.readonly_text=value;r.tip_of=function()return{label(),type(value)=='function'and value()or tostring(value)}end;return r
 end
 local function action(p,id,label,target)
  local r=row(p,id,label,'Linked local definitions');r.custom_value=function()return 0 end
  r.custom_text=function()return txt('Open definition','打开定义')end
  r.custom_action=function()return c.open_page and c.open_page(target)end
 end
 for _,entry in ipairs(G.data.effects)do
  local base=entry.definition;local id=base.id;local role=model.roles[id]
  local function name(lang)
   local z=lang=='zh-Hans'or lang=='zh-Hant'
   local suffix=role and(role.kind=='effect'and(z and' [生效]'or' [effect]')or(z and' [图标]'or' [icon]'))or''
   return string.format('%04d · %s%s',id,title(entry,lang),suffix)
  end
  local p=page('PlanetEffectIds',name('en'),'galactic-effect/'..id);p.effect_id=id
  M.titles[p.name]=name;M.by_id[id]=p
  p.search=p.search..' '..name('zh-Hans')..' '..plain(entry.reference_note)..' '..base.effectType..' '..J.encode(base.values)
  local targets=local_targets(model:read(id,'effectType'),model:read(id,'values'))
  p.local_definition_targets=targets
  for _,target in ipairs(targets)do p.search=p.search..' '..target.name end
  p.search_extra=function()return J.encode(model:read(id,'values'))..' '..model:read(id,'effectType')end
  p.custom_modified=function()return model:changed(id)end
  p.custom_reset=function()return model:reset(id)end
  p.note_of=function()return txt('Network definitions save beside the program; the supplied proxy must load them. Local links use Write to game.',
   '网络定义便携保存，需附带代理加载；关联的本地参数仍用“写入游戏”。')end
  p.ensure_rows=function()
   local revision=model.revision..':'..M.assignment_model.revision
   if p.rows_built and p.definition_revision==revision then return end
   p.rows_built,p.definition_revision,p.rows=true,revision,{}
   local current_type=model:read(id,'effectType')
   local targets=local_targets(current_type,model:read(id,'values'));p.local_definition_targets=targets
   info(p,'id',function()return'galacticEffectId'end,tostring(id))
   info(p,'role',function()return txt('Role in original definition','原定义的作用')end,function()
    if role then return role.kind=='effect'and txt('Gameplay effect; separate icon ID ','实际生效词条；独立图标 ID ')..role.other
      or txt('Icon / presence; separate gameplay ID ','图标／表现；独立生效 ID ')..role.other end
    return txt('No verified icon/effect pairing','没有已确认的图标／生效配对')
   end)
   info(p,'category',function()return txt('Payload interpretation','载荷含义')end,function()
    local t=TYPES[model:read(id,'effectType')];return(t and txt(t[1],t[2])or txt('Unresolved effect type','尚未确认的效果类型'))..' · effectType '..model:read(id,'effectType')
   end)
   local description=entry.description_zh or entry.description_en or entry.long_description_zh or entry.long_description_en
   if description then info(p,'description',function()return txt('Game description (snapshot)','游戏说明（目录快照）')end,plain(description))end
   if role then
    local r=row(p,'paired_id',function()return role.kind=='effect'and txt('Separate icon ID','对应的独立图标 ID')or txt('Separate gameplay ID','对应的独立生效 ID')end,'Identity')
    r.custom_value=function()return 0 end;r.custom_text=function()return tostring(role.other)..' →'end
    r.custom_action=function()return c.open_page and c.open_page(M.by_id[role.other])end
   end
   PLANETS.effect_rows(c,p,id,row,txt)
   local function flag(key,label,get,set)
    local r=row(p,key,label,'Wire definition');r.storage='flag';r.min,r.max=0,1
    r.custom_value=function(original)return not original and get()and 1 or 0 end
    r.custom_change=function(v)return set(v>=.5)end;r.custom_reset=function()return set(false)end
   end
   flag('network_master',function()return txt('Enable network definitions (all IDs)','启用网络定义覆盖（总开关）')end,function()return model.cfg.enabled end,function(v)return model:master(v)end)
   flag('network_entry',function()return txt('Override this ID','覆盖本词条 ID')end,function()return model:enabled(id)end,function(v)return model:set(id,'enabled',v)end)
   for _,key in ipairs(G.fields)do
    local key=key;local label=txt(FIELD_TEXT[key][1],FIELD_TEXT[key][2])
    local r=row(p,key,function()return label end,'Wire definition')
    local function text()return J.encode(model:read(id,key))end
    r.input_text,r.custom_text=text,text
    r.custom_value=function(original)return not original and J.encode(model:read(id,key))~=J.encode(base[key])and 1 or 0 end
    r.custom_edit=function(input)
     local ok,value=pcall(J.decode,input)
     if not ok then value=tonumber(input)end -- also accept hex for scalar hashes
     if not G.valid(key,value)then return nil,txt('Enter a finite JSON number / numeric array; metadata fields require uint32.',
      '请输入有限 JSON 数值／数值数组；元数据字段为 uint32。')end
     return model:set(id,key,value)
    end
    r.custom_reset=function()return model:reset(id,key)end
    r.tip_of=function()return{key,txt('Meaning depends on the effect category. See the field documentation.',FIELD_HELP[key]),'ID '..id..' · '..G.data.source,
     txt('Original: ','原定义：')..J.encode(base[key]),
     txt('Edits are saved in Data/galactic_effect_overrides.json, not written into dl_bin. Both switches and the network proxy are required.',
      '保存至 Data/galactic_effect_overrides.json；不写入 dl_bin。总开关、本词条开关与网络代理均须启用。'),
     plain(entry.reference_note)~=''and(txt('Historical reference (amounts may be stale): ','历史参考（数值可能过期）：')..plain(entry.reference_note))or''}end
   end
   local pathrow=info(p,'plan',function()return txt('Portable definition file','便携式定义文件')end,'Data/galactic_effect_overrides.json','Wire definition')
   pathrow.tip_of=function()return{model.path}end
   if model.error or model.stale[tostring(id)]then info(p,'stale',function()return txt('Definition error','定义错误')end,
    model.error or txt('Snapshot changed. Reset this ID before editing; the proxy ignores stale definitions.',
     '目录定义已变更；先重置本 ID。代理会跳过过期定义。'),'Wire definition')end
   local ordinals={};for _,target in ipairs(targets)do ordinals[target.source_ordinal or target.modifier_id]=true end
   local count=0;for _ in pairs(ordinals)do count=count+1 end
   if count==1 then
    for n,target in ipairs(targets)do
     action(p,'local_'..n,function()return txt('Local: ','本地：')..target.name end,target)
     p.search=p.search..' '..target.name
    end
   else
    info(p,'no_local',function()return txt('Local mapping','本地关联')end,
     count>1 and txt('Ambiguous short hash; no local target opened.','短哈希存在歧义，不自动关联。')or
     txt('No verified local definition; edit the network payload above.','没有已核实的本地定义；实际载荷请在上方网络定义编辑。'),'Linked local definitions')
   end
   if current_type==40 then
    local value=model:read(id,'values')[1]
    local tags={[2922304745]='GM_BotAssault',[2313485354]='GM_BugSuperPredators'}
    info(p,'enemy_tag',function()return txt('EnemyTag reference','EnemyTag 引用')end,
     tags[value]or(type(value)=='number'and value%1==0 and value>=0 and value<=4294967295 and string.format('0x%08X',value)
      or value~=nil and J.encode(value)or txt('Missing value','载荷为空')),'Linked local definitions')
   end
  end
 end
 PLANETS.build(c,page,txt,M,M.assignment_model)
 return model
end
return M
