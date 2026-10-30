-- Native Unicode filesystem + saved-payload preview; all writes confined to TEST_WORK.
local I=require('install');local F=require('preset_files');local L=require('preset_library');local J=require('json_data')
assert(TEST_WORK,'Use --work with a fresh isolated directory');I.mkdirs(TEST_WORK)
local dir=TEST_WORK..'/Presets';assert(F.mkdir(dir))
local lib=L.new{dir=dir}
assert(lib:create_group('中文分组/子目录'));assert(lib:create_group('Control'));assert(lib:create_group('next'))
local hash='EF85D6CF58E31D70'
local id=assert(lib:create('global','测试方案',{group='中文分组/子目录',description='第一行 #说明\n第二行：测试 🚀',values={{hash=hash,id='health',value=250}},data={version=2}}))
assert(F.read(dir..'/中文分组/子目录/测试方案.json'))
assert(lib:metadata(id,'description','描述更新\n保留 # 与中文'));assert(lib:rename(id,'重命名'))
assert(not F.read(dir..'/中文分组/子目录/测试方案.json'))
assert(lib:replace(id,{scope='global',values={{hash=hash,id='health',value=300}},data={version=2}}))
local p=lib:get(id);assert(p.description=='描述更新\n保留 # 与中文'and p.group=='中文分组/子目录')
local other=assert(lib:create('global','重命名',{group='Control',values={}}))
assert(lib:metadata(other,'group','中文分组/子目录'))
assert(F.read(dir..'/中文分组/子目录/重命名 (2).json'))
-- Physical folder moves win over metadata; share/import preserves descriptions and nested groups.
assert(F.mkdir(dir..'/手动移动'));assert(F.move(dir..'/中文分组/子目录/重命名.json',dir..'/手动移动/重命名.json'))
local reopened=L.new{dir=dir};assert(reopened:get(id).group=='手动移动')
assert(reopened:get(id).description=='描述更新\n保留 # 与中文')
local group_set={};for _,g in ipairs(reopened:groups())do group_set[g]=true end
assert(group_set['中文分组/子目录']and group_set.Control and group_set.next)
-- Saving from a stale editor must not recreate an externally moved file.
assert(not lib:metadata(id,'description','stale edit'))
local second=TEST_WORK..'/NextBuild';assert(F.mkdir(second));local imported=L.new{dir=second}
local ok,n=imported:import_folder(dir);assert(ok and n==2)
local found=false;for _,entry in ipairs(imported:list())do if entry.description=='描述更新\n保留 # 与中文'then assert(entry.group=='手动移动');found=true end end;assert(found)
for _,bad in ipairs({'../escape','CON','LPT1.txt','backup','trailing.','bad?name'})do assert(not pcall(L.group,bad),bad)end
assert(L.group('Control')=='Control');assert(not reopened:metadata(id,'description',string.rep('x',4097)))
-- Saved values, not the active editor's staged values, drive the preview and its stars.
local lang='zh-Hans';local current=999
local c={lang=function()return lang end,tr=function(v)return v end,tab_of=function(w)return w.slot end,
 navigation={{id='armory',name={'Armory','军械库','軍械庫'},subs={{name={'Weapons','武器编辑','武器編輯'},tabs={'Primary','Secondary'}},{name={'Equipment','存档配装','存檔配裝'},tabs={'CurrentLoadout'}}}},
 {id='misc',name={'Misc','杂项','雜項'},subs={{name={'Preload','预载','預載'},tabs={'PreloadCatalog','PreloadGlobal','PreloadWorld'}}}}},
 by_hash={[hash]={name='测试武器',slot='Primary',by_id={health={row={label='Health',label_of=function()return lang=='en'and'Health'or'生命值'end}}}}},
 default_value=function()return 100 end}
local payload={scope='global',values={{hash=hash,id='health',value=300},{hash='AAAAAAAAAAAAAAAA',id='unknown',value=2}},data={version=2,
 loadout={values={primary=1,secondary=3},baseline={primary=1,secondary=2}},
 preload={arrays={array={expected={1,2},values={1,3,4}}},targets={['18235E0C9EC0E636']=true},merge_enabled=true}}}
