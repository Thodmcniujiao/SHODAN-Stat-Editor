-- Modifiers by dimension (built with the planet pages; offline/planet_components.lua registers and lists them):
--   PlanetModifiers    generated_modifier_settings.dl_bin, type Modifier (24 bytes): +0 id (u32), +4 byte, +8 groups
--                      (ModifierGroup, 32 bytes: the entities (u64 array) and the entity deltas applied to them (u64 array)).
--                      The server switches them on by id (galactic / planet effects: barrage upgrades, resupply...).
--   OperationModifiers the entity deltas (generated_entity_deltas.dl_bin) that change the mission game mode's
--                      GameModeComponent (reinforcements, extraction, map size) or HiveMindComponent (time limit,
--                      patrols, encounters, difficulty): what an operation modifier switches on.
-- Every value a delta sets is editable (it is written into the delta storage, as the attachment pages do).
local D=require('demolition')
local DATA=require('modifier_data')
local M={TYPE=0xDCEA3AEF,GROUP=0x05238A1C,DELTAS=0x683E604F,FILE='generated_modifier_settings.dl_bin',
 OPERATION={GameModeComponentData=true,HiveMindComponentData=true},
 titles={},   -- page name -> {简体, 繁體} (planet_components.translate_name)
 labels={PlanetModifiers={'Modifiers (entity deltas)','星球效果修饰','星球效果修飾'},
  OperationModifiers={'Operation modifiers','行动修饰符','行動修飾符'}}}
local function u32(b,o)if o<0 or o+4>#b then return end;local a,c,d,e=b:byte(o+1,o+4);return a+c*256+d*65536+e*16777216 end
local function u64hex(b,o)return D.hex(b:sub(o+1,o+8))end
local function pick(lang,t)return lang=='zh-Hans'and t[2]or lang=='zh-Hant'and(t[3]or t[2])or t[1]end
-- the record type of a component's keyed table (members: map, array of records)
local function record_type(schemas,hash)
 local t=schemas and schemas[hash];local arr=t and t.members and t.members[2];return arr and arr.type
end
-- the scalar at a byte offset of a type: storage code and size (nil: inside padding)
local function leaf_at(schemas,tid,off,depth)
 local t=schemas and schemas[tid];if not t or(depth or 0)>12 then return end
 for _,m in ipairs(t.members)do
  local n=m.atom==2 and m.count or 1;local step=math.floor(m.size/math.max(1,n))
  if off>=m.offset and off<m.offset+m.size then
   local k=math.floor((off-m.offset)/step);local inner=off-m.offset-k*step
   if m.storage==20 then return leaf_at(schemas,m.type,inner,(depth or 0)+1)end
   if m.atom==3 then return 4,1 end
   return m.storage,step,inner
  end
 end
