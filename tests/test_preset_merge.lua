-- Preset folder refresh, preview jump targets and merging selected contents into another preset.
-- All files stay in TEST_WORK; nothing touches the game or the user's Presets folder.
local I=require('install');local F=require('preset_files');local L=require('preset_library');local Merge=require('preset_merge')
assert(TEST_WORK,'Use --work with a fresh isolated directory');I.mkdirs(TEST_WORK)
local dir=TEST_WORK..'/MergePresets';assert(F.mkdir(dir))
local W1,W2='EF85D6CF58E31D70','0123456789ABCDEF'
local war=4321
local function network(planets,effects)
 return {version=1,assignments={version=1,enabled=true,war_id=war,selected_planet=-1,targets=planets,
  definitions={['77']={effectType=1,nameHash=2},['88']={effectType=3,nameHash=4}},icon_pairs={['77']=1077,['88']=1088}},
  definitions={version=1,enabled=false,effects=effects or{}}}
end
local source={scope='global',kind='snapshot',values={
  {hash=W1,id='health',value=300},{hash=W1,id='speed',value=9},
  {hash=W2,id='ref_lo',value=5},{hash=W2,id='ref_hi',value=6}},
 data={version=3,game={stacks={},own_off={},armor_passives={['4660']={1,2}}},
  demolition={values={a={['0:hit']=50}},stale={}},
  loadout={version=0x107,values={primary=7},baseline={primary=1}},
  preload={version=1,edits={},selected={AAAA0000AAAA0000=true},targets={},arrays={},merge_enabled=true},
  network=network({['12']={effects={77},include_icons=true}}),legacy_preload={legacy_key='old',value={}}}}
local target={scope='global',kind='snapshot',values={{hash=W1,id='health',value=200},{hash=W1,id='speed',value=10},{hash=W2,id='other',value=1}},
 data={version=3,game={stacks={},own_off={},armor_passives={}}}}
local lib=L.new{dir=dir}
local sid=assert(lib:create('global','来源',source));local tid=assert(lib:create('global','目标',target))
-- controller with a minimal editor around it
local lang='zh-Hans'
local by_hash={[W1]={hash=W1,name='武器一',slot='Primary',by_id={health={row={label='Health'}},speed={row={label='Speed'}}}},
 [W2]={hash=W2,name='武器二',slot='Primary',by_id={ref_lo={row={label='Ref',hash64=true,id='ref',parts={{id='ref_lo'},{id='ref_hi'}}}},ref_hi={row={label='Ref'}},other={row={label='Other'}}}}}
by_hash[W2].by_id.ref_lo.row.parts[1].id='ref_lo';by_hash[W2].by_id.ref_hi.row=by_hash[W2].by_id.ref_lo.row
local defaults={health=100,speed=10,ref_lo=0,ref_hi=0,other=0}
local ui={version=0,fpage=1}
local now=0
local c={ui=ui,lang=function()return lang end,tr=function(v)return v end,tab_of=function(w)return w.slot end,by_hash=by_hash,
 navigation={{id='armory',name={'Armory','军械库','軍械庫'},subs={{name={'Weapons','武器','武器'},tabs={'Primary'}}}}},
 default_value=function(hash,id)return defaults[id]end,now=function()return now end,log=function()end,
 passive_name=function(id)return'Passive '..id end}
local P=require('preset_controller').new(c)
P.directory=dir;P.library=lib;ui.fslot=sid
-- jump targets ride on the preview rows
local found
for _,page in ipairs(P.detail_pages(lib:get(sid)))do for _,section in ipairs(page.sections)do for _,row in ipairs(section.rows)do
 if row.id=='health'then found=row end
 if row.id=='ref'then assert(row.jump.hash==W2 and row.jump.part=='ref_lo'and row.ref.ids[2]=='ref_hi','64-bit pair: one row, both ids')end
 if row.ref and row.ref.store=='game'then assert(row.jump.hash=='FFFFFFF800001234','armor rows open the armor page')end
