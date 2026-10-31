local M=require('weapon_component_groups')
local function component(key)
 local field={key=key,users={}};local part={id='shared',field=field}
 local row={id='shared',parts={part}};part.row=row
 local page={rows={},by_id={},component_view=key}
 page.ensure_rows=function()page.rows={row};page.by_id.shared=part;page.rows_built=true end
 local spec={KEY=key,TYPE=key,COMPONENT={key,key,key},FIELDS={{'shared',0,'u32','g','shared','shared','shared',{}, {id='shared'}}}}
 return spec,page,part
end
local a,ap,apart=component('first');local b,bp,bpart=component('second')
local weapon={slot='Weapons',hash='fixture',rows={},by_id={}}
M.attach({weapons={weapon},slots={Weapons=true},primary={{spec=a,view={by_entity={fixture=ap}}},{spec=b,view={by_entity={fixture=bp}}}},
 fallback={},subs={weapon={order=1,name={'Components','组件','組件'}}},changed=function()return false end,
 lang=function()return'en'end,text=function(t)return t[1]end,
 wrap=function(w,groups)
  w.component_groups=groups
  for _,g in ipairs(groups)do g.load=function()if not g.loaded then g.rows=g.ensure_rows();g.loaded=true end end end
 end})
local second
for _,g in ipairs(weapon.component_groups)do if g.spec==b then second=g end end
second.load();assert(bp.rows_built and not ap.rows_built)
assert(weapon.by_id.second_shared==bpart)
assert(weapon.by_id.shared==apart,'opening a later component changed precedence of an old saved ID')
assert(weapon.by_id.first_shared==apart and #apart.field.users==1 and #bpart.field.users==1)
second.load();assert(#bpart.field.users==1)
print('PASS: ambiguous saved IDs retain original component precedence regardless of lazy-open order; prefixed aliases and field ownership remain stable')
