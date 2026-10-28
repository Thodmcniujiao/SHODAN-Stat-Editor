-- ThrowerComponentData and ThrowableComponentData views (offline/component_view.lua and the two specs): layout,
-- nested type checks, groups, field sharing, lower-only counts and the fallback to the fields the editor had.
-- python tests/run_lua.py tests/test_thrower_components.lua   (no game files needed; memory is simulated)
if not jit then   -- (plain Lua: a stand-in for the parts of demolition.lua the module uses)
 local function hex(k)local t={}for i=8,1,-1 do t[#t+1]=string.format('%02X',k:byte(i))end return table.concat(t)end
 package.loaded.demolition={hex=hex,hash_resource=function(s)
  local h=0;for i=1,#s do h=(h*131+s:byte(i))%4294967291 end
  local t={};for i=1,8 do t[i]=string.char(h%256);h=math.floor(h/256)end;return table.concat(t)end}
end
local V=require('component_view')
local SIZE={f32=4,u32=4,i32=4,enum=4,flag=1,u8=1,u64=8}
for b=0,7 do SIZE['bit'..b]=1 end
local function layout_bytes(layout)local n=0;for _,e in ipairs(layout)do n=n+e[2]end;return n end

local function suite(name,spec,want)
 -- every field inside the record, no two overlapping, every group used
 assert(#spec.FIELDS==want.fields,name..' fields '..#spec.FIELDS)
 local spans,ids,groups={},{},{}
 local bitbytes={}
 for _,s in ipairs(spec.FIELDS)do
  -- (bitfields: one byte for all the bits at an offset)
  if not s[3]:match('^bit')or not bitbytes[s[2]]then spans[#spans+1]={s[2],s[2]+SIZE[s[3]],s[1]}end
  if s[3]:match('^bit')then bitbytes[s[2]]=true end
  local id=s[9]and s[9].id or s[1]
  assert(not ids[id],'duplicate id '..id);ids[id]=true;groups[s[4]]=true
 end
 table.sort(spans,function(a,b)return a[1]<b[1]end)
 local used=0
 for i,sp in ipairs(spans)do
  assert(sp[2]<=spec.SIZE,sp[3]);used=used+sp[2]-sp[1]
  if i>1 then assert(sp[1]>=spans[i-1][2],'overlap: '..spans[i-1][3]..' / '..sp[3])end
 end
 assert(spec.SIZE-used==want.padding,name..' padding '..(spec.SIZE-used))
 for _,g in ipairs(spec.GROUPS)do assert(groups[g[1]],name..' empty group '..g[1])end

 -- simulated memory: two records (the second shared by two entities), the library as the spec lays it out
 local K=function(n)return string.char(n,0,0,0,0,0,0,0)end
 local mem={}
 for r=0,1 do for _,s in ipairs(spec.FIELDS)do
  mem[r*spec.SIZE+s[2]]=0;if s[3]=='u64'then mem[r*spec.SIZE+s[2]+4]=0 end
 end end
 for off,v in pairs(want.values)do mem[off]=v;mem[spec.SIZE+off]=v end
 local fields={}
 local function field_at(kind,off,st,lim)   -- (as the editor's: bitN -> a 'flag' field with a mask)
  local bit=st:match('^bit(%d)$')
  local k=kind..':'..off..(bit and(':'..st)or'')
  fields[k]=fields[k]or{kind=kind,offset=off,storage=bit and'flag'or st,mask=bit and 2^tonumber(bit),limit=lim,key=k,users={}}
  return fields[k]
 end
 local function read(f)
  local v=mem[f.offset];if v==nil then return nil end
  if f.mask then return math.floor(v/f.mask)%2 end
  if v<(f.signed and -f.limit or 0)or v>f.limit then return nil end
  return v
 end
 local function add_row(w,sec,id,label,st,parts,min,max,small,big)
  local r={section=sec,id=id,label=label,storage=st,parts=parts,min=min,max=max,small=small,big=big}
  w.rows[#w.rows+1]=r
  for _,p in ipairs(parts)do w.by_id[p.id]=p;p.row=p.row or r;p.field.users[#p.field.users+1]=w end
  return r
 end
 local function schemas(broken)
  local out={T={size=32,members={{type=0},{type=1}}}}
  local n=10
  local function struct(size,layout,nested)
   local t={size=size,members={}}
   for _,e in ipairs(layout)do
    local m={offset=e[1],size=e[2],count=1}
    if layout==V.UNIT_EFFECT.layout and e[1]==44 then   -- effect_flags: one member per bit (atom 3), as in the library
     for bit=0,4 do t.members[#t.members+1]={offset=44,size=1,atom=3,count=bit*256+1}end
     m=nil
    end
    local inner=nested and nested[e[1]]
    if m and inner and not(broken=='nested'and inner.required)then n=n+1;m.type=n;out[n]=struct(inner.size,inner.layout,inner.nested)end
    if m then t.members[#t.members+1]=m end
   end
   return t
  end
  out[1]=struct(spec.SIZE,spec.LAYOUT,spec.NESTED)
  if broken=='moved'then local m=out[1].members[#out[1].members];m.offset=m.offset+1 end
  return out
 end
 local lang,logs='zh-Hans',{}
 local function build(sc)
  fields={}
  local old={name='old page',hash='0000000000000099',rows={},by_id={}}
  local o=want.owned
  add_row(old,'Old',o[2],o[2],o[3],{{id=o[2],field=field_at('T',o[1],o[3],1000000)}},0,1e6,1,5)
  local out=V.build(spec,{table={index={[K(1)]=0,[K(2)]=spec.SIZE,[K(3)]=spec.SIZE}},kind='T',weapons={old},by_hash={},
   field_at=field_at,read=read,add_row=add_row,default_of=function(f)return read(f)end,
   log=function(s)logs[#logs+1]=s end,schemas=sc,lang=function()return lang end})
  return out,old
 end

 local out,old=build(schemas())
 assert(out.full,logs[#logs]);assert(#out.pages==3)
 local p=out.by_entity['0000000000000002'];assert(p.note_of():find('共用记录：2'),p.note_of())
 assert(#p.rows==want.fields,#p.rows)
 local order,last={},nil
 for _,row in ipairs(p.rows)do
  assert(row.component==spec.TYPE and row.component_of()==V.pick('zh-Hans',spec.COMPONENT))
  local g=row.section_of();if g~=last then order[#order+1]=g;last=g end
 end
 assert(table.concat(order,',')==want.order,table.concat(order,','))
 local by={};for _,row in ipairs(p.rows)do by[row.id]=row end
 local q=out.by_entity['0000000000000001'];local first={};for _,row in ipairs(q.rows)do first[row.id]=row end
 local owned=first[want.owned[4]or want.owned[2]]
 assert(owned.parts[1].field==old.rows[1].parts[1].field and owned.parts[1].health_owner.weapon==old,'shared field')
 if want.check then want.check(by,read,lang)end
 lang='en';assert(p.rows[1].component_of()==spec.COMPONENT[1])
 local tip=p.rows[1].tip_of();assert(tip[2]:find(spec.TYPE..' %+0x'))

 -- a library that differs: only the fields the editor had
 -- a library that differs: every field still shown, with a warning under the title
 local out2=build(schemas('moved'));assert(not out2.full and logs[#logs]:find('type library differs'),logs[#logs])
 lang='zh-Hans';assert(out2.pages[1].note_of():find('类型库与解析不一致'),out2.pages[1].note_of())
 for _,pg in ipairs(out2.pages)do assert(#pg.rows==want.fields,#pg.rows)end
 if want.nested then
  local out3=build(schemas('nested'));assert(not out3.full and logs[#logs]:find('no type for the nested record'),logs[#logs])
 end
 assert(not build(nil).full and logs[#logs]:find('no type library'))
 print(name..': ok ('..want.fields..' fields)')
end

suite('throwable',require('throwable_components'),{fields=78,padding=66,owned={16,'throw_distance','f32'},
 order='投掷,携带数量,粘附与触发,引信,实体与动画,音效与尾迹特效,未知字段',
 values={[16]=20,[100]=4,[104]=5,[108]=3,[172]=-1,[184]=-1,[160]=1,[24]=-11},
 check=function(by,read)
  assert(read(by.throw_start.parts[1].field)==4 and read(by.throw_max.parts[1].field)==5 and read(by.throw_supply.parts[1].field)==3)
  assert(read(by.max_spawned_amount.parts[1].field)==-1 and by.max_spawned_amount.min<0)
  assert(read(by.fuse1_time.parts[1].field)==-1)
  assert(read(by.custom_angular_velocity_min_x.parts[1].field)==-11)
  assert(by.trail_link.label_of()=='尾迹：脱离宿主时：销毁',by.trail_link.label_of())
  assert(by.trail_particle.hash64 and by.fuse6_unk.hash64)
  assert(by.trail_linked.parts[1].field.mask==2 and by.trail_linked.storage=='flag')
 end})

suite('thrower',require('thrower_components'),{fields=186,padding=28,owned={40,'mine_panels','u32','panels'},nested=true,
 order='编队 1,编队 2,编队 1：资源与音效,编队 2：资源与音效,编队 1：抛射特效,编队 2：抛射特效,编队 1：抛射节点,编队 2：抛射节点,编队 1：未知字段,编队 2：未知字段',
 values={[40]=6,[44]=2,[376+40]=3,[376+44]=4,[248]=2,[280]=90,[268]=90},
 check=function(by,read)
  -- the counts only go down from the game's values
  assert(by.panels.max==6 and by.per_panel.max==2 and by.f2_panels.max==3 and by.f2_per_panel.max==4)
  assert(by.panels.parts[1].field.most==6 and by.f2_per_panel.parts[1].field.most==4)
  assert(read(by.arming.parts[1].field)==2 and read(by.spread.parts[1].field)==90)
  assert(by.f2_node48 and by.f2_node48.parts[1].field.offset==752+376+48+47*4)
  assert(by.throwable.hash64 and by.f2_unk_158.hash64)
 end})

suite('minefield',require('minefield_components'),{fields=11,padding=6,owned={8,'mine_trigger','f32'},
 order='触发,爆炸与 AI 回避,音效,未知字段',values={[8]=1,[24]=179,[36]=2,[32]=1},
 check=function(by,read)
  assert(by.step_detection_min_unit_size.label_of()=='可触发的最小单位体型：大',by.step_detection_min_unit_size.label_of())
  assert(read(by.explosion_type.parts[1].field)==179)
 end})

suite('mine spawner',require('mine_spawner_components'),{fields=7,padding=3,owned={16,'mine_wide','u32'},
 order='布雷范围,未知字段',values={[16]=4,[20]=4,[8]=48,[12]=24,[24]=6},
 check=function(by,read)
  assert(read(by.mine_wide.parts[1].field)==4 and read(by.mine_width.parts[1].field)==48)
  assert(by.unk_uint64_0x0000.hash64)
 end})

suite('faction',require('faction_components'),{fields=32,padding=3,owned={72,'priority','f32'},
 order='阵营,被瞄准,生成影响,复杂瞄准节点,瞄准时忽略的单位,未知字段',values={[0]=1,[4]=32,[8]=0,[72]=1},
 check=function(by,read)
  assert(by.faction1.label_of()=='阵营 1：超级地球' and by.faction2.label_of()=='阵营 2：平民',by.faction2.label_of())
  assert(by.faction1.max==32,by.faction1.max)
  assert(by.ignored6.hash64 and by.complex_node16.parts[1].field.offset==152+84+60)
 end})

suite('mount',require('mount_components'),{fields=30,padding=10,owned={12,'side','u32','mount1_side'},nested=true,
 order='挂载位 1,挂载位 2,挂载位 3,挂载位 4,挂载位 5',values={[12]=1,[24+12]=2,[20]=1},
 check=function(by,read)
  assert(by.mount1_side.label_of()=='挂载侧：右侧' and by.mount2_side.label_of()=='挂载侧：左侧')
  assert(by.mount1_entity.hash64 and by.mount1_entity.label_of()=='挂载的实体：无',by.mount1_entity.label_of())
  assert(by.mount5_unk15.parts[1].field.offset==120+96+21)
 end})

suite('inventory',require('inventory_components'),{fields=20,padding=3,owned={48,'stims','u32','start_amount_stims'},
 order='默认装备,治疗针,其他,未命名装备列表',values={[48]=2,[52]=2,[56]=4,[60]=1},
 check=function(by,read)
  assert(read(by.max_amount_stims.parts[1].field)==4 and by.default_primary.hash64)
  assert(by.default_primary.label_of()=='主武器：无',by.default_primary.label_of())
  assert(by.unk_entity10.parts[1].field.offset==144+64+72)
 end})

suite('sensor eye',require('sensor_eye_components'),{fields=11,padding=3,owned={0,'sight','f32'},
 order='视野范围,视线,植被',values={[0]=3000,[4]=-1,[8]=-1,[32]=2},
 check=function(by,read)
  assert(read(by.sight.parts[1].field)==3000 and by.sight.parts[1].field.limit>=3000)   -- (the old page's limit: 1e6 here)
  assert(read(by.back_distance.parts[1].field)==-1 and by.eye_type.label_of()=='视觉类型：锥形')
 end})

suite('turret',require('turret_components'),{fields=19,padding=0,owned={12,'turn_h','f32'},
 order='转动,转动范围,节点,音效',values={[12]=18,[8]=18,[20]=-45,[28]=-180},
 check=function(by,read)
  assert(read(by.vertical_limit_min.parts[1].field)==-45 and read(by.horizontal_limit_min.parts[1].field)==-180)
 end})