end end end
assert(found and found.jump.hash==W1 and found.jump.id=='health'and found.pick=='values:'..W1..':health')
-- refresh: a preset copied into the folder (another library instance writes it) appears; nothing else changes
local other=L.new{dir=dir};local cid=assert(other:create('global','复制进来的',{values={}}))
local ok,added,removed=P.refresh(true);assert(ok and added==1 and removed==0,'new preset file is discovered')
assert(P.list()[cid]and P.list()[sid].name=='来源')
ui.editing={kind='description',n=sid,text=''};assert(P.refresh(true)==nil,'never while editing');ui.editing=nil
-- a stale library: the save fails, the folder is read again, the next try works
local stale=P.library;local outside=L.new{dir=dir};assert(outside:rename(tid,'目标'..'！'))
assert(not P.library:rename(sid,'改名失败'));P.library=stale
local okr=P.library:metadata(sid,'description','x');assert(not okr,'stale library must refuse')
assert(P.refresh(true));assert(P.library:get(tid).name=='目标！')
-- merge: select whole Armory page + a few stores, into the target
assert(P.merge_start());assert(ui.preset_merge.source==sid)
P.merge_toggle('page','armory')
assert(P.merge_state('page','armory')=='all')
P.merge_toggle('entry','values:'..W1..':speed')  -- unpick speed (equal at 10? no: source 9, target 10)
assert(P.merge_state('page','armory')=='some')
P.merge_toggle('entry','values:'..W1..':speed')
local picks={'game:armor_passives:4660','demolition:a:0:hit','loadout:primary','preload:selected:AAAA0000AAAA0000',
 'network:assignments:planet:12','network:assignments:field:enabled','legacy'}
