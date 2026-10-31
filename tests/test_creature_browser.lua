-- Real editor/component tables, isolated profile; no game writes.
local f=assert(io.open(TEST_ROOT..'/tests/test_stratagem_editor.lua','rb'))
local prefix=assert(f:read('*a'):match('^(.-)local checks='));f:close()
local start=assert(loadstring(prefix..'\nreturn start'))()
local checks=[==[
local C=require('creature_components');local V=require('component_view');local J=require('json_data')
local nav=E.MOD.nav.page('enemies');assert(nav.name[2]=='生物设置'and #nav.subs==5)
local index
for n,sub in ipairs(nav.subs)do if sub.name[2]=='生物组件'then index=n end end
assert(index and nav.subs[index+1].name[2]=='敌人替换器')
assert(table.concat(nav.subs[index].tabs,',')==table.concat(C.SUBS.creature,','))
assert(#nav.subs[2].tabs==4,'suppression components must not remain duplicated in AI tabs')
assert(not E.MOD.weapon_component_views.creature_avatar,'duplicate Avatar browser remains')
assert(E.MOD.component_tab_label.CreatureUnitComponents[2]=='单位')
local character=E.MOD.nav.page('character')
local voice_parent,voice_sub=E.MOD.nav.locate('CharacterVoiceComponents')
assert(voice_parent==character and character.subs[voice_sub].name[2]=='角色语音')
local ai_types,creature_types={},{}
for _,s in ipairs(E.MOD.weapon_components.SPECS)do
 for _,slot in ipairs(nav.subs[2].tabs)do if slot==s.SLOT then ai_types[s.HASH]=true end end
 for _,slot in ipairs(C.SUBS.creature)do if slot==s.SLOT then
  assert(not creature_types[s.HASH],'duplicate creature component');creature_types[s.HASH]=true
 end end
end
for kind in pairs(creature_types)do assert(not ai_types[kind],'component duplicated in AI settings')end
local audit=J.array();local visible={}
for _,s in ipairs(E.MOD.weapon_components.SPECS)do
 local parent,sub=E.MOD.nav.locate(s.SLOT)
 if parent then visible[s.HASH]=parent.name[2]..' / '..parent.subs[sub].name[2]end
end
for _,s in ipairs(E.MOD.preload.SPECS)do
 local parent,sub=E.MOD.nav.locate(s.SLOT)
 if parent then visible[s.HASH]=parent.name[2]..' / '..parent.subs[sub].name[2]end
end
for typ,where in pairs({[0xB3915DE3]='实体组件 / 生命与拆毁',[0x5653EA91]='实体组件 / 生命与拆毁',
 [0x40EF204C]='人物数据 / 人物数据',
 [0x14729B6A]='生物设置 / AI设置',[0x1EBA7593]='实体组件 / 炮塔与制导',[0x3845B1E0]='实体组件 / 挂载',
 [0x8ADAB43B]='实体组件 / 挂载',[0x74FEF89A]='实体组件 / 地雷与投掷',[0xA29A84D8]='实体组件 / 地雷与投掷',
 [0xAF16BCB5]='实体组件 / 地雷与投掷',[0x5154DB66]='实体组件 / 生命与拆毁',
 [0x556FF68B]='轨道飞鹰 / 飞鹰编辑',[0x86B6558B]='轨道飞鹰 / 飞鹰编辑',
 [0x936A9C08]='轨道飞鹰 / 轨道武器编辑',[0xCDBC43D8]='轨道飞鹰 / 轨道编辑'})do visible[typ]=visible[typ]or where end
for _,root in ipairs(require('stratagem_entity_specs').ROOTS)do if not root[3]:match('^Component_0x')then
 local t=E.tables[root[1]];local count=0;for _ in pairs(t and t.index or{})do count=count+1 end
 audit[#audit+1]={type=root[3],hash=string.format('%08X',root[1]),bytes=root[2],entities=count,loaded=t~=nil,
  browser=visible[root[1]]or'Armory related-entity reflection only',standalone=visible[root[1]]~=nil}
end end
write(TEST_WORK..'/component-audit.json',J.encode(audit,true))
local examples={};local total=0
for _,s in ipairs(C.SPECS)do
 local parent,sub=E.MOD.nav.locate(s.SLOT)
 if s.TYPE=='CharacterVoiceComponentData'then assert(parent==character and sub==voice_sub,s.TYPE)
 else assert(parent==nav and sub==index,s.TYPE)end
 local views=assert(E.MOD.weapon_component_views[s.KEY]);assert(views.full,s.TYPE..': '..tostring(views.why)..' table='..tostring(E.tables[s.HASH]))
 assert(#views.pages>0,s.TYPE..' has no loaded entities')
 local page=views.pages[1];assert(not page.rows_built,s.TYPE..' eagerly built its records')
 page.ensure_rows();assert(#page.rows>0 and page.entity_hash)
 for _,row in ipairs(page.rows)do for _,p in ipairs(row.parts)do
  assert(p.field.kind==s.HASH and p.field.offset>=E.tables[s.HASH].index[page.key]
   and p.field.offset<E.tables[s.HASH].index[page.key]+s.SIZE,'another entity record leaked into the page')
 end end
 examples[s.KEY]=page;total=total+#s.FIELDS
end
assert(examples.creature_unit.rows[1].label_of()=='单位资源路径'or examples.creature_unit.rows[1].label_of()=='Unit path')
local unit_tip=table.concat(examples.creature_unit.rows[1].tip_of(),'\n')
assert(unit_tip:find('unit_path',1,true)and unit_tip:find('shalzuth',1,true))
assert(not unit_tip:find('Meaning unknown',1,true))
local function sync(id,kind,offset,view_key)
 local original,part
 for _,w in ipairs(E.weapons)do
  local p=w.enemy and not w.enemy.faction and w.by_id[id]
  if p and p.field.kind==kind then original,part=w,p;break end
 end
 assert(part,'missing curated field '..id)
 local key;for k,at in pairs(E.tables[kind].index)do if at+offset==part.field.offset then key=k;break end end
 assert(key)
 local page=assert(E.MOD.weapon_component_views[view_key].by_entity[D.hex(key)]);page.ensure_rows()
 local row
 for _,r in ipairs(page.rows)do for _,p in ipairs(r.parts)do if p.field==part.field then row=r end end end
 assert(row,'browser does not share the curated field '..id)
 local before=E.row_value(part.row);E.select_weapon(page);E.change(row,0,false,before+1)
 assert(math.abs(E.row_value(part.row)-(before+1))<.001)
 assert(E.MOD.page_changed(original)and E.MOD.page_changed(page))
 E.reset_row(page,row);assert(E.row_value(part.row)==before)
 return page
end
local danger=sync('danger_radius',0xC677F538,4,'sensor_danger')
local targeting=sync('flinch',0x2C0968D2,36,'targeting')
assert(E.MOD.nav.locate('SensorDangerComponents')==nav and E.MOD.nav.locate('TargetingComponents')==nav)
local avatar_fields=0
for _,page in ipairs(E.weapons_in('Helldiver'))do for _,group in ipairs(page.component_groups or{})do
 if group.type=='AvatarComponentData'then for _,row in ipairs(group.rows)do for _,part in ipairs(row.parts)do
  if part.field.kind==0x40EF204C then avatar_fields=avatar_fields+1 end
 end end end
end end
assert(avatar_fields>0,'removing the duplicate Avatar view removed Character data fields')
local voice=examples.character_voice;local voice_row=assert(voice.rows[1]);local before=E.row_value(voice_row)
E.select_weapon(voice);E.change(voice_row,0,false,before==4294967295 and before-1 or before+1)
assert(E.MOD.page_changed(voice),'voice edit does not mark the moved page')
E.reset_row(voice,voice_row);assert(E.row_value(voice_row)==before)
-- Render the longest tab row and representative large component pages in the native UI.
S.w,S.h=1460,1080;S.version=S.version+1
local info=ffi.new('host_bitmapinfo');info.size=ffi.sizeof(info);info.width,info.height,info.planes,info.bits=S.w,-S.h,1,32
local ptr=ffi.new('void *[1]');local dib=gdi.CreateDIBSection(S.dc,info,0,ptr,nil,0);assert(dib~=nil)
gdi.SelectObject(S.dc,dib);S.bits=ffi.cast('uint32_t *',ptr[0]);gdi.SetBkMode(S.dc,1);gdi.SetTextAlign(S.dc,24)
E.settings.lang='zh-Hans';S.lang=function()return E.settings.lang end
for _,entry in ipairs({{examples.creature_unit,'unit'},{targeting,'suppression'},{examples.status_receiver,'status'},
 {examples.character_voice,'voice',true}})do
 state.nav_open(entry[3]and'character'or'enemies',entry[3]and voice_sub or index);E.select_weapon(entry[1]);E.MOD.nav.sync()
 E.tick();S.sleep(1700);E.tick();assert(state.ui_errors==0)
 local buttons={};for _,r in ipairs(E.ui.regions)do buttons[r.key]=true end
 if entry[3]then assert(not buttons['cat:CreatureUnitComponents'],'creature tab leaked into Character')
 else for _,tab in ipairs(C.SUBS.creature)do assert(buttons['cat:'..tab],'missing component tab '..tab)end end
 S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/creature-'..entry[2]..'.bmp')
end
assert(#H.diff()==0,'component browser checks modified game memory')
gdi.DeleteDC(S.dc)
print('PASS: '..#C.SUBS.creature..' distinct creature tabs, no AI duplicates; Avatar stays in Character data, voice moves to Character; '..total..' generated fields, lazy rows, entity ownership, shared suppression edits/stars/reset and native renders; no game writes')
]==]
assert(loadstring(start..checks,'@creature-browser'))()