end
local STORE={[2]='i32',[4]='u8',[6]='u32',[8]='f32',[12]='u32',[14]='u8',[16]='u32'}
function M.register(kinds,PC)
 kinds[M.TYPE]=kinds[M.TYPE]or{name='modifier settings',stride=1,groups=true,list={},
  group_key=function(b,address)return'modifier '..tostring(PC.location(address))end,
  parse=function(b)if #b<24 then return nil,'modifier header truncated'end;return{},0 end}
end
function M.clear(kinds)if kinds[M.TYPE]then kinds[M.TYPE].list={}end end
-- c: the planet build's context; page(slot,name,key) makes a page; info(...) a read-only row
function M.build(c,page,txt,PC,mission_fields)
 local lang=c.lang
 local dt=c.tables[M.DELTAS];local layout=c.kinds[M.DELTAS]and c.kinds[M.DELTAS].layout
 local db=dt and layout and c.bytes(M.DELTAS)
 local function entity_label(hex)
  local n=DATA.ENTITIES[hex];if n then return pick(lang(),{n[1],n[2],n[2]})..' · '..hex end
  local path=(c.names or{})[hex];return(path and(path:match('([^/]+)$')..' · ')or'')..hex
 end
 local function delta_label(hex)
  local n=DATA.DELTAS[hex];return n and(pick(lang(),{n[1],n[2],n[2]})..' · '..hex)or hex
 end
 -- a delta resource's changes: {comp=type name, hash, offset (in the component), size, at (payload offset of the data)}
 local function changes(key)
  if not db then return nil end
  local slot=dt.index[key];if not slot then return nil end
  local count,first=u32(db,layout[1]+slot*8),u32(db,layout[1]+slot*8+4)
  local out={}
  for ci=first or 0,(first or 0)+(count or 0)-1 do
   local index,fd,nd=u32(db,layout[2]+ci*12),u32(db,layout[2]+ci*12+4),u32(db,layout[2]+ci*12+8)
   local comp=DATA.COMPONENTS[index]
   for x=fd or 0,(fd or 0)+(nd or 0)-1 do
    local offset,size,data=u32(db,layout[3]+x*12),u32(db,layout[3]+x*12+4),u32(db,layout[3]+x*12+8)
    out[#out+1]={index=index,comp=comp and comp.name or('component '..tostring(index)),hash=comp and comp.hash,offset=offset,size=size,at=layout[4]+data}
   end
  end
  return out
 end
 -- editable rows for one delta resource's changes
 local function delta_rows(p,key,section,section_of,component,component_of)
  local list=changes(key)
  if not list then
   local r={id='missing_'..D.hex(key),label='missing',storage='u32',parts={},empty=true,section=section,section_of=section_of,component=component,component_of=component_of,
    readonly_text=function()return txt('Not in this game build\'s delta storage','本游戏版本的差异表中没有此项','本遊戲版本的差異表中沒有此項')end}
   r.label_of=function()return delta_label(D.hex(key))end;r.tip_of=function()return{D.hex(key)}end;p.rows[#p.rows+1]=r;return 0
  end
  local n=0
  for _,ch in ipairs(list)do
   local rt=ch.hash and record_type(c.schemas,ch.hash)
   local w=0
   while w<ch.size do
    local off=ch.offset+w
    local st,size=nil,nil
    if rt then local code,sz=leaf_at(c.schemas,rt,off);st,size=STORE[code],sz;if code==7 or code==17 then st,size='u64',8 end end
    if not st then st=ch.size-w>=4 and'u32'or'u8';size=st=='u32'and 4 or 1 end
    if size>ch.size-w then st,size='u8',1 end
    local id='delta_'..D.hex(key)..'_'..ch.index..'_'..off
    local mf=mission_fields[ch.comp]and mission_fields[ch.comp][off]
    local named=DATA.FIELDS[ch.comp]and DATA.FIELDS[ch.comp][off]
    local function field_label()
     if mf then return pick(lang(),{mf[1],mf[2],mf[3]})end
     if named then return pick(lang(),{named[1],named[2],named[3]})end
     return txt(string.format('Unknown +0x%X',off),string.format('未知 +0x%X',off),string.format('未知 +0x%X',off))
    end
    local row
    if st=='u64'then
     local lo,hi=c.field_at(M.DELTAS,ch.at+w,'u32',4294967295),c.field_at(M.DELTAS,ch.at+w+4,'u32',4294967295)
     row=c.add_row(p,section,id,id,'u64',{{id=id..'_lo',field=lo},{id=id..'_hi',field=hi}},0,4294967295,1,1);row.hash64,row.lead=true,true
     p.field_keys[lo.key],p.field_keys[hi.key]=true,true
    else
     local limit=st=='f32'and 3.402823466e38 or st=='i32'and 2147483648 or 4294967295
     local f=c.field_at(M.DELTAS,ch.at+w,st,limit);f.limit=math.max(f.limit or 0,limit)
     if st=='f32'or st=='i32'then f.signed=true end
     local min=st=='f32'and-3.402823466e38 or st=='i32'and-2147483648 or 0
     local max=st=='f32'and 3.402823466e38 or st=='i32'and 2147483647 or st=='u8'and 255 or 4294967295
     row=c.add_row(p,section,id,id,st,{{id=id,field=f}},min,max,st=='f32'and .05 or 1,st=='f32'and 1 or 10)
     p.field_keys[f.key]=true
    end
    row.component,row.component_of,row.section_of=component,component_of,section_of
    row.label_of=function()return ch.comp:gsub('ComponentData$','')..' · '..field_label()end
    row.tip_of=function()
     local lines={(mf and mf[4])or(named and named[1])or string.format('+0x%X',off),
      string.format('%s (component index %d) +0x%X · %s',ch.comp,ch.index,off,st),
      txt('Written into the entity delta storage (generated_entity_deltas.dl_bin).','写入实体差异表（generated_entity_deltas.dl_bin）。','寫入實體差異表（generated_entity_deltas.dl_bin）。')}
     if not mf and not named then lines[#lines+1]=txt('Field name unknown; the type comes from the installed type library.','字段名未知；类型来自已安装游戏的类型库。','欄位名未知；類型來自已安裝遊戲的類型庫。')end
     return lines
    end
    n=n+1;w=w+size
   end
  end
  return n
 end
 local function info(p,id,label,value,section,section_of,component,component_of)
  local r={id=id,label=id,storage='u32',parts={},empty=true,readonly_text=value,section=section,section_of=section_of,component=component,component_of=component_of}
  r.label_of=type(label)=='function'and label or function()return label end
  r.tip_of=function()return{r.label_of(),type(value)=='function'and value()or tostring(value)}end;p.rows[#p.rows+1]=r;return r
 end
 -- 1. the Modifier settings
 local band_m=function()return txt('Modifier','星球效果修饰','星球效果修飾')end
 for _,kind in ipairs((c.kinds[M.TYPE]or{}).list or{})do
  local t=c.tables[kind];local b=t and c.bytes(kind)
  if b and #b>=24 then
   local address=t.copies[1]+24
   local function ptr(o)local lo,hi=u32(b,o),u32(b,o+4);if not hi then return end;local v=lo+hi*4294967296;if v>=#b then v=v-address end;if v<0 or v>=#b then return end;return v end
   local location=PC.location(t.copies[1]);local ordinal=location and location:match(':(%d+)$')or'1'
   local id=u32(b,0)
   local groups,gat=u32(b,16)or 0,ptr(8)
   -- named after its first named delta, else its first entity
   local title
   for g=0,groups-1 do
    local q=gat and gat+g*32
    if q and q+32<=#b then
     local nd,da,ne,ea=u32(b,q+24)or 0,ptr(q+16),u32(b,q+8)or 0,ptr(q)
     for k=0,nd-1 do if not title and da then title=DATA.DELTAS[u64hex(b,da+k*8)]end end
     for k=0,ne-1 do if not title and ea then local e=DATA.ENTITIES[u64hex(b,ea+k*8)];title=e and{e[1]..' (+)',e[2]..'（+）'}end end
    end
   end
   local name=string.format('Modifier · %s%08X',title and(title[1]..' · ')or'',id)
   if title then M.titles[name]={string.format('星球效果修饰 · %s · %08X',title[2],id),string.format('星球效果修飾 · %s · %08X',title[2],id)}end
   local p=page('PlanetModifiers',name,'modifier/'..ordinal..'/'..id)
   p.note_of=function()return txt('Definition selected by runtime ID; applies deltas to the entities listed. This is not a per-planet attachment list.',
    '运行时按编号选用的定义：把差异套用到所列实体；此处不是每颗星球的携带列表。','執行時按編號選用的定義：把差異套用到所列實體；此處不是每顆星球的攜帶列表。')end
   p.ensure_rows=function()
    if p.rows_built then return end;p.rows_built=true
    local head=function()return txt('Modifier','修饰','修飾')end
    info(p,'id',function()return'ID'end,string.format('%08X (%d)',id,id),'head',head,'Modifier',band_m)
    info(p,'flag',function()return txt('Byte +4','字节 +4','位元組 +4')end,tostring(b:byte(5)),'head',head,'Modifier',band_m)
    info(p,'groups',function()return txt('Groups','分组数','分組數')end,tostring(groups),'head',head,'Modifier',band_m)
    for g=0,groups-1 do
     local q=gat and gat+g*32
     if not q or q+32>#b then break end
     local ne,ea,nd,da=u32(b,q+8)or 0,ptr(q),u32(b,q+24)or 0,ptr(q+16)
     local sec='group'..g
     local sec_of=function()return txt('Group ','分组 ','分組 ')..(g+1)end
     for k=0,ne-1 do if ea then local hex=u64hex(b,ea+k*8)
      info(p,'entity'..g..'_'..k,function()return txt('Entity ','实体 ','實體 ')..(k+1)end,function()return entity_label(hex)end,sec,sec_of,'Modifier',band_m)end end
     for k=0,nd-1 do if da then
      local key=b:sub(da+k*8+1,da+k*8+8);local hex=D.hex(key)
      info(p,'delta'..g..'_'..k,function()return txt('Entity delta ','实体差异 ','實體差異 ')..(k+1)end,function()return delta_label(hex)end,sec,sec_of,'Modifier',band_m)
      delta_rows(p,key,sec,sec_of,'Modifier',band_m)
     end end
    end
   end
  end
 end
 -- 2. operation modifiers: every delta that changes the game mode or the hive mind
 if db then
  local band_o=function()return txt('Operation modifier (entity delta)','行动修饰符（实体差异）','行動修飾符（實體差異）')end
  local keys={};for key in pairs(dt.index)do keys[#keys+1]=key end;table.sort(keys,function(a,b)return D.hex(a)<D.hex(b)end)
  for _,key in ipairs(keys)do
   local list=changes(key);local hit=false
   for _,ch in ipairs(list or{})do if M.OPERATION[ch.comp]then hit=true end end
   if hit then
    local hex=D.hex(key)
    -- named after what it changes
    local en,zs,zt,seen={}, {}, {}, {}
    for _,ch in ipairs(list)do
     local mf=mission_fields[ch.comp]and mission_fields[ch.comp][ch.offset]
     local nm=DATA.FIELDS[ch.comp]and DATA.FIELDS[ch.comp][ch.offset]
     local l=mf or(nm and{nm[1],nm[2],nm[3]})
     if l and not seen[l[1]]and #en<3 then seen[l[1]]=true;en[#en+1]=l[1]:gsub('_',' ');zs[#zs+1]=l[2];zt[#zt+1]=l[3]end
    end
    local name='OperationModifier · '..(#en>0 and(table.concat(en,' / ')..(#list>#en and' …'or'')..' · ')or'')..hex
    if #zs>0 then M.titles[name]={'行动修饰符 · '..table.concat(zs,' / ')..(#list>#zs and' …'or'')..' · '..hex,'行動修飾符 · '..table.concat(zt,' / ')..(#list>#zt and' …'or'')..' · '..hex}end
    local p=page('OperationModifiers',name,'operation/'..hex);p.entity_hash=hex
    p.search=p.search..' '..table.concat(zs,' ')
    p.search=p.search..' '..((DATA.DELTAS[hex]or{})[1]or'')
    local comps={};for _,ch in ipairs(list)do comps[ch.comp:gsub('ComponentData$','')]=true end
    local names={};for n in pairs(comps)do names[#names+1]=n end;table.sort(names)
    p.note_of=function()return txt('Effect definition for mission game-mode entities, not an operation attachment list: ',
     '作用于任务游戏模式实体的效果定义；不是行动携带列表：','作用於任務遊戲模式實體的效果定義；不是行動攜帶列表：')..table.concat(names,' / ')end
    p.ensure_rows=function()
     if p.rows_built then return end;p.rows_built=true
     local sec_of=function()return txt('Changes','修改的参数','修改的參數')end
     delta_rows(p,key,'changes',sec_of,'OperationModifier',band_o)
    end
   end
  end
 end
end
return M
