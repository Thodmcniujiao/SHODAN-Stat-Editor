-- Full native Health view, with the original basic fields kept as compatibility aliases.
-- Large per-zone rows are made only on selection/preset restore, never for every entity at startup.
local D=require('demolition')
local V=require('component_view')
local M={}
M.SPEC=require('health_schema')
function M.check_layout(schemas,kind)
 local ok,why=V.check_layout(M.SPEC,schemas,kind)
 if not ok then return ok,why end
 -- EffectSetting: five independent single-bit flags. The merged byte layout alone cannot validate this.
 local t=schemas[0x10CEE58B];local bits={}
 for _,m in ipairs(t and t.members or{})do
  if m.atom==3 then bits[#bits+1]=m.offset..':'..m.storage..':'..m.size..':'..m.count end
 end
 table.sort(bits)
 if table.concat(bits,',')~='44:4:1:1,44:4:1:1025,44:4:1:257,44:4:1:513,44:4:1:769'then return nil,'EffectSetting packed flags differ'end
 return true
end
local BODY={
 {'health','Health',0,'u32',10000000,1000000,10,100},
 {'armor','Armor',280,'u32',100,10,1,1},
 {'durable','Durable ratio (0-1)',268,'f32',1,1,.05,.1},
 {'explosive','Explosive damage taken (x)',388,'f32',100,100,.05,.25},
 {'bleed','Bleed-out health',24,'u32',10000000,1000000,10,100},
 {'regen','Regeneration (health/s)',4,'f32',1000000,100000,1,10},
 {'regen_delay','Regeneration delay after damage (s)',12,'f32',3600,600,.1,1},
}
local ZONE={
 {'health','Health',232,'u32',10000000,1000000,10,100},
 {'armor','Armor',216,'u32',100,10,1,1},
 {'durable','Durable ratio (0-1)',204,'f32',1,1,.05,.1},
 {'explosive','Explosive damage taken (x)',324,'f32',100,100,.05,.25},
 {'to_body','Damage passed to the body (x)',248,'f32',100,100,.05,.25},
 {'fatal','Killing it kills the enemy',244,'flag',1,1,1,1},
}
function M.build(c)
 local out={pages={},by_entity={}}
 if not c.table then return out end
 local names,zones,owners,users,enemy_records={},{},{},{},{}
 local full,why=M.check_layout(c.schemas,c.kind)
 out.full,out.why=full,why
 for _,w in ipairs(c.weapons)do
  if w.key then names[w.key]=names[w.key]or w.name end
  if w.enemy and w.enemy.members then
   for i,m in ipairs(w.enemy.members)do
    if c.table.index[m.key]then enemy_records[c.table.index[m.key]]=true end
    names[m.key]=w.name..(#w.enemy.members>1 and(' · '..i)or'')
    zones[m.key]={}
    for z,name in (w.enemy.zones or''):gmatch('(%d+)=([^;]*)')do zones[m.key][tonumber(z)]=c.zone_name(name)end
   end
  end
  for _,row in ipairs(w.rows)do for _,p in ipairs(row.parts)do
   if p.field.kind==c.kind and not owners[p.field.key]then owners[p.field.key]={weapon=w,part=p}end
  end end
 end
 local keys={}
 for key,at in pairs(c.table.index)do keys[#keys+1]=key;users[at]=(users[at]or 0)+1 end
 table.sort(keys,function(a,b)return D.hex(a)<D.hex(b)end)
 for _,key in ipairs(keys)do
  local at=c.table.index[key];local entity=D.hex(key)
  local path=(c.names or{})[entity]or''
  local name=names[key]or(path~=''and path:match('([^/]+)$'))or entity
  local hash=D.hex(D.hash_resource('shodan/components/health/'..entity:lower()))
  assert(not c.by_hash[hash],'Health component view hash collision')
  local page={name=name,hash=hash,key=key,slot='HealthComponents',health_component=true,
   health_enemy_scope=enemy_records[at],
   entity_hash=entity,path=path,health_offset=at,shared_count=users[at],rows={},by_id={},field_keys={}}
  page.note='HealthComponentData · '..entity..' · '..users[at]..' entity reference(s) to this record'
  page.note_of=function()
   local lang=c.lang and c.lang()or'en'
   if lang=='zh-Hans'or lang=='zh-Hant'then
    return 'HealthComponentData · '..entity..' · '..(users[at]>1 and('共用记录：'..users[at]..' 个实体，修改会一起生效')or'此实体的生命组件')
   end
   return page.note
  end
  local function rows(section,prefix,base,specs)
   for _,s in ipairs(specs)do
    local f=c.field_at(c.kind,at+base+s[3],s[4],s[5])
    local value=c.read(f)
    if value~=nil then
     local id=prefix..s[1];local p={id=id,field=f,health_owner=owners[f.key]}
     local row=c.add_row(page,section,id,s[2],s[4],{p},0,math.max(s[6],value),s[7],s[8])
     if section=='Health'then
      row.section_level='component'
      row.section_of=function()
       local lang=c.lang and c.lang()or'en'
       return lang=='zh-Hans'and'生命组件（Health）'or lang=='zh-Hant'and'生命組件（Health）'or'Health'
      end
     end
     page.field_keys[f.key]=true
    end
   end
  end
  rows('Health','',0,BODY)
  for z=0,37 do
   local base=520+z*552
   if c.zone_present(at+base+96)then rows((zones[key]or{})[z]or('Body part '..(z+1)),'zone'..z..'_',base,ZONE)end
  end
  c.by_hash[hash]=page;out.pages[#out.pages+1]=page;out.by_entity[entity]=page
 end
 table.sort(out.pages,function(a,b)
  local an,bn=a.name~=a.entity_hash,b.name~=b.entity_hash
  if an~=bn then return an end
  if a.name==b.name then return a.entity_hash<b.entity_hash end
  return a.name:lower()<b.name:lower()
 end)
 if full then M.complete(c,out,zones,owners)elseif c.log then c.log('Health: basic compatibility fields only: '..tostring(why))end
 return out
end

function M.complete(c,out,zones,owners)
 local original_field_at=c.field_at
 local ctx=setmetatable({lazy_rows=true,page_for=function(key)return out.by_entity[D.hex(key)]end,
  field_at=function(kind,at,storage,limit)
   local f=original_field_at(kind,at,storage,limit)
   -- Old enemy/quick pages read these signed native words as uint32. Keep their exact field object and owner.
   if storage=='i32'and f.storage=='u32'then f.storage='i32';f.signed=true;f.limit=2147483648 end
   -- FLT_MAX is a serialized "not specified" value (not corrupt data), notably on explosion multipliers.
   if storage=='f32'then f.limit=3.4028234663852886e38;f.signed=true end
   return f
  end,
  add_row=function(page,section,id,label,storage,parts,lo,hi,small,big)
   for _,p in ipairs(parts)do
    p.health_owner=owners[p.field.key]or p.health_owner
    if not owners[p.field.key]then owners[p.field.key]={weapon=page,part=p}end
   end
   return c.add_row(page,section,id,label,storage,parts,lo,hi,small,big)
  end},{__index=c})
 V.build(M.SPEC,ctx)
 local meta={};for _,s in ipairs(M.SPEC.FIELDS)do meta[s[9].id]=s end
 for _,page in ipairs(out.pages)do
  local fill=page.ensure_rows
  page.health_full=true
  page.ensure_rows=function()
   if page.rows_built then return end
   for _,row in ipairs(page.rows)do for _,p in ipairs(row.parts or{})do
    for i=#p.field.users,1,-1 do if p.field.users[i]==page then table.remove(p.field.users,i)end end
   end end
   page.rows,page.by_id={},{}
   fill()
   page.all_component_rows=page.rows
   local buckets={}
   for _,row in ipairs(page.rows)do
    local s=meta[row.id];local bucket=assert(s and s[9].bucket,'Health field has no category: '..row.id)
    row.health_path,row.health_offset,row.health_group=s[1],s[2],s[4]
    if row.storage=='f32'then
     row.input_text=function()return string.format('%.17g',c.read(row.parts[1].field))end
     local tip=row.tip_of
     row.tip_of=function()
      local lines=tip();lines[#lines+1]=V.pick(c.lang and c.lang()or'en',{
       'FLT_MAX (3.4028234663852886e38) is preserved as a special unspecified value; R restores the original value.',
       'FLT_MAX（3.4028234663852886e38）是未单独指定的特殊值，按原值保留；R 可恢复原值。',
       'FLT_MAX（3.4028234663852886e38）是未单独指定的特殊值，按原值保留；R 可恢复原值。'})
      return lines
     end
    end
    buckets[bucket]=buckets[bucket]or{};buckets[bucket][#buckets[bucket]+1]=row
   end
   if c.wrap then
    local groups={}
    local function group(key,title)
     if buckets[key]then
      local g={type='Health:'..key,hide_type=true,label=title,rows=buckets[key]}
      groups[#groups+1]=g;buckets[key]=nil;return g
     end
    end
    group('body',{'Body health','本体生命与倒地','本体生命与倒地'})
    group('regen',{'Regeneration and bleed-out','恢复与流血','恢复与流血'})
    group('unit',{'Unit and wounded state','体型、击杀与受伤状态','体型、击杀与受伤状态'})
    group('default',{'Default damage zone','默认受伤区域','默认受伤区域'})
    -- Configured parts first, global death/effect categories next, unnamed reserve slots last.
    local function zone_groups(configured)
     for z=0,37 do
      local present=c.zone_present(page.health_offset+520+z*552+96)
      if (not not present)==configured then
       local name=(zones[page.key]or{})[z]
       local field=page.by_id['zone'..z..'_info_zone_name'].field;local original=c.read(field)
       local g=group('zone'..z,{'Body part #'..z,'部位 #'..z,'部位 #'..z})
       g.label_of=function()
        local lang=c.lang and c.lang()or'en';local zh=lang=='zh-Hans'or lang=='zh-Hant'
        local value=c.read(field)
        local suffix=name and value==original and(c.translate and c.translate(name)or name)
         or value==0 and(zh and'未配置名称（ID = 0）'or'name ID = 0')
         or(zh and'名称 ID 'or'name ID ')..tostring(value)
        return (zh and'部位 #'or'Body part #')..z..' · '..suffix
       end
      end
     end
    end
    zone_groups(true)
    for _,g in ipairs(M.SPEC.GROUPS)do group(g[1],{g[2],g[3],g[4]})end
    zone_groups(false)
    assert(not next(buckets),'unplaced Health category')
    c.wrap(page,groups,{'Health parameter groups','生命组件参数分类','生命组件参数分类'})
   end
  end
 end
 if c.log then c.log('Health: '..#M.SPEC.FIELDS..' fields per record; 38 complete zone slots; native layout verified')end
end
return M
