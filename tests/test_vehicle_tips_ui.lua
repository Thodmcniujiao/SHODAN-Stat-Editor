local f=assert(io.open(TEST_ROOT..'/tests/test_stratagem_editor.lua','rb'))
local prefix=assert(f:read('*a'):match('^(.-)local checks='));f:close()
local start=assert(loadstring(prefix..'\nreturn start'))()
start=start:gsub('MOD=MOD,','MOD=MOD,draw=draw,',1)
local setup=[==[
local vehicle_kind
for _,r in ipairs(require('stratagem_entity_specs').ROOTS)do if r[3]=='VehicleComponentData'then vehicle_kind=r[1]end end
local keys={}
for _,b in ipairs(D.entity_blocks(model.entities))do if b.type==vehicle_kind then
 local map=model.schemas[b.type].members[1]
 for i=0,map.count-1 do local at=b.payload+map.offset+i*16;local key=model.entities:sub(at+1,at+8)
  if key~=string.rep('\0',8)then keys[#keys+1]=key end
 end
end end
assert(#keys>4);table.sort(keys)
local buffer=ffi.new('uint8_t[?]',#keys*2048);local files={}
local function u(p,o,v)ffi.cast('uint32_t *',p+o)[0]=v end
local function number(p,o,v)ffi.cast('float *',p+o)[0]=v end
for i,key in ipairs(keys)do
 local p=buffer+(i-1)*2048
 number(p,0,1000+i);ffi.copy(p+4,string.rep('\255',28)..'\68\0\0\0',32)
 number(p,56,0);number(p,60,0);number(p,64,-.375)
 ffi.copy(p+128,'VR  ',4)
 for k,v in pairs({[1]=128,[2]=1056,[3]=1156,[5]=1256})do u(p,144+12+4*(k-1),v)end
 ffi.copy(p+272,'VRW ',4);u(p,276,4)
 for w=0,3 do
  local offset=64+w*160;u(p,280+w*4,offset);local at=272+offset+12
  u(p,at-8,w<2 and 1 or 0);number(p,at+4,w<2 and -1 or 1)
  number(p,at+24,1);number(p,at+28,.5);number(p,at+72,100);number(p,at+76,2);number(p,at+80,.3)
  u(p,at+68,w<2 and 0 or 1)
 end
 ffi.copy(p+1200,'VRE ',4);number(p,1224,5000);number(p,1228,750)
 ffi.copy(p+1300,'VRT ',4);u(p,1352,4)
 for g=1,4 do number(p,1352+4*g,5-g)end
 ffi.copy(p+1400,'VRB ',4);number(p,1416,100);number(p,1432,120)
 files[D.hex(key)..'.5F7203C8F280DAB8']={at=(i-1)*2048,size=2048}
end
TEST_VEHICLE_PHYSICS={buffer=buffer,files=files}
SHODAN_PHYSICS={base=tonumber(ffi.cast('uintptr_t',buffer)),files=files}
]==]
start=start:gsub('SHODAN_OFFLINE=true',function()return setup..'\nSHODAN_OFFLINE=true'end,1)
local checks=[==[
local Tips=require('vehicle_tips')
for _,id in ipairs({'mass','com','com_x','com_y','torque','rpm','gear1','gear4','brake','handbrake','front_grip','rear_radius','front_spring','rear_damping','front_travel'})do
 for _,lang in ipairs({'en','zh-Hans','zh-Hant','ru'})do local tip=assert(Tips.get(id,lang),id);assert(#tip==2 and #tip[1]>5)end
end
local owners={}
for _,page in ipairs(E.MOD.stratagem_entity_model.pages)do
 for _,g in ipairs(page.component_groups)do if g.archive_physics then
  assert(g.entity==page.entity_hash)
  local file=assert(TEST_VEHICLE_PHYSICS.files[page.entity_hash..'.5F7203C8F280DAB8'])
  for _,row in ipairs(g.rows)do for _,p in ipairs(row.parts)do
   assert(p.field.offset>=file.at and p.field.offset<file.at+file.size,'another entity physics file leaked into a page')
  end end
  if g.type:find(':Handling:',1,true)then owners[page.entity_hash]={page=page,group=g,file=file}end
 end end
end
local examples={};for _,owner in pairs(owners)do examples[#examples+1]=owner end;assert(#examples>=2,'archive physics disappeared from component folds')
local a,b=examples[1],examples[2]
E.select_weapon(a.page);E.MOD.nav.sync()
E.ui.expanded_components[a.page.hash..':'..a.group.type]=true;a.page.sync_rows(a.group.type)
local mass;for _,row in ipairs(a.group.rows)do if row.id=='phys_mass'then mass=row;break end end
assert(mass and mass.tip_of)
local original=E.row_value(mass);local other=ffi.cast('float *',TEST_VEHICLE_PHYSICS.buffer+b.file.at)[0]
E.change(mass,0,false,original+25);assert(a.group.header.component_modified())
assert(ffi.cast('float *',TEST_VEHICLE_PHYSICS.buffer+b.file.at)[0]==other,'changing one vehicle changed another entity')
E.reset_row(a.page,mass);assert(E.row_value(mass)==original and not a.group.header.component_modified())
E.settings.lang='zh-Hans';S.lang=function()return E.settings.lang end
assert(mass.tip_of()[1]:find('越重',1,true))
for n,row in ipairs(a.page.rows)do if row==mass then E.ui.row=n;E.ui.scroll=n;break end end
S.w,S.h=1272,1296;S.version=S.version+1
local info=ffi.new('host_bitmapinfo');info.size=ffi.sizeof(info);info.width,info.height,info.planes,info.bits=S.w,-S.h,1,32
local ptr=ffi.new('void *[1]');local dib=gdi.CreateDIBSection(S.dc,info,0,ptr,nil,0);assert(dib~=nil)
gdi.SelectObject(S.dc,dib);S.bits=ffi.cast('uint32_t *',ptr[0]);gdi.SetBkMode(S.dc,1);gdi.SetTextAlign(S.dc,24)
E.tick();S.sleep(1700);E.tick();assert(state.ui_errors==0)
E.ui.hover='row:'..E.ui.row;E.draw(S.w,S.h)
S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/vehicle-hover-zh.bmp')
assert(#H.diff()==0,'UI checks must not modify game tables');gdi.DeleteDC(S.dc)
print('PASS: four-language vehicle tips, archive physics visible in folds, per-entity file ownership, edit/star/reset and native hover render; synthetic physics and read-only game fixtures')
]==]
assert(loadstring(start..checks,'@vehicle-tips-ui'))()