for _,k in ipairs(picks)do P.merge_toggle('entry',k)end
assert(P.merge_preview()==nil,'a target must be chosen first')
local targets=P.merge_targets();local names={};for _,t in ipairs(targets)do names[t.label]=true end
assert(not names['来源'],'the source is not its own target')
P.merge_target(tostring(tid))
local plan=assert(P.merge_preview())
-- health 200 (changed in target) vs 300: conflict; speed 10 equals the game's own in the target: an addition
local kinds={}
for _,list in ipairs({'added','conflicts','same','blocked','kept'})do for _,e in ipairs(plan[list])do kinds[e.key]=list end end
assert(kinds['values:'..W1..':health']=='conflicts')
assert(kinds['values:'..W1..':speed']=='added','target at the game value: no conflict')
assert(kinds['values:'..W2..':ref_lo+ref_hi']=='added')
assert(kinds['game:armor_passives:4660']=='added'and kinds['loadout:primary']=='added'and kinds['demolition:a:0:hit']=='added')
assert(kinds['network:assignments:planet:12']=='added'and kinds['legacy']=='blocked')
local lines=P.merge_lines();assert(#lines>5 and lines[1].tone=='head')
P.merge_apply()
local t=assert(P.library:get(tid))
assert(ui.preset_merge==nil and ui.fslot==tid,'after merging the target is shown')
local v={};for _,e in ipairs(t.values)do v[e.hash..':'..e.id]=e.value end
assert(v[W1..':health']==300 and v[W1..':speed']==9 and v[W2..':ref_lo']==5 and v[W2..':ref_hi']==6 and v[W2..':other']==1)
assert(t.name=='目标！'and t.kind=='snapshot','name and mode stay the target\'s')
assert(t.data.game.armor_passives['4660'][2]==2 and t.data.demolition.values.a['0:hit']==50)
assert(t.data.loadout.values.primary==7 and t.data.loadout.baseline.primary==1 and t.data.loadout.version==0x107)
assert(t.data.preload.selected.AAAA0000AAAA0000==true)
local a=t.data.network.assignments
assert(a.war_id==war and a.enabled==true and a.targets['12'].effects[1]==77 and a.definitions['77'].nameHash==2 and a.icon_pairs['77']==1077)
assert(a.definitions['88']==nil,'only the merged planets\' definitions travel')
assert(not t.data.legacy_preload,'legacy plans never merge')
-- source untouched
local s=assert(P.library:get(sid));assert(#s.values==4 and s.data.network.assignments.targets['12'])
-- a merge against files changed outside: refused, the folder read again, the picks kept, preview again, then it works
local t3=assert(P.library:create('global','外部改动',{values={},data={version=3}}))
ui.fslot=sid;assert(P.merge_start());P.merge_toggle('entry','values:'..W1..':speed');P.merge_target(tostring(t3));assert(P.merge_preview())
assert(L.new{dir=dir}:rename(t3,'外部改名'))
assert(not P.merge_apply(),'stale files refuse the merge')
assert(ui.preset_merge and ui.preset_merge.plan==nil and ui.preset_merge.picked['values:'..W1..':speed'],'picks survive, preview reset')
assert(P.merge_preview());P.merge_apply()
assert(P.library:get(t3).name=='外部改名'and P.library:get(t3).values[1].value==9)
-- keep-target mode: conflicts stay, additions still go in
local t2=assert(P.library:create('global','保留目标',{values={{hash=W1,id='health',value=250}},data={version=3}}))
ui.fslot=sid;assert(P.merge_start());P.merge_toggle('entry','values:'..W1..':health');P.merge_toggle('entry','values:'..W1..':speed')
P.merge_target(tostring(t2));P.merge_keep();plan=assert(P.merge_preview())
assert(#plan.kept==1 and #plan.added==1 and #plan.conflicts==0)
P.merge_apply()
v={};for _,e in ipairs(P.library:get(t2).values)do v[e.id]=e.value end;assert(v.health==250 and v.speed==9)
-- nothing to do: already equal
ui.fslot=sid;assert(P.merge_start());P.merge_toggle('entry','values:'..W1..':health');P.merge_target(tostring(tid))
plan=assert(P.merge_preview());assert(plan.changes==0 and #plan.same==1);assert(not P.merge_apply());P.merge_cancel()
-- another war: the planet plan is blocked, everything else merges
local war2=assert(P.library:create('global','另一场战争',{values={},data={version=3,network={version=1,assignments={version=1,enabled=false,war_id=war+1,
 selected_planet=-1,targets={},definitions={},icon_pairs={}}}}}))
local direct=Merge.plan(P.library:get(sid),P.library:get(war2),{{store='network',kind='assignments',planet='12'},{store='values',hash=W1,ids={'health'}}})
assert(#direct.blocked==1 and direct.blocked[1].why:find('Galactic War')and #direct.added==1)
-- the plan never edits its inputs
assert(P.library:get(war2).values[1]==nil)
-- the panel draws in every state (headless: calls recorded, every control inside the panel)
local W,H=1000,932
local function draw()
 local keys={}
 local function inside(k,x,y,w,h)assert(x>=0 and y>=0 and x+w<=W+1 and y+h<=H+1,'outside the panel: '..tostring(k)..' '..x..','..y..' '..w..'x'..h);if k then keys[k]=true end end
 require('preset_panel').draw({presets=P,ui=ui,W=W,H=H,lang=c.lang,
  text=function()end,button=function(k,_,x,y,w,h)inside(k,x,y,w,h)end,rect=function(x,y,w,h)inside(nil,x,y,w,h)end,
  outline=function()end,region=function(k,x,y,w,h)inside(k,x,y,w,h)end,
  GOLD=1,WHITE=2,MUTED=3,WARN=4,selected=5,hover=6,line=7,input=8})
 return keys
end
ui.fslot=sid;ui.preset_tree=nil;ui.preset_merge=nil
assert(P.toggle_detail('page','armory'))
local keys=draw();assert(keys['fpreset:merge']and keys['fpreset:refresh'])
assert(P.toggle_detail('section','armory/Primary'))
keys=draw();local any=false;for k in pairs(keys)do if k:match('^pdetail:%d+$')then any=true end end;assert(any,'parameters take double-clicks')
assert(P.detail_entry(3)and P.detail_entry(3).jump.hash,'a parameter row resolves to its jump')
assert(P.merge_start());keys=draw()
assert(keys['pmerge_pick:page:armory']and keys['pmerge:preview']and keys['pmenu:merge_target'])
ui.preset_menu='merge_target';keys=draw();assert(keys['pmerge_target:'..tid]);ui.preset_menu=nil
P.merge_toggle('page','armory');P.merge_target(tostring(tid));assert(P.merge_preview());keys=draw()
assert(keys['pmerge:apply']and keys['pmerge:back']and not keys['pmerge_pick:page:armory'])
P.merge_cancel();draw()
print('PASS: preset folder refresh, stale-folder recovery, preview jump targets, page/section/parameter picks, conflict preview (overwrite and keep), 64-bit pairs, armor/demolition/equipment/preload/network merge, war mismatch and legacy blocking, source unchanged; panel drawn in browse, merge-pick, target-menu and preview states')
