-- Real editor integration, isolated profile, offscreen native GDI rendering.
local f=assert(io.open(TEST_ROOT..'/tests/test_editor_demolition_sync.lua','rb'));local text=f:read('*a'):gsub('\r\n','\n');f:close()
local start=assert(text:match('^(.-)local weapon=assert'))
start=start:gsub('local state\n',[[
write(I.home..'/preset_01.txt','name Existing full\n'..hash..' unit_demolition 321\n')
write(I.home..'/weapon_presets.txt',hash..' 5 unit_demolition 456\n')
local state
]],1)
local checks=[==[
local weapon=assert(E.by_hash[hash]);local normal=assert(weapon.by_id.unit_demolition)
assert(not E.presets.weapon_count and not E.presets.save_weapon_preset,'old quick preset API still exposed')
local library=E.presets.library;assert(library)
local old_full,old_single
for _,p in ipairs(library:list())do if p.name=='Existing full'then old_full=p elseif #p.values==1 and p.values[1].value==456 then old_single=p end end
assert(old_full and old_single,'legacy files were not imported')
E.select_weapon(weapon);E.ui.page=3;E.ui.row=2;E.ui.scroll=2;E.ui.search.text='retained search'
local tab,page=E.ui.tab,E.ui.nav.page
local row_index;for i,r in ipairs(weapon.rows)do if r==normal.row then row_index=i end end;assert(row_index)
E.ui.value={weapon=weapon,n=row_index,text='bad input'}
assert(not state.open_workspace('presets')and state.workspace_mode()=='editor','invalid field was discarded')
E.ui.value={weapon=weapon,n=row_index,text='777'}
assert(state.open_workspace('presets')and state.workspace_mode()=='presets')
assert(E.row_value(normal.row)==777,'pending value not committed')
local new_id=assert(E.presets.new_full_preset());assert(E.ui.editing)
E.ui.editing.text='命名方案';assert(E.presets.finish_rename(true));assert(library:get(new_id).name=='命名方案')
E.change(normal.row,0,false,999)
assert(E.presets.load_full_preset(new_id));assert(E.row_value(normal.row)==777,'named snapshot failed to load')
assert(E.presets.load_full_preset(old_single.id));assert(E.row_value(normal.row)==456,'legacy partial preset failed')
assert(state.open_workspace('settings')and state.workspace_mode()=='settings')
assert(state.open_workspace('editor')and state.workspace_mode()=='editor')
assert(E.ui.tab==tab and E.ui.nav.page==page and E.ui.weapon==weapon and E.ui.page==3 and E.ui.scroll==2 and E.ui.search.text=='retained search','editor context not restored')
local Stage={snapshot=function()return{version=0x107,values={primary=123}}end,apply_snapshot=function(self,data)self.loaded=data;return true end}
SHODAN_PLAYER_SAVE_MODEL=Stage
local Preload={snapshot=function()return{version=1,selected={A=true},targets={},edits={},arrays={}}end,apply_snapshot=function(self,data)self.loaded=data;return true end,reset=function()return true end}
SHODAN_PRELOAD_MODEL=Preload
assert(state.open_workspace('presets'));assert(E.presets.select_scope('loadout'))
local save_id=assert(E.presets.new_full_preset());assert(E.presets.finish_rename(false));assert(E.presets.load_full_preset(save_id));assert(Stage.loaded.values.primary==123)
assert(E.presets.select_scope('preload'));local preload_id=assert(E.presets.new_full_preset());assert(E.presets.finish_rename(false));assert(E.presets.load_full_preset(preload_id));assert(Preload.loaded.selected.A)
assert(E.presets.select_scope('game'));E.presets.show(new_id)
-- Real click routing and text editing, including Unicode groups and a literal group named next.
E.click('pgroup:new');assert(E.ui.editing.kind=='group');E.ui.editing.text='战术/中文分组';E.click('name:ok')
assert(E.ui.preset_group=='战术/中文分组'and E.presets.chosen()==nil)
E.presets.show(new_id);E.click('pmove:战术/中文分组');assert(library:get(new_id).group=='战术/中文分组')
E.click('fpreset:description');assert(not E.ui.editing,'single click must not edit description')
E.click('fpreset:description');assert(E.ui.editing.kind=='description')
E.ui.editing.text='支援火力方案 #1\n提高普通命中拆毁阈值；保留直击参数。\n适合测试建筑物拆毁。';E.click('name:ok')
assert(library:get(new_id).description:find('#1',1,true))
E.click('pgroup:new');E.ui.editing.text='next';E.click('name:ok');E.click('pgroup_id:next');assert(E.ui.preset_group=='next')
E.click('pgroup_id:*');E.presets.show(new_id)
local pages=E.presets.detail_pages(library:get(new_id))
local collapsed=E.presets.details(library:get(new_id));assert(#collapsed==#pages)
for _,row in ipairs(collapsed)do assert(row.kind=='page'and not row.expanded,'every main page must start collapsed')end
local main,sub
for _,page in ipairs(pages)do if page.count>0 then main=page;for _,section in ipairs(page.sections)do if section.count>0 then sub=section;break end end;break end end
assert(main and sub)
E.click('ptree_page:'..main.id)
local children=E.presets.details(library:get(new_id));local sections=0
for _,row in ipairs(children)do
 assert(row.kind~='parameter','subpages must also start collapsed')
 if row.kind=='section'then assert(row.count>0);sections=sections+1 end
end
assert(sections>0)
E.click('ptree_section:'..main.id..'/'..sub.id)
local normal_preview
for _,row in ipairs(E.presets.details(library:get(new_id)))do if row.kind=='parameter'then
 assert(row.entry.changed,'unchanged parameters must stay hidden')
 if row.entry.id=='0:normal'then normal_preview=row.entry end
end end
assert(normal_preview and normal_preview.value=='777','preview did not use the saved demolition value')
E.click('ptree_page:'..main.id)
local function render(lang,w,h,mode,suffix)
 E.settings.lang=lang;S.lang=function()return lang end;S.w,S.h=w,h;E.ui.version=E.ui.version+1
 if state.workspace_mode()~=mode then assert(state.open_workspace(mode))end
 local info=ffi.new('host_bitmapinfo');info.size=ffi.sizeof(info);info.width,info.height,info.planes,info.bits=w,-h,1,32
 local ptr=ffi.new('void *[1]');local dib=gdi.CreateDIBSection(S.dc,info,0,ptr,nil,0);assert(dib~=nil)
 local previous=gdi.SelectObject(S.dc,dib);S.bits=ffi.cast('uint32_t *',ptr[0]);gdi.SetBkMode(S.dc,1);gdi.SetTextAlign(S.dc,24)
 E.tick();S.sleep(1650);E.tick();assert(state.ui_errors==0 and E.ui.gui,'native workspace draw failed')
 local seen,description_regions,frame,back={},0;for _,region in ipairs(E.ui.regions)do
  if region.key=='panel'then frame=region elseif region.key=='workspace_back'then back=region end
  if region.key=='fpreset:description'then description_regions=description_regions+1 end
  seen[region.key]=true
  assert(not region.key:match('^wslot:')and not region.key:match('^wpreset:'),'quick preset controls survived')
  if mode=='presets'or mode=='settings'then
   assert(not region.key:match('^nav:')and not region.key:match('^cat:')and region.key~='reset_weapon','original page navigation leaked into workspace')
   assert(not region.key:match('^weapon:'),'background weapon list leaked into workspace')
  end
  if mode=='editor'then assert(region.key~='presets'and region.key~='settings','duplicate footer buttons survived')end
 end
 if mode=='presets'then
  assert(frame and back and back.y>=frame.y+frame.h,'Back to editor must be fully outside and above the gold workspace frame')
  for _,preset in ipairs(library:list())do
   local changes=0;for _,page in ipairs(E.presets.detail_pages(preset))do changes=changes+page.count end
   assert(E.presets.count(preset)==changes,'left list and changed-page totals disagree')
  end
  assert(description_regions==(E.ui.editing and E.ui.editing.kind=='description'and 0 or 1),'description must have one direct-edit region, no duplicate button')
  assert(not seen['pmenu:page']and not seen['pmenu:section'],'single-page selectors survived')
  assert(seen['fpreset:new']and seen['workspace_back']and seen['preset_folder']);for key in pairs(seen)do assert(not key:match('^preset_scope:'),'obsolete preset categories survived')end end
 S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/'..mode..'-'..suffix..'.bmp')
 gdi.SelectObject(S.dc,previous);gdi.DeleteObject(dib)
end
render('zh-Hans',1060,1080,'presets','zh')
E.click('pmenu:group');render('zh-Hans',1060,1080,'presets','groups');E.click('pmenu:dismiss')
E.click('ptree_page:'..main.id);render('zh-Hans',1060,1080,'presets','expanded');E.click('ptree_page:'..main.id)
E.click('fpreset:description');E.click('fpreset:description');render('zh-Hans',1060,1080,'presets','description');E.click('name:cancel')
render('en',1060,1080,'presets','en')
render('zh-Hans',3650,806,'presets','wide')
local payload=require('preset_library').copy(library:get(new_id));payload.values={}
for key,part in pairs(weapon.by_id)do
 local amount=part.row and E.row_value(part.row)
 if type(amount)=='number'and amount==amount and math.abs(amount)<1e90 then payload.values[#payload.values+1]={hash=weapon.hash,id=key,value=amount+1}end
 if #payload.values>=36 then break end
end
assert(#payload.values>8,'fixture needs enough real fields to exercise paging')
payload.description=string.rep('长描述滚动测试：支援火力与拆毁参数。',25)
local long_id=assert(library:create('global','多参数分页检查',payload));E.presets.show(long_id)
for _,row in ipairs(E.presets.details(library:get(long_id)))do assert(row.kind=='page'and not row.expanded,'switching presets must reset folds')end
local found_long=false
for _,page in ipairs(E.presets.detail_pages(library:get(long_id)))do for _,sub in ipairs(page.sections)do if #sub.rows>8 then
 E.click('ptree_page:'..page.id);E.click('ptree_section:'..page.id..'/'..sub.id);found_long=true;break
end end;if found_long then break end end
assert(found_long,'long preview page missing')
render('zh-Hans',1060,1080,'presets','long-first')
E.click('pdetail_scroll:next');assert(E.ui.preset_detail_scroll>1)
render('zh-Hans',1060,1080,'presets','long-next')
E.ui.hover='fpreset:description';E.ui.wheel_scroll(-3);assert(E.ui.preset_description_scroll>1,table.concat({tostring(E.ui.preset_description_scroll),tostring(E.ui.preset_description_last),tostring(E.ui.preset_menu),tostring(E.ui.editing),tostring(E.ui.tab),tostring(E.ui.settings)},','))
E.ui.hover=nil;E.ui.cursor_gx=E.ui.split_gx+10;local before=E.ui.preset_detail_scroll;E.ui.wheel_scroll(1);assert(E.ui.preset_detail_scroll<before)
E.presets.show(new_id)
render('zh-Hans',1060,1080,'settings','zh')
render('zh-Hans',1060,1080,'editor','zh')
assert(library:get(new_id),'preset disappeared after returning')
assert(#H.diff()==0,'preset UI modified shared DL data instead of canonical values')
gdi.DeleteDC(S.dc)
print('PASS: real editor named presets; legacy import/application; input guard; resource/custom scopes; preserved return context; no quick slots/APIs; independent preset/settings regions; Chinese/English/ultrawide native renders; no game writes')
]==]
assert(loadstring(start..checks,'@preset-workspace-integration'))()
