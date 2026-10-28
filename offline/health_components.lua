-- A component-first view of the existing live Health fields. No duplicate value store.
local D=require('demolition')
local M={}
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
 local names,zones,owners,users={},{},{},{}
 for _,w in ipairs(c.weapons)do
  if w.key then names[w.key]=names[w.key]or w.name end
  if w.enemy and w.enemy.members then
   for i,m in ipairs(w.enemy.members)do
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
 return out
end
return M
