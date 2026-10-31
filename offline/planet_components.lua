-- Current, typed local planet configuration. RawData names and legacy hints have separate provenance.
local D=require('demolition')
local V=require('component_view')
local DATA=require('planet_data')
local PC=require('preload_components')
local MODS=require('modifier_components')
local MODDATA=require('modifier_data')
local ASSIGN=require('modifier_assignments')
local EFFECTS=require('galactic_effect_view')
local M={data=DATA,pages={},ROOTS={},ENTITY_TYPES={},FILES={},labels={
 PlanetData={'Planet generation','星球生成','星球生成'},PlanetTypes={'Planet types','星球类型','星球類型'},
 PlanetEnvironment={'Environment','环境设置','環境設定'},PlanetWeather={'Weather','天气设置','天氣設定'},
 PlanetSpace={'Solar / galactic','星系表现','星系表現'},PlanetRegions={'Regions / territory','区域领土','區域領土'},
 PlanetComponents={'Environment ECS','环境组件','環境組件'},
 PlanetEffectIds={'Effect ID definitions','词条 ID 定义','詞條 ID 定義'},
 PlanetEffectAssignments={'Planet effects','星球词条分配','星球詞條分配'},
 PlanetModifiers=MODS.labels.PlanetModifiers,OperationModifiers=MODS.labels.OperationModifiers,
 PlanetModifierLists=ASSIGN.labels.PlanetModifierLists,GalacticModifierLists=ASSIGN.labels.GalacticModifierLists}}
local ROOT_ZH={LevelGenerationPlanetData='星球生成',SolarSystemObjectTypes='星球类型',EnvironmentSettings='环境',WeatherSettings='天气',
 WeatherColorSets='天气配色',SolarSystemSettings='星系',PlanetRegionSettings='星球区域',GenerationRegionSettings='区域配置',
 GenerationRegionGroup='区域组',PlanetOverrideSettings='星球覆盖',PlanetColorSets='星球配色',SavedPlanetTerritoryGraph='领土图',
 GalacticPresenceSettings='银河表现',WeatherControlComponent='天气控制组件',EnvironmentalHazardComponent='环境危害组件',
 EnvironmentalEffectTagComponent='环境效果标签组件',WeatheringComponent='风化组件'}
local ZH={planet_type='星球类型',planet_name_loc='星球名称文本 ID',planet_description_loc='星球描述文本 ID',
 planet_description_short_loc='星球短描述文本 ID',planet_system_name_loc='星系名称文本 ID',planet_layout_id='星球布局 ID',
 weather_type='天气类型',effect_type='环境效果类型',status_effect_to_apply='施加的状态效果',weather_name='天气名称哈希',
 previous_weather_out_time='上一天气退出时间',target_weather_in_time='目标天气进入时间',target_weather_active_hold_time='目标天气维持时间',
 target_weather_out_time='目标天气退出时间',weather_catch_up_time='天气追赶时间',gameplay_effect_activation_point='游戏效果激活比例',
 remove_entity_on_completion='完成时移除实体',start_active='初始激活',on_activate_script_event='激活脚本事件哈希',
 on_deactivate_script_event='停用脚本事件哈希',min_refire_time='最短再次触发时间',max_refire_time='最长再次触发时间',
 ability_id='能力 ID',detonatable='可引爆',trigger_reset_time='触发重置时间',id='ID',name='名称',type='类型',
 fog_density='雾密度',fog_color='雾颜色',cloud_opacity='云不透明度',cloud_coverage='云覆盖率',cloud_altitude='云高度',
 cloud_color='云颜色',cloud_speed='云移动速度',wind_speed_min='最小风速',wind_speed_max='最大风速',weather_color_set='天气配色组',
 package='资源包',env_shared_package='环境共享资源包',mission_planet_unit_package='任务星球模型包',
 mission_planet_hologram_unit_package='任务星球全息包',resource_packages='额外资源包',position='位置',rotation='旋转',scale='缩放',
 cell_count='领土单元数量',edge_count='领土边数量',distance='距离',radius='半径',weight='权重',probability='概率'}