local pages=require('preset_details').build(payload,c)
local by_id={};for _,page in ipairs(pages)do for _,section in ipairs(page.sections)do by_id[section.id]=section end end
assert(by_id.Primary.rows[1].value=='300'and by_id.Primary.rows[1].baseline=='100'and by_id.Primary.rows[1].changed)
assert(by_id.Primary.rows[1].label=='生命值'and #by_id.Secondary.rows==0)
assert(by_id.CurrentLoadout.count==1 and #by_id.CurrentLoadout.rows==2)
assert(#by_id.PreloadWorld.rows==2,'array preview must list only changed and added indices on the editor array page')
assert(by_id.Unavailable.rows[1].id=='unknown','unavailable saved fields must remain visible')
assert(by_id.PreloadGlobal.count==0,'the default preload target and merge switch are not changes')
lang='en';assert(require('preset_details').build(payload,c)[1].sections[1].rows[1].label=='Health')
assert(current==999 and payload.values[1].value==300,'preview must not apply the preset')
-- The accordion exposes every main page, only changed subpages and changed fields.
c.navigation[#c.navigation+1]={id='empty',name={'Empty main page','无改动主页','無改動主頁'},subs={}}
c.ui={version=0,fpage=1,fslot=77};payload.id=77
local other={id=78,scope='global',values={},data={version=2}}
local browser=require('preset_controller').new(c)
browser.library={revision=0,list=function()return{payload,other}end}
local folded=browser.details(payload)
assert(#folded==4,'all configured main pages and the unavailable-fields page must be visible')
for _,entry in ipairs(folded)do assert(entry.kind=='page'and not entry.expanded)end
assert(not browser.toggle_detail('page','empty'),'empty main pages must not expose empty subpages')
assert(browser.toggle_detail('page','armory'));assert(browser.toggle_detail('page','misc'))
assert(browser.toggle_detail('section','armory/Primary'));assert(browser.toggle_detail('section','armory/CurrentLoadout'))
assert(browser.toggle_detail('section','misc/PreloadWorld'))
local fields,main_open=0,0
for _,entry in ipairs(browser.details(payload))do
 if entry.kind=='page'and entry.expanded then main_open=main_open+1 end
 if entry.kind=='section'then assert(entry.count>0 and entry.id~='armory/Secondary')end
 if entry.kind=='parameter'then
  assert(entry.entry.changed);assert(entry.entry.id~='primary','unchanged loadout fields must stay hidden');fields=fields+1
 end
end
assert(main_open==2 and fields==4,'multiple changed branches must be visible together')
browser.show(other.id)
for _,entry in ipairs(browser.details(other))do assert(entry.kind=='page'and not entry.expanded,'a newly selected preset must start collapsed')end
-- Regression: 20 stored entries can contain only one actual change.
local before_bridge,before_save=SHODAN_DEMOLITION_BRIDGE,SHODAN_PLAYER_SAVE_MODEL
local equipment={};for i=1,16 do equipment['field_'..i]=i end
local twenty={id=79,scope='global',values={{hash=hash,id='health',value=100000}},data={version=2,
 game={stacks={},own_off={}},demolition={values={target={['0:normal']=40,['0:hit']=40}},stale={}},
 loadout={values=equipment},preload={selected={},edits={},arrays={},targets={['18235E0C9EC0E636']=true},merge_enabled=true}}}
SHODAN_DEMOLITION_BRIDGE={panel={model={by_id={target={name='Target',hash=hash,levels={{key='0:normal',value=40},{key='0:hit',value=40}}}}}}}
SHODAN_PLAYER_SAVE_MODEL={save={},read=function(_,key)return equipment[key]end}
local epoch=0;c.detail_version=function()return epoch end
assert(browser.saved_count(twenty)==20,'reproduce the 20-entry snapshot')
assert(browser.count(twenty)==1,'unchanged demolition, equipment and default preload must not inflate the change count')
assert(browser.count(payload)==5 and browser.count(twenty)==1,'caches must remain independent across preset IDs')
SHODAN_PLAYER_SAVE_MODEL.read=function(_,key)return key=='field_1'and 0 or equipment[key]end;epoch=epoch+1
assert(browser.count(twenty)==2,'changing the loaded original save must refresh counts and detail stars together')
SHODAN_DEMOLITION_BRIDGE,SHODAN_PLAYER_SAVE_MODEL=before_bridge,before_save
print('PASS: nested Unicode folders, physical moves, description/name/overwrite/reload/import, duplicate names per group, empty groups, invalid paths; localized navigation, saved values, originals, changed stars, loadout baselines, array diffs and unavailable fields')
