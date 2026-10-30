-- A component-first view of one keyed ECS component (a spec: thrower_components.lua, throwable_components.lua):
-- every entity that has the component, every field of its record, under the component's heading in parameter
-- groups. Every field is shown. The layouts were checked field by field against the game's type library and every
-- value against the game's data and Darctor/Helldivers2_RawData
-- (https://github.com/Darctor/Helldivers2_RawData, 1.007.200); at start they are checked again against the
-- installed game's type library (LAYOUT, and NESTED for the structs inside it), and a difference (a game update) is
-- logged and shown under the page's title, without hiding any field.
-- Same field objects as the original pages (no duplicate value store): a field an original page already has keeps
-- saving under that page's config entry (health_owner, as on the Health page).
local D=require('demolition')
local M={}
local HASH=4294967295
M.HASH=HASH
-- value ranges: smallest, largest, small step, big step, signed
M.R={
 count={0,999,1,5},hp={0,10000000,50,250},sec={0,3600,.5,5},ssec={-1,3600,.5,5,true},rate={0,1000000,10,50},
 m={0,1000,.1,1},sm={-1000,1000,.1,1,true},ratio={0,1,.05,.1},deg={-360,360,1,5,true},rpm={0,100000,10,100},
 speed={0,1000,.1,1},raw={-1e9,1e9,.1,1,true},hash={0,HASH,1,1},flag={0,1,1,1},enum={0,HASH,1,1},u8={0,255,1,1},
 i32={-1,1000000,1,5,true},
}
M.ENUMS={
 orphan={[0]={'None','无','無'},{'Destroy','销毁','銷毀'},{'Stop','停止','停止'},{'Disconnect','断开','斷開'}},
}
M.ENUM_TYPE={orphan='UnitEffectOrphanStrategy',ability='AbilityId'}
local function pick(lang,t)return lang=='zh-Hans'and t[2]or lang=='zh-Hant'and t[3]or t[1]end
M.pick=pick
-- an enum's values in order (they need not be 0, 1, 2, ...: FactionType is 0, 1, 2, 4, 8, ...)
local function values_of(t)local list={};for v in pairs(t)do list[#list+1]=v end;table.sort(list);return list end

-- field builders: f(fields, name, offset, storage, group, en, 简体, 繁體, range, extra)
function M.field(list,name,off,storage,group,en,zhs,zht,range,extra)
 list[#list+1]={name,off,storage,group,en,zhs,zht,range or M.R.raw,extra}
end
-- a vector: three f32 fields x, y, z
function M.vec3(list,name,off,group,en,zhs,zht,range,id)
 for i,a in ipairs({'x','y','z'})do
  M.field(list,name..'.'..a,off+(i-1)*4,'f32',group,en..' '..a:upper(),zhs..' '..a:upper(),zht..' '..a:upper(),range or M.R.raw,
   {id=(id or name)..'_'..a})
 end
end
-- a UnitEffect (48 bytes): +0 particle effect (u64), +8 offset, +20 rotation offset, +32 node, +36 emit event,
-- +40 link option (UnitEffectOrphanStrategy), +44 effect flags: 5 bitfields of one byte (bit 0 inherit rotation,
-- bit 1 linked, bit 2 spawn on camera, bits 3 and 4 unknown; the dump calls those effect_unk_bit_4 / _5)
function M.unit_effect(list,name,off,group,en,zhs,zht,id)
 id=id or name
 M.field(list,name..'.particle_effect',off,'u64',group,en..': particle effect (resource hash)',zhs..'：粒子特效资源哈希',zht..'：粒子特效資源雜湊',M.R.hash,{id=id..'_particle'})
 M.vec3(list,name..'.offset',off+8,group,en..': offset',zhs..'：位置偏移',zht..'：位置偏移',M.R.sm,id..'_offset')
 M.vec3(list,name..'.rotation_offset',off+20,group,en..': rotation offset',zhs..'：旋转偏移',zht..'：旋轉偏移',M.R.deg,id..'_rotation')
 M.field(list,name..'.node_id',off+32,'u32',group,en..': node (hash)',zhs..'：节点（哈希）',zht..'：節點（雜湊）',M.R.hash,{id=id..'_node'})
 M.field(list,name..'.trigger_emit_event',off+36,'u32',group,en..': emit event (hash)',zhs..'：触发发射事件（哈希）',zht..'：觸發發射事件（雜湊）',M.R.hash,{id=id..'_emit'})
 M.field(list,name..'.link_option',off+40,'enum',group,en..': when orphaned',zhs..'：脱离宿主时',zht..'：脫離宿主時',M.R.enum,{id=id..'_link',enum='orphan'})
 for bit,b in ipairs({{'inherit_rotation','inherits rotation','继承旋转','繼承旋轉'},{'linked','linked','跟随宿主','跟隨宿主'},
  {'spawn_on_camera','spawns on the camera','在相机处生成','在相機處生成'},{'effect_unk_bit_4','unknown bit 3','未知位 3','未知位 3'},
  {'effect_unk_bit_5','unknown bit 4','未知位 4','未知位 4'}})do
  M.field(list,name..'.effect_flags_detail.'..b[1],off+44,'bit'..(bit-1),group,en..': '..b[2],zhs..'：'..b[3],zht..'：'..b[4],M.R.flag,
   {id=id..'_'..b[1]})
 end
end
M.UNIT_EFFECT={size=48,layout={{0,8},{8,12},{20,12},{32,4},{36,4},{40,4},{44,1}}}
M.VEC3={size=12,layout={{0,4},{4,4},{8,4}}}

-- sorted copy of a type's members
-- (bitfields: the library lists each bit as a member at its byte's offset, atom 3; they are one field here, as
-- large as the largest of them, e.g. a UnitEffect's effect_flags: inherit rotation, linked, spawn on camera, ...)
local function members_of(t)
 local list={}
 for _,m in ipairs(t.members)do list[#list+1]=m end
 table.sort(list,function(a,b)return a.offset<b.offset end)
 local merged={}
 for _,m in ipairs(list)do
  local last=merged[#merged]
  if last and last.offset==m.offset then
   last.bits=(last.bits or 1)+1;last.size=math.max(last.size,m.size);last.bitfield=last.bitfield or m.atom==3
  else merged[#merged+1]={offset=m.offset,size=m.size,count=m.count,type=m.type,storage=m.storage,atom=m.atom,bitfield=m.atom==3}end
 end
 return merged
end
local function describe(list)
 local got={}
 for _,m in ipairs(list)do
  got[#got+1]='+'..m.offset..':'..m.size..(m.bits and(' bits '..m.bits)or m.bitfield and' bit'or m.count and m.count>1 and('x'..m.count)or'')
 end
 return ' ('..table.concat(got,' ')..')'
end
-- (an inline array: its whole size, or one element's times the count)
local function same_size(m,size)
 if m.bitfield then return m.size<=size end   -- (a bitfield's storage: at most the field it is read as)
 return m.size==size or m.size*(m.count or 1)==size
end
local function check_struct(schemas,t,size,layout,nested,where)
 if t.size~=size then return nil,where..' is '..tostring(t.size)..' bytes, not '..size end
 local list=members_of(t)
 if #list~=#layout then return nil,where..' has '..#list..' fields, not '..#layout..describe(list)end
 for i,m in ipairs(list)do
  local e=layout[i]
  if m.offset~=e[1]or not same_size(m,e[2])then return nil,where..' fields differ at +'..e[1]..describe(list)end
  if e[3]and(m.storage~=e[3]or m.atom~=e[4]or m.count~=e[5])then return nil,where..' field type differs at +'..e[1]end
  if e[6]and m.type~=e[6]then return nil,where..' member type hash differs at +'..e[1]end
  local n=nested and nested[e[1]]
  if n then
   local inner=schemas[m.type]
   if inner then
    local ok,why=check_struct(schemas,inner,n.size,n.layout,n.nested,where..' +'..e[1])
    if not ok then return nil,why end
   elseif n.required then return nil,where..' +'..e[1]..': no type for the nested record' end
  end
 end
 return true
end
-- true when the type library (type hash -> { size, members = { offset, size, count, type } }) lays the keyed
-- table's record out as spec.LAYOUT (and spec.NESTED); else nil, why
function M.check_layout(spec,schemas,kind)
 if type(schemas)~='table'then return nil,'no type library'end
 local t=schemas[kind or spec.HASH]
 if not t or #t.members~=2 then return nil,spec.TYPE..' is not a keyed table in the type library'end
 local row=schemas[t.members[2].type]
 if not row then return nil,'no record type'end
 return check_struct(schemas,row,spec.SIZE,spec.LAYOUT,spec.NESTED,'record')
end

-- spec: TYPE, KEY (namespace), SIZE, SLOT, FLAG (page flag), COMPONENT {en, 简体, 繁體}, GROUPS
-- ({key, en, 简体, 繁體} in page order), FIELDS, LAYOUT, NESTED, ENUMS (extra names)
function M.prepare(spec)
 spec.GROUP={};for i,g in ipairs(spec.GROUPS)do spec.GROUP[g[1]]={n=i,name={g[2],g[3],g[4]}}end
 for i,s in ipairs(spec.FIELDS)do s.n=i;assert(spec.GROUP[s[4]],s[1])end
 table.sort(spec.FIELDS,function(a,b)
  local ga,gb=spec.GROUP[a[4]].n,spec.GROUP[b[4]].n;if ga~=gb then return ga<gb end;return a.n<b.n end)
 spec.VERIFIED=0;for _,s in ipairs(spec.FIELDS)do if s[9]and s[9].verified then spec.VERIFIED=spec.VERIFIED+1 end end
 return spec
end

function M.build(spec,c)
 local out={pages={},by_entity={}}
 if not c.table then return out end
 local function lang()return c.lang and c.lang()or'en'end
 local function zh()local l=lang();return l=='zh-Hans'or l=='zh-Hant'end
 local full,why=M.check_layout(spec,c.schemas,c.kind)
 out.full,out.why=full,why
 if spec.STRICT and not full then
  if c.log then c.log(spec.KEY..': incompatible layout: '..tostring(why))end
  return out
 end
 if c.log then
  c.log(spec.KEY..': all '..#spec.FIELDS..' fields'..(full and' (type library layout matches)'
   or(' -- the type library differs, check before editing: '..tostring(why))))
 end
 local names,owners,users={},{},{}
 for _,w in ipairs(c.weapons)do
  if w.key then names[w.key]=names[w.key]or w.name end
  if w.enemy and w.enemy.members then
   for i,m in ipairs(w.enemy.members)do names[m.key]=w.name..(#w.enemy.members>1 and(' · '..i)or'')end
  end
  for _,row in ipairs(w.rows)do for _,p in ipairs(row.parts)do
   if p.field.kind==c.kind and not owners[p.field.key]then owners[p.field.key]={weapon=w,part=p}end
  end end
 end
 local enums=setmetatable(spec.ENUMS or{},{__index=M.ENUMS})
 -- an entity's name by its hash (16 hex digits): the editor's pages, else the last part of its resource path
 local by_hex={}
 for key,n in pairs(names)do by_hex[D.hex(key)]=n end
 local function entity_name(hex)
  if hex=='0000000000000000'then return pick(lang(),{'none','无','無'})end
  local friendly=spec.ENTITY_NAMES and spec.ENTITY_NAMES[hex]
  if friendly then return pick(lang(),friendly)end
  local path=(c.names or{})[hex]
  return by_hex[hex]or(path and path:match('([^/]+)$'))or nil
 end
 local function enum_name(x,v)
  local t=x.enum and enums[x.enum];local n=t and v~=nil and t[v]
  return n and pick(lang(),n)or nil
 end
 local keys={}
 for key,at in pairs(c.table.index)do keys[#keys+1]=key;users[at]=(users[at]or 0)+1 end
 table.sort(keys,function(a,b)return D.hex(a)<D.hex(b)end)
 for _,key in ipairs(keys)do
  local at=c.table.index[key];local entity=D.hex(key)
  local path=(c.names or{})[entity]or''
  local name=(spec.NAMES and spec.NAMES[entity])or names[key]or(path~=''and path:match('([^/]+)$'))or entity
  local hash=D.hex(D.hash_resource('shodan/components/'..spec.KEY..'/'..entity:lower()))
  local existing=c.page_for and c.page_for(key)
  assert(existing or not c.by_hash[hash],spec.TYPE..' component view hash collision')
  local page=existing or{name=name,hash=hash,key=key,slot=spec.SLOT,[spec.FLAG]=true,component_view=spec.KEY,
   entity_hash=entity,path=path,component_offset=at,shared_count=users[at],rows={},by_id={},field_keys={}}
  if existing then
   hash=page.hash;page.component_view=spec.KEY;page.entity_hash=entity
   page.component_offset,page.shared_count,page.field_keys=at,users[at],page.field_keys or{}
  end
  page.catalog_hint=spec.CATEGORIES and spec.CATEGORIES[entity]
  page.note=spec.TYPE..' · '..entity..' · '..users[at]..' entity reference(s) to this record'
  local short=not full and tostring(why):gsub(' %(.*$','')or nil
  page.note_of=function()
   if short then
    return spec.TYPE..' · '..entity..(zh()and(' · 注意：游戏类型库与解析不一致（'..short..'），修改前请先核对')
     or(' · warning: the type library differs ('..short..'), check before editing'))
   end
   if zh()then
    return spec.TYPE..' · '..entity..' · '..(users[at]>1 and('共用记录：'..users[at]..' 个实体，修改会一起生效')
     or('此实体的'..pick('zh-Hans',spec.COMPONENT):gsub('（.*$','')))
   end
   return page.note
  end
  if spec.NOTICE then
   local source_note=page.note_of
   page.note_of=function()return pick(lang(),spec.NOTICE)..' · '..source_note()end
  end
  -- the rows: at once, or (c.lazy_rows: the big weapon components) the first time the page is shown or one of its
  -- saved values is applied (page.ensure_rows, called by the editor)
  local function fill()
  for _,s in ipairs(spec.FIELDS)do
   local x=s[9]or{}
   do
    local field,off,storage,group,r=s[1],at+s[2],s[3],s[4],s[8]
    local id=x.id or field
    local section=spec.KEY..':'..group
    local row
    local shared=storage=='u64'and c.field_at(c.kind,off,'u32',HASH)
    if shared and shared.storage~='u32'then
     -- an original page already reads these 8 bytes its own way (the SEAF weapons: storage 'gun', a choice from
     -- a list): the same field and the same choice here
     local value=c.read(shared)
     if value~=nil then
      row=c.add_row(page,section,id,s[5],shared.storage,{{id=id,field=shared,health_owner=owners[shared.key]}},1,HASH,1,10)
      row.choice=shared.storage
      page.field_keys[shared.key]=true
     end
    elseif storage=='u64'then
     local lo,hi=shared,c.field_at(c.kind,off+4,'u32',HASH)
     if c.read(lo)~=nil and c.read(hi)~=nil then
      row=c.add_row(page,section,id,s[5],'u64',{{id=id..'_lo',field=lo},{id=id..'_hi',field=hi}},0,HASH,1,1)
      row.hash64,row.lead=true,true
      page.field_keys[lo.key],page.field_keys[hi.key]=true,true
     end
    else
     local st=storage=='enum'and'u32'or storage
     local limit=st=='f32'and 1e12 or(st=='flag'or st:match('^bit'))and 1 or st=='u8'and 255
      or st=='i32'and 2147483648 or HASH
     local f=c.field_at(c.kind,off,st,limit)
     -- an original page already reads this field its own way (another width or kind, e.g. a reload flag read as a
     -- switch, an enemy's gun as a choice): the same field, read and written as that page does
     if f.storage~=st and not f.mask then
      st=f.storage
      if st=='gun'or st=='grenade'or st=='tier'then x=setmetatable({choice=st},{__index=x})end
     end
     -- (a field an original page made first keeps its own plausibility limit, e.g. a sight range read up to 1000 m;
     -- the layout is verified, so the wider limit: no row is dropped for a value above it)
     if type(f.limit)=='number'and f.limit<limit and f.storage==st then f.limit=limit end
     -- (before the first read: negative values are refused otherwise; a float may always be negative, e.g. -1 for
     -- off, and below the range's smallest the row starts at the game's value)
     if r[5]or st=='f32'then f.signed=true end
     local value=c.read(f)
     if value~=nil then
      if x.most and f.most==nil then f.most=(c.default_of and c.default_of(f))or value end
      local max=r[2]
      if storage=='enum'and enums[x.enum]and not spec.OPEN_ENUMS then local list=values_of(enums[x.enum]);max=list[#list]end
      if f.most then max=f.most end
      row=c.add_row(page,section,id,s[5],f.storage,{{id=id,field=f,health_owner=owners[f.key]}},
       math.min(r[1],value),math.max(max,value),r[3],r[4])
      if x.choice then row.choice=x.choice end
      page.field_keys[f.key]=true
      if x.ref and c.reference then c.reference(row,x.ref,f,value)end   -- (an ID of another record: double-click opens it)
     end
    end
    if row then
     row.component=spec.TYPE
     row.component_of=function()return pick(lang(),spec.COMPONENT)end
     row.section_of=function()return pick(lang(),spec.GROUP[group].name)end
     local f1=row.parts[1].field
     local f2=row.parts[2]and row.parts[2].field
     row.label_of=function()
      local label=pick(lang(),{s[5],s[6],s[7]})
      local e
      if row.choice and c.choice_label then e=c.choice_label(row.choice,c.read(f1))
      elseif x.entity and f2 then
       local lo,hi=c.read(f1),c.read(f2)
       e=lo and hi and entity_name(string.format('%08X%08X',hi,lo))
      else e=enum_name(x,c.read(f1))end
      return e and(label..(zh()and'：'or': ')..e)or label
     end
     row.tip_of=function()
      local kind=storage=='u64'and'uint64 (exact decimal)'or storage=='enum'and((M.ENUM_TYPE[x.enum]or x.enum_type or'enum')..' (u32)')or storage
      local lines={field,string.format('%s +0x%X · %s',spec.TYPE,s[2],kind)}
      local t=x.enum and enums[x.enum]
      if t then
       local list={};for _,v in ipairs(values_of(t))do list[#list+1]=v..' = '..pick(lang(),t[v])end
       lines[#lines+1]=table.concat(list,'; ')
      end
      if x.note then lines[#lines+1]=pick(lang(),x.note)end
      if x.shal then
       lines[#lines+1]=pick(lang(),x.inferred and{
        'Name from the 2024 schemas (shalzuth/HelldiversData), paired with the current type library by member order: check before relying on it.',
        '名称取自 2024 年数据（shalzuth/HelldiversData），按成员类型顺序与当前类型库对齐推断，使用前请核对。',
        '名稱取自 2024 年資料（shalzuth/HelldiversData），按成員類型順序與當前類型庫對齊推斷，使用前請核對。'}or{
        'Name from the 2024 schemas (shalzuth/HelldiversData); the struct matches the current type library member for member.',
        '名称取自 2024 年数据（shalzuth/HelldiversData），该结构与当前类型库逐成员一致。',
        '名稱取自 2024 年資料（shalzuth/HelldiversData），該結構與當前類型庫逐成員一致。'})
      end
      if x.desc then lines[#lines+1]=pick(lang(),{'2024 description: ','2024 年说明：','2024 年說明：'})..x.desc end
      if field:find('unk_')then
       lines[#lines+1]=pick(lang(),{'Meaning unknown; position and type checked against the type library.',
        '含义尚未确认；位置与类型已按类型库核对。','含義尚未確認；位置與類型已按類型庫核對。'})
      end
      return lines
     end
    end
   end
  end
  end
  if c.lazy_rows then
   page.ensure_rows=function()if not page.rows_built then page.rows_built=true;fill()end end
  else fill()end
  c.by_hash[hash]=page;out.pages[#out.pages+1]=page;out.by_entity[entity]=page
 end
 table.sort(out.pages,function(a,b)
  local an,bn=a.name~=a.entity_hash,b.name~=b.entity_hash
  if an~=bn then return an end
  if a.name==b.name then return a.entity_hash<b.entity_hash end
  return a.name:lower()<b.name:lower()
 end)
 return out
end
return M