local function pick(lang,en,zh)return(lang=='zh-Hans'or lang=='zh-Hant')and(zh or en)or en end
local ROOT_ZH_T={LevelGenerationPlanetData='星球生成',SolarSystemObjectTypes='星球類型',EnvironmentSettings='環境',WeatherSettings='天氣',
 WeatherColorSets='天氣配色',SolarSystemSettings='星系',PlanetRegionSettings='星球區域',GenerationRegionSettings='區域配置',
 GenerationRegionGroup='區域組',PlanetOverrideSettings='星球覆蓋',PlanetColorSets='星球配色',SavedPlanetTerritoryGraph='領土圖',
 GalacticPresenceSettings='銀河表現',WeatherControlComponent='天氣控制組件',EnvironmentalHazardComponent='環境危害組件',
 EnvironmentalEffectTagComponent='環境效果標籤組件',WeatheringComponent='風化組件'}
local KIND={[0]={'int8','整数','整數'},[2]={'int32','有符号整数','有號整數'},[4]={'byte','字节','位元組'},[5]={'uint16','整数','整數'},
 [6]={'uint32','整数','整數'},[7]={'uint64','64位值','64位值'},[8]={'float','浮点数','浮點數'},[10]={'int8','整数','整數'},[12]={'enum','枚举','列舉'},
 [14]={'enum','枚举','列舉'},[15]={'enum','枚举','列舉'},[16]={'enum','枚举','列舉'},[17]={'enum','枚举','列舉'},[18]={'string','字符串','字串'},
 [19]={'pointer','指针','指標'},[20]={'struct','结构','結構'}}
function M.kind_name(m)if m.atom==3 then return'bit'end;return(KIND[m.storage]or{'value'})[1]end
function M.kind_zh(m,k)if m.atom==3 then return k==1 and'位'or'位'end;return(KIND[m.storage]or{'','值','值'})[k+1]end
-- where a member's name came from (DATA.schemas[..].members[..].source, from tools/planet_gen/gen.py)
local HOW={
 rawdata={'Name and values checked against RawData.','名称与数值已与 RawData 核对。','名稱與數值已與 RawData 核對。'},
 value={'Name matched by value to the 2025 settings of shalzuth/HelldiversData (%d%% of records agree).',
  '名称按数值与 shalzuth/HelldiversData 的 2025 年设置逐条比对得出（%d%% 的记录一致）。','名稱按數值與 shalzuth/HelldiversData 的 2025 年設定逐條比對得出（%d%% 的記錄一致）。'},
 ['value-constant']={'Every record holds the same value as the 2025 field of this name, in the same place among its neighbours (%d%% agree).',
  '各记录的值与 2025 年同名字段相同，且位置与前后字段一致（%d%% 一致）。','各記錄的值與 2025 年同名字段相同，且位置與前後字段一致（%d%% 一致）。'},
 order={'Name inferred from member order and kind of value (no values to compare); check before relying on it.',
  '名称按成员顺序与数值类型推断（无数值可比对），使用前请核对。','名稱按成員順序與數值類型推斷（無數值可比對），使用前請核對。'},
 legacy={'Name from an older member-order pairing; the 2025 data cannot confirm it: check before relying on it.',
  '名称沿用旧版成员顺序推断，2025 年数据无法核对，使用前请核对。','名稱沿用舊版成員順序推斷，2025 年資料無法核對，使用前請核對。'},
 none={'Name unknown: position and type are from the installed type library.','名称未知：位置与类型来自已安装游戏的类型库。','名稱未知：位置與類型來自已安裝遊戲的類型庫。'}}
function M.provenance(how,agree,lang)
 local t=HOW[how]or HOW.none;local s=lang=='zh-Hans'and t[2]or lang=='zh-Hant'and t[3]or t[1]
 if s:find('%%d')then s=string.format(s,math.floor((agree or 1)*100+.5))end;return s
