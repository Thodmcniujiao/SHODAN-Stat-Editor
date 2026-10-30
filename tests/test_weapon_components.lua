-- The generated weapon components (offline/weapon_components.lua): 27 components (Equipment, Interactable too), every field once, no overlap, the
-- type-library layout checks pass on a library built from the specs' own LAYOUT / NESTED, pages build lazily.
-- python tests/run_lua.py tests/test_weapon_components.lua   (no game files needed; memory is simulated)
if not jit then   -- (plain Lua: a stand-in for the parts of demolition.lua the module uses)
 local function hex(k)local t={}for i=8,1,-1 do t[#t+1]=string.format('%02X',k:byte(i))end return table.concat(t)end
 package.loaded.demolition={hex=hex,hash_resource=function(s)
  local h=0;for i=1,#s do h=(h*131+s:byte(i))%4294967291 end
  local t={};for i=1,8 do t[i]=string.char(h%256);h=math.floor(h/256)end;return table.concat(t)end}
end
local V=require('component_view')
local W=require('weapon_components')
local SIZE={f32=4,u32=4,i32=4,enum=4,flag=1,u8=1,u64=8}
for b=0,7 do SIZE['bit'..b]=1 end
assert(#W.SPECS==27,#W.SPECS)
local total,subs=0,{weapon=0,type=0,attach=0,mount=0}
for _,spec in ipairs(W.SPECS)do
 subs[spec.SUB]=subs[spec.SUB]+1
 total=total+#spec.FIELDS
 -- every field inside the record, none overlapping (the bits of one byte share it), ids unique, groups used
 local spans,ids,groups,bitbytes={}, {}, {}, {}
 for _,s in ipairs(spec.FIELDS)do
  assert(SIZE[s[3]],spec.TYPE..' '..s[1]..' '..s[3])
  if not s[3]:match('^bit')or not bitbytes[s[2]]then spans[#spans+1]={s[2],s[2]+SIZE[s[3]],s[1]}end
  if s[3]:match('^bit')then bitbytes[s[2]]=true end
  local id=s[9].id;assert(not ids[id],spec.TYPE..' duplicate id '..id);ids[id]=true;groups[s[4]]=true
  assert(s[6]and s[7]and s[5],s[1])
 end
 table.sort(spans,function(a,b)return a[1]<b[1]end)
 for i,sp in ipairs(spans)do
  assert(sp[2]<=spec.SIZE,spec.TYPE..' '..sp[3])
  if i>1 then assert(sp[1]>=spans[i-1][2],spec.TYPE..' overlap: '..spans[i-1][3]..' / '..sp[3])end
 end
 for _,g in ipairs(spec.GROUPS)do assert(groups[g[1]],spec.TYPE..' empty group '..g[1])end
 -- a type library laid out as the spec says (bitfields: one member per bit), and the page built from zeroed memory
 local schemas,n={},100
 local function struct(size,layout,nested)
  local t={size=size,members={}}
  for _,e in ipairs(layout)do
   local inner=nested and nested[e[1]]
   local m={offset=e[1],size=e[2],count=1}
   if inner then n=n+1;m.type=n;schemas[n]=struct(inner.size,inner.layout,inner.nested)end
   t.members[#t.members+1]=m
  end
  return t
 end
 schemas[1]=struct(spec.SIZE,spec.LAYOUT,spec.NESTED)
 schemas.T={size=32,members={{type=0},{type=1}}}
 assert(V.check_layout(spec,schemas,'T'),spec.TYPE)
 local fields={}
 local function field_at(kind,off,st,lim)
  local bit=st:match('^bit(%d)$');local k=kind..':'..off..(bit and(':'..st)or'')
  fields[k]=fields[k]or{kind=kind,offset=off,storage=bit and'flag'or st,mask=bit and 2^tonumber(bit),limit=lim,key=k,users={}}
  return fields[k]
 end
 local function add_row(w,sec,id,label,st,parts,min,max)
  local r={section=sec,id=id,label=label,storage=st,parts=parts,min=min,max=max};w.rows[#w.rows+1]=r
  for _,p in ipairs(parts)do w.by_id[p.id]=p end
  return r
 end
 local out=V.build(spec,{table={index={[string.char(1,0,0,0,0,0,0,0)]=0}},kind='T',weapons={},by_hash={},field_at=field_at,
  read=function()return 0 end,add_row=add_row,schemas=schemas,lazy_rows=true,lang=function()return'zh-Hans'end})
 local page=out.pages[1]
 assert(#page.rows==0 and page.ensure_rows)
 page.ensure_rows();page.ensure_rows()
 assert(#page.rows==#spec.FIELDS,spec.TYPE..' rows '..#page.rows)
 for _,r in ipairs(page.rows)do assert(r.component_of()and r.section_of()and r.label_of()and r.tip_of())end
end
assert(total==2016,total)
assert(subs.weapon==8 and subs.type==9 and subs.attach==8 and subs.mount==2)
print('weapon components: ok ('..#W.SPECS..' components, '..total..' fields)')
