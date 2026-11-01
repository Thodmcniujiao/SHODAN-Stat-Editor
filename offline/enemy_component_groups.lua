-- Presentation over the existing enemy/SEAF rows. The flat canonical rows remain
-- available to faction multipliers, config/preset ownership and bulk operations,
-- even while components are closed. No native field or virtual multiplier splits.
local Work=require('startup_work')
local M={}
function M.attach(c)
 local function eligible(page)
  return page.enemy and c.slots[page.slot]and page.slot~='Spawning'
 end
 local function raw(page)return page.enemy_component_rows or c.rows(page)end
 local function native(row,kinds)
  for _,part in ipairs(row.parts or{})do
   local f=part.field
   if f and f.storage~='virtual'and f.kind~=0 then kinds[f.kind]=true end
  end
 end
 for _,page in ipairs(c.weapons)do if eligible(page)then
  Work.checkpoint()
  local rows=raw(page)
  if #rows>0 then
  page.enemy_component_rows=rows
  local groups,by_type={},{}
  for _,row in ipairs(rows)do
   local kinds={};native(row,kinds)
   if row.faction then
    for _,other in ipairs(c.weapons)do
     if other.enemy and not other.enemy.faction
       and(page.enemy.global and c.slots[other.slot]and other.slot~='SEAF'or other.slot==page.slot)then
      for _,r in ipairs(raw(other))do for _,part in ipairs(r.parts or{})do
       local field=part.field
       if field and field.storage~='virtual'and row.faction[7](other,r,part)then kinds[field.kind]=true end
      end end
     end
    end
   end
   local infos,seen={},{}
   for kind in pairs(kinds)do
    local info=c.info(kind)
    if not seen[info.type]then infos[#infos+1]=info;seen[info.type]=true end
   end
   table.sort(infos,function(a,b)return(a.order or 100)<(b.order or 100)or
    (a.order or 100)==(b.order or 100)and a.type<b.type end)
   if #infos==0 then infos={{type='EnemyConvenience',label={'Convenience parameters','便捷参数','便捷參數'},order=900}}end
   local ids={};for _,info in ipairs(infos)do ids[#ids+1]=info.type end
   local key=table.concat(ids,'+')
   local group=by_type[key]
   if not group then
    group={type=key,label=infos[1].label,hide_type=#infos>1 or infos[1].hide_type,
     rows={},native_types=infos,default_expanded=true,order=infos[1].order or 100}
    if #infos>1 then
     group.label_of=function()
      local labels={};for _,info in ipairs(infos)do labels[#labels+1]=c.text(info.label)end
      return c.text({'Combined: ','组合参数：','組合參數：'})..table.concat(labels,' / ')
     end
    end
    by_type[key]=group;groups[#groups+1]=group
   end
   -- Keep existing parameter preferences keyed by the original row identity.
   row.parameter_identity=row.parameter_identity or c.identity(page,row)
   group.rows[#group.rows+1]=row
  end
  table.sort(groups,function(a,b)return a.order<b.order or a.order==b.order and a.type<b.type end)
  page.field_keys=page.field_keys or{}
  c.wrap(page,groups,{'Components','组件','組件'})
  end
 end end
end
return M