end
-- the members along a group key ('o176.o44.', 'o48[0].o32[1].', 'o8->.'): {m=member, index=n or nil} from the root down
function M.path_members(root,key)
 local out,tid={},root
 for seg in key:gmatch('([^%.]+)%.')do
  local off=tonumber(seg:match('^o(%d+)'));local idx=seg:match('%[(%d+)%]');idx=idx and tonumber(idx)
  local t=DATA.schemas[tid];local hit
  for _,m in ipairs(t and t.members or{})do if m.offset==off and(m.storage==19 or m.storage==20)then hit=m;break end end
  if not hit then break end
  out[#out+1]={m=hit,index=idx};tid=hit.type
 end
 return out
end
local function u32(b,o)
 if o<0 or o+4>#b then return end;local a,c,d,e=b:byte(o+1,o+4);return a+c*256+d*65536+e*16777216
end
local WIDTH={[0]=1,[1]=2,[2]=4,[3]=8,[4]=1,[5]=2,[6]=4,[7]=8,[8]=4,[9]=8,
 [10]=1,[11]=2,[12]=4,[13]=8,[14]=1,[15]=2,[16]=4,[17]=8,[18]=8,[19]=8}
local STORAGE={[0]='i8',[2]='i32',[4]='u8',[5]='u16',[6]='u32',[7]='u64',[8]='f32',[10]='i8',[12]='i32',[14]='u8',[15]='u16',[16]='u32',[17]='u64'}
local function pointer(b,o,address)
 local lo,hi=u32(b,o),u32(b,o+4);if not hi then return end
 local v=lo+hi*4294967296;if v>=#b and address then v=v-address end
 if v<0 or v>=#b then return end;return v
end
function M.string_at(b,o,address)
 local at=pointer(b,o,address);if not at or at==0 then return end
 local s=b:sub(at+1,at+513):match('^([^%z]*)%z')
 return s and not s:find('[%c]')and s or nil
end
function M.check_layout(root,schemas,seen)
 seen=seen or{};if seen[root]then return true end;seen[root]=true
 local a,b=DATA.schemas[root],schemas and schemas[root]
 if not a or not b or a.size~=b.size or #a.members~=#b.members then return false end
 local got={};for _,m in ipairs(b.members)do got[#got+1]=m end
 table.sort(got,function(x,y)if x.offset~=y.offset then return x.offset<y.offset end;return x.count<y.count end)
 for i,m in ipairs(a.members)do
  for _,k in ipairs({'offset','size','type','atom','storage','count'})do if m[k]~=got[i][k]then return false end end
  if(m.storage==19 or m.storage==20)and DATA.schemas[m.type]and not M.check_layout(m.type,schemas,seen)then return false end
 end;return true
end
function M.identity(b,root,address)
 local t=DATA.schemas[root]
 for _,m in ipairs(t.members)do if m.storage==18 and m.atom==0 and(m.alias=='debug_name'or m.alias=='name')then
  local s=M.string_at(b,m.offset,address);if s and s~=''then return s:match('([^/]+)$')or s end
 end end
 for _,m in ipairs(t.members)do if m.storage==18 and m.atom==0 then
  local s=M.string_at(b,m.offset,address);if s and s~=''then return s:match('([^/]+)$')or s end
 end end
 for _,m in ipairs(t.members)do if m.atom==0 and(m.alias=='id'or m.alias=='name')then
  if m.size==8 then return D.hex(b:sub(m.offset+1,m.offset+8))end
  return tostring(u32(b,m.offset)or'')
 end end
 return''
end
-- Plan bounded pages without allocating every field. Large arrays are divided into stable index groups.
-- callback receives either a scalar, a string or an array descriptor; it never receives a writable pointer.
function M.plan(b,root,address)
 local groups={{key='root',units={{tid=root,pos=0,path=''}},fields=0,arrays=0}};local excluded={};local seen={};local leaves=0;local render_seen
 local visit
 local function emit(group,m,pos,path)
  leaves=leaves+1;group.fields=group.fields+1
 end
 visit=function(group,tid,pos,path,depth,discover,callback)
  assert(depth<32,'planet structure nesting is excessive')
  local t=assert(DATA.schemas[tid],'unknown nested planet type');assert(pos>=0 and pos+t.size<=#b,'planet record outside block')
  local key=tid..':'..pos
  if discover then if seen[key]then return end;seen[key]=true end
  if not discover then if render_seen[key]then return end;render_seen[key]=true end
  for _,m in ipairs(t.members)do
   local off=pos+m.offset;local field=path..'o'..m.offset..(m.atom==3 and('b'..m.count)or'')
   local label=m.alias or string.format('unnamed_0x%X',m.offset)
   local n=m.atom==2 and m.count or 1;local at=off;local step=m.atom==2 and math.floor(m.size/math.max(1,n))or m.size
   if m.atom==1 then
    n=assert(u32(b,off+8));assert(n<=100000 and u32(b,off+12)==0,'invalid planet array header')
    step=m.storage==20 and DATA.schemas[m.type]and DATA.schemas[m.type].size or WIDTH[m.storage]
    if callback then callback({kind='array',m=m,offset=off,path=field,count=n,group=path,alias=label})end
    if discover then group.arrays=group.arrays+1 end
    if n>0 then at=pointer(b,off,address);assert(at and step and at+n*step<=#b,'planet array outside block')end
   end
   if m.storage==19 and m.atom==0 then
    local p=pointer(b,off,address)
    if p and p>0 then visit(group,m.type,p,field..'->.',depth+1,discover,callback)end
   elseif m.storage==18 and m.atom==0 then
    if callback then callback({kind='string',m=m,offset=off,path=field,group=path,alias=label})end
   elseif n>0 then
    local threshold=m.storage==20 and 16 or 128
    local split=(m.atom==1 or m.atom==2)and n>threshold
    if split and discover then
     excluded[off]=true
     for start=0,n-1,threshold do
      local g={key=field..'['..start..']',name=label..' ['..start..'-'..math.min(n-1,start+threshold-1)..']',units={},fields=0,arrays=0}
      groups[#groups+1]=g;assert(#groups<=100000,'too many planet array pages')
      for j=start,math.min(n-1,start+threshold-1)do
       local p=field..'['..j..']'
       if m.storage==20 then g.units[#g.units+1]={tid=m.type,pos=at+j*step,path=p..'.'};visit(g,m.type,at+j*step,p..'.',depth+1,true)
       else g.units[#g.units+1]={member=m,pos=at+j*step,path=p,alias=label..'['..j..']'};emit(g,m,at+j*step,p)end
      end
     end
    elseif not split or not excluded[off]then
     for j=0,n-1 do
      local p=field..((m.atom==1 or m.atom==2)and('['..j..']')or'')
      if m.storage==20 then visit(group,m.type,at+j*step,p..'.',depth+1,discover,callback)
      elseif STORAGE[m.storage]or m.atom==3 then
       if discover then emit(group,m,at+j*step,p)end
       if callback then callback({kind='scalar',m=m,offset=at+j*step,path=p,group=path,alias=label..((m.atom==1 or m.atom==2)and('['..j..']')or'')})end
      else error('unsupported planet scalar storage '..m.storage)end
     end
    end
   end
  end
 end
 visit(groups[1],root,0,'',0,true)
 for _,g in ipairs(groups)do
  g.each=function(callback)
   render_seen={}
   for _,unit in ipairs(g.units)do
    if unit.member then callback({kind='scalar',m=unit.member,offset=unit.pos,path=unit.path,group=unit.path,alias=unit.alias})
    else visit(g,unit.tid,unit.pos,unit.path,0,false,callback)end
   end
  end
 end
 return{groups=groups,fields=leaves}
end
function M.register(kinds)
 MODS.register(kinds,PC)
 for _,r in ipairs(DATA.roots)do
  M.ROOTS[r.hash]=r;M.FILES[r.file]=true
  if not kinds[r.hash]then kinds[r.hash]={name='planet '..r.name,stride=1,groups=true,list={},
   group_key=function(b,address)return'planet '..r.hash..' '..tostring(PC.location(address))end,
   parse=function(b)if #b<DATA.schemas[r.hash].size then return nil,'planet header truncated'end;return{},0 end}end
 end
 for _,s in ipairs(DATA.components)do
  M.ENTITY_TYPES[s.hash]=true
  kinds[s.hash]=kinds[s.hash]or{name='planet '..s.name,stride=s.size,keyed=true}
 end
end
function M.clear(kinds)
 MODS.clear(kinds)
 for _,r in ipairs(DATA.roots)do if kinds[r.hash]and kinds[r.hash].name=='planet '..r.name then kinds[r.hash].list={}end end
end
function M.build(c)
 for _,list in pairs(M.pages)do for _,p in ipairs(list)do if c.by_hash[p.hash]==p then c.by_hash[p.hash]=nil end end end
 M.pages={PlanetData={},PlanetTypes={},PlanetEnvironment={},PlanetWeather={},PlanetSpace={},PlanetRegions={},PlanetComponents={},
  PlanetEffectAssignments={},PlanetEffectIds={},PlanetModifiers={},OperationModifiers={},PlanetModifierLists={},GalacticModifierLists={}}
 local function tx(en,zh)return pick(c.lang(),en,zh)end
 local owners={};for _,p in pairs(c.by_hash)do for _,r in ipairs(p.rows or{})do for _,part in ipairs(r.parts or{})do if not owners[part.field.key]then owners[part.field.key]={weapon=p,part=part}end end end end
 local function page(slot,name,key)
  local hash=D.hex(D.hash_resource('shodan/planet/'..key));assert(not c.by_hash[hash],'planet page identity collision')
  local p={name=name,slot=slot,hash=hash,rows={},by_id={},field_keys={},planet_parameters=true,search=name..' '..key}
  c.by_hash[hash]=p;M.pages[slot][#M.pages[slot]+1]=p;return p
 end
 local function zh()local l=c.lang();return l=='zh-Hans'or l=='zh-Hant'end
 local function txt(en,zhs,zht)local l=c.lang();return l=='zh-Hans'and(zhs or en)or l=='zh-Hant'and(zht or zhs or en)or en end
 -- a member's name in the page's language
 local function name_of(m)
  if not m.alias then
   return txt(string.format('Unknown %s +0x%X',M.kind_name(m),m.offset),string.format('未知%s +0x%X',M.kind_zh(m,1),m.offset),string.format('未知%s +0x%X',M.kind_zh(m,2),m.offset))
  end
  local z=(DATA.zh or{})[m.alias];return txt(m.alias,z and z[1],z and z[2])
 end
 local function info(p,id,label,value,section,section_of,component,component_of)
  local r={id=id,label=label,storage='u32',parts={},empty=true,readonly_text=value,section=section or'',section_of=section_of,
   component=component,component_of=component_of}
  r.label_of=function()return type(label)=='function'and label()or label end
  r.tip_of=function()return{type(label)=='function'and label()or label,type(value)=='function'and value()or tostring(value)}end;p.rows[#p.rows+1]=r;return r
 end
 local function fill(p,plan,group,kind,b,address,metadata)
  local root=metadata.root
  local component=metadata.type_name
  local component_of=function()return txt(metadata.type_name,(ROOT_ZH[metadata.type_name]or metadata.type_name)..'（'..metadata.type_name..'）',
   (ROOT_ZH_T[metadata.type_name]or ROOT_ZH[metadata.type_name]or metadata.type_name)..'（'..metadata.type_name..'）')end
  local sections={}
  local function section_of(key)
   if not sections[key]then
    local chain=M.path_members(root,key)
    sections[key]=function()
     if #chain==0 then return txt('General','基本参数','基本參數')end
     local out={};for _,seg in ipairs(chain)do out[#out+1]=name_of(seg.m)..(seg.index and(' #'..(seg.index+1))or'')end
     return table.concat(out,' · ')
    end
   end;return sections[key]
  end
  local function emit(entry)
   local m,off=entry.m,entry.offset
   local index=entry.path:match('%[(%d+)%]$');index=index and tonumber(index)
   local label=function()return name_of(m)..(index and(' #'..(index+1))or'')end
   local section=entry.group
   -- One authoring source for variable-length effect lists; the generic view points to it.
   local attached=root==ASSIGN.PLANET and m.offset==424 or root==ASSIGN.GALACTIC and(m.offset==504 or m.offset==704)
   if rawget(_G,'SHODAN_PRELOAD_MODEL')and attached and m.atom==1 and entry.group==''then
    if entry.kind=='array'then
     info(p,'attachment_list_'..entry.path,function()return name_of(m)end,
      txt('Edit under Local environment entities (add, replace, delete); not the eight effect-ID slots.','在“本地环境实体”中增删、替换；此处不是八槽效果 ID。','在「本機環境實體」中增刪、替換；此處不是八槽效果 ID。'),
      section,section_of(section),component,component_of)
    end
    return
   end
   if entry.kind=='array'then
    info(p,'array_count_'..entry.path,function()return name_of(m)..txt(' · items',' · 项数',' · 項數')end,tostring(entry.count),
     section,section_of(section),component,component_of);return
   elseif entry.kind=='string'then
    local value=M.string_at(b,off,address)or''
    info(p,'string_'..entry.path,label,value,section,section_of(section),component,component_of);return
   end
   local id='planet_'..entry.path
   local storage=STORAGE[m.storage];local bitwidth,shift
   if m.atom==3 then bitwidth=m.count%256;shift=math.floor(m.count/256);storage='bits'..m.size..'_'..shift..'_'..bitwidth end
   local enum=DATA.enums[m.type]
   local row
   if storage=='u64' then
    local lo,hi=c.field_at(kind,off,'u32',4294967295),c.field_at(kind,off+4,'u32',4294967295)
    row=c.add_row(p,section,id,m.alias or id,'u64',{{id=id..'_lo',field=lo,health_owner=owners[lo.key]},
     {id=id..'_hi',field=hi,health_owner=owners[hi.key]}},0,4294967295,1,1);row.hash64,row.lead=true,true
    p.field_keys[lo.key],p.field_keys[hi.key]=true,true
   else
    local limit=storage=='f32'and 3.402823466e38 or storage=='i32'and 2147483648 or storage=='i8'and 128 or 4294967295
    local f=c.field_at(kind,off,storage,limit);f.limit=math.max(f.limit or 0,limit)
    if storage=='f32'or storage=='i32'or storage=='i8' then f.signed=true end
    local value=c.read(f)
    if value==nil then info(p,id,label,txt('Non-finite or unavailable value','非有限或不可读取值','非有限或不可讀取值'),section,section_of(section),component,component_of);return end
    local min,max=storage=='f32'and-3.402823466e38 or storage=='i32'and-2147483648 or storage=='i8'and-128 or 0,
     storage=='f32'and 3.402823466e38 or storage=='i32'and 2147483647 or storage=='i8'and 127 or storage=='u8'and 255 or storage=='u16'and 65535 or bitwidth and 2^bitwidth-1 or 4294967295
    row=c.add_row(p,section,id,m.alias or id,bitwidth==1 and'flag'or storage,{{id=id,field=f,health_owner=owners[f.key]}},min,max,storage=='f32'and .05 or 1,storage=='f32'and 1 or 10)
    p.field_keys[f.key]=true
   end
   row.component,row.component_of=component,component_of
   row.section_of=section_of(section)
   row.label_of=function()
    local name=label()
    if row.hash64 then
     local h=string.format('%08X%08X',c.read(row.parts[2].field)or 0,c.read(row.parts[1].field)or 0)
     local e=MODDATA.ENTITIES[h]
     if e then name=name..(zh()and'：'or': ')..txt(e[1],e[2],e[2])end
    end
    if enum and not row.hash64 then
     local value=c.read(row.parts[1].field);local e=enum.labels[tostring(value)]
     if e then name=name..(zh()and'：'or': ')..(e.label:gsub('^%u%w-_',''))..(e.source=='2025 values'and''or' (?)')end
    end;return name
   end
   row.tip_of=function()
    local lines={(m.alias or string.format('+0x%X',m.offset))..(index and('['..index..']')or''),
     (metadata.file or metadata.type_name)..string.format(' · payload +0x%X · %s',off,storage)}
    local how=metadata.rawdata and'rawdata'or m.source or(m.alias and'legacy'or'none')
    lines[#lines+1]=M.provenance(how,m.agree,c.lang())
    if m.description then lines[#lines+1]=m.description end
    if enum then lines[#lines+1]=enum.name..' · '..#enum.values..txt(' declared values',' 个声明值',' 個宣告值')
     for i=1,math.min(18,#enum.values)do local v=enum.values[i];local e=enum.labels[v];lines[#lines+1]=v..(e and(' = '..e.label..(e.source=='2025 values'and''or' (?)'))or'')end
    end
    if row.hash64 then
     local h=string.format('%08X%08X',c.read(row.parts[2].field)or 0,c.read(row.parts[1].field)or 0)
     local pkg=PC.data.catalog[h];if pkg then lines[#lines+1]=pkg.path~=''and pkg.path or h end
    end
    return lines
   end
  end
  local first=#p.rows+1
  group.each(emit)
  -- a group's rows together (nested groups come between a type's own members in memory)
  local order,rank={},{}
  for i=first,#p.rows do local k=p.rows[i].section or'';if not rank[k]then order[#order+1]=k;rank[k]=#order end end
  local moved={};for i=first,#p.rows do moved[#moved+1]={rank[p.rows[i].section or''],i,p.rows[i]}end
  table.sort(moved,function(x,y)if x[1]~=y[1]then return x[1]<y[1]end;return x[2]<y[2]end)
  for k,e in ipairs(moved)do p.rows[first+k-1]=e[3]end
 end
 local function build_record(slot,type_name,root,kind,b,address,identity,record_pos,metadata)
  require('startup_work').checkpoint()
  local ok,plan=pcall(M.plan,b,root,address)
  if not ok then if c.log then c.log('planet: '..type_name..' rejected: '..tostring(plan))end;return end
  for _,group in ipairs(plan.groups)do
   local key=metadata.key..'/'..group.key
   local name=type_name..' · '..identity..(group.name and(' · '..group.name)or'')
   local p=page(slot,name,key);p.planet_root=root;p.source_file=metadata.file;p.source_ordinal=metadata.ordinal
   local planet=metadata.planet
   if planet then p.search=p.search..' '..planet.en..' '..planet.zhs..' '..planet.zht..' '..planet.sector end
   p.note_of=function()return txt('Local planet configuration: the galaxy map\'s owner, health, regeneration, position and effects come from the server and are not edited here.',
    '本地星球配置：银河地图上的归属、生命值、恢复速度、坐标与效果由服务器下发，不在此修改。',
    '本地星球配置：銀河地圖上的歸屬、生命值、恢復速度、座標與效果由伺服器下發，不在此修改。')end
   p.ensure_rows=function()
    if p.rows_built then return end;p.rows_built=true
    local band=function()return txt(type_name,(ROOT_ZH[type_name]or type_name)..'（'..type_name..'）',(ROOT_ZH_T[type_name]or ROOT_ZH[type_name]or type_name)..'（'..type_name..'）')end
    local head=function()return txt('Source','来源','來源')end
    if planet then
     info(p,'planet',function()return txt('Planet','星球','星球')end,function()
      return txt(planet.en,planet.zhs,planet.zht)..' · '..txt('galaxy index ','银河编号 ','銀河編號 ')..planet.index..' · '..planet.sector end,'source',head,type_name,band)
    end
    info(p,'source',function()return txt('File','文件','檔案')end,metadata.file or'generated_entities.dl_bin','source',head,type_name,band)
    info(p,'layout',function()return txt('Type','类型','類型')end,type_name..string.format(' · 0x%08X · %d bytes',root,DATA.schemas[root].size),'source',head,type_name,band)
    fill(p,plan,group,kind,b,address,{type_name=type_name,file=metadata.file,rawdata=metadata.rawdata,root=root})
   end
  end
 end
 for _,r in ipairs(DATA.roots)do if M.check_layout(r.hash,c.schemas)then
  for _,kind in ipairs(c.kinds[r.hash].list or{})do
   local t=c.tables[kind];local b=c.bytes(kind);local location=PC.location(t.copies[1]);local ordinal=location and location:match(':(%d+)$')or'1'
   local identity=M.identity(b,r.hash,t.copies[1]+24)
   local planet=r.name=='LevelGenerationPlanetData'and(DATA.planets or{})[identity]or nil
   build_record(r.slot,r.name,r.hash,kind,b,t.copies[1]+24,(identity~=''and identity or'#'..ordinal)..' [#'..ordinal..']',0,
    {key=r.file..'/'..r.hash..'/'..ordinal,file=r.file,ordinal=tonumber(ordinal),planet=planet})
  end
 elseif c.log then c.log('planet: layout mismatch '..r.name)end end
 for _,s in ipairs(DATA.components)do if M.check_layout(s.record_hash,c.schemas)then
  local t=c.tables[s.hash]
  if t then
   local b=c.bytes(s.hash);local keys={};for key in pairs(t.index)do keys[#keys+1]=key end;table.sort(keys,function(a,b)return D.hex(a)<D.hex(b)end)
   for _,key in ipairs(keys)do
    local pos=t.index[key];local entity=D.hex(key);local name=(DATA.rawdata.weather_names[entity]or{}).en or(c.names or{})[entity]or entity
    -- Component payload offsets stay rooted at their keyed table; the generic walker uses a synthetic prefix.
    local record=b:sub(pos+1,pos+s.size)
    local ok,plan=pcall(M.plan,record,s.record_hash,0)
    if ok then
     local p=page('PlanetComponents',s.name..' · '..name,'component/'..s.hash..'/'..entity);p.entity_hash=entity;p.planet_root=s.record_hash
     p.note_of=function()return s.name..' · '..entity..(s.name=='WeatherControlComponent'and txt(' · RawData: 9 records / 99 values verified',' · 已与 RawData 核对：9 条记录、99 个值',' · 已與 RawData 核對：9 條記錄、99 個值')or txt(' · local entity component',' · 本地实体组件',' · 本地實體組件'))end
     p.ensure_rows=function()
      if p.rows_built then return end;p.rows_built=true
      local group=plan.groups[1];local adapted={each=function(fn)group.each(function(e)e.offset=e.offset+pos;fn(e)end)end}
      fill(p,plan,adapted,s.hash,b,t.copies[1]+24,{type_name=s.name,file='generated_entities.dl_bin',rawdata=s.name=='WeatherControlComponent',root=s.record_hash})
     end
    elseif c.log then c.log('planet: component parse rejected '..s.name..': '..tostring(plan))end
   end
  end
 end end
 -- the modifiers (offline/modifier_components.lua); the mission components' names for the fields they change
 local mission_fields={}
 local okm,mission=pcall(require,'mission_components')
 for _,spec in ipairs(okm and mission.SPECS or{})do
  local t={};mission_fields[spec.TYPE]=t
  for _,f in ipairs(spec.FIELDS)do if not f[3]:match('^bit')then t[f[2]]={f[5],f[6],f[7],f[1]}end end
 end
 local ok,why=pcall(MODS.build,c,page,txt,PC,mission_fields)
 if not ok and c.log then c.log('planet: modifiers rejected: '..tostring(why))end
 local oka,whya=pcall(ASSIGN.build,c,page,txt,PC)
 if not oka and c.log then c.log('planet: modifier attachments rejected: '..tostring(whya))end
 local oke,whye=pcall(EFFECTS.build,c,page,txt,M.pages)
 if not oke and c.log then c.log('planet: galactic effects rejected: '..tostring(whye))end
 for _,list in pairs(M.pages)do table.sort(list,function(a,b)return a.name:lower()<b.name:lower()end)end
 return M.pages
end
function M.translate_name(v,lang)
 local target=require('planet_effect_view').translate_name(v,lang);if target then return target end
 local effect=EFFECTS.translate_name(v,lang);if effect then return effect end
 local assignment=ASSIGN.translate_name(v,lang);if assignment then return assignment end
 local t=MODS.titles[v];if t then return lang=='zh-Hans'and t[1]or lang=='zh-Hant'and t[2]or nil end
 local root,name=v:match('^(%w+) · (.*)$');if not(root and ROOT_ZH[root])then return end
 local zt=lang=='zh-Hant'and(ROOT_ZH_T[root]or ROOT_ZH[root])or ROOT_ZH[root]
 if root=='LevelGenerationPlanetData'then
  local debug=name:match('^(%S+)');local planet=debug and(DATA.planets or{})[debug]
  if planet then
   local shown=lang=='zh-Hans'and planet.zhs or lang=='zh-Hant'and planet.zht or planet.en
   return shown..'（'..name..'）'
  end
 end
 return pick(lang,root,zt)..' · '..name
end
function M.list(tab,query,tr)
 local list=M.pages[tab];if not list then return end
 if not query or query==''then return list end
 local out={};for _,p in ipairs(list)do
  local hay=(p.search..' '..(p.search_extra and p.search_extra()or'')..' '..(tr and tr(p.name)or'')..' '..(p.entity_hash or'')):lower();local found=true
  for word in query:lower():gmatch('%S+')do if not hay:find(word,1,true)then found=false;break end end
  if found then out[#out+1]=p end
 end;return out
end
function M.network_status_revision()return require('planet_effect_view').status_revision()end
return M
