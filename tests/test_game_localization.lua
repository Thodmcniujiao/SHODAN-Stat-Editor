local L=require('game_localization');local data=L.data
local G=require('galactic_effect_data');local P=require('planet_effect_data')
assert(data.coverage.local_records==438 and data.coverage.api_planets==273)
assert(data.coverage.planet_texts.zhs==389 and data.coverage.planet_texts.zht==389)
assert(L.planet('planet_002').zhs=='开拓者V'and L.planet('planet_002').zht=='探路者V')
assert(L.planet('planet_175').zhs=='艾拉特主星')
assert(L.planet('planet_269').zhs=='大流散X')
assert(L.planet('planet_022').zhs=='正义堡','API index was confused with debug suffix')
assert(not L.planet('planet_homeworld_superearth'),'ambiguous debug name guessed a title')
assert(L.planet('planet_homeworld_superearth',3965403289).zhs=='普罗维登斯')
assert(not L.planet('planet_homeworld_superearth',437720334),'unknown duplicate borrowed another record title')
assert(L.planet_index(22,160106209).zhs=='泽格马乐土')
assert(L.planet_index(22,160106209).zht=='澤蓋瑪天堂')
assert(not L.planet_index(22,1257502272),'mismatched API settingsHash was accepted')
for _,p in ipairs(P.planets)do
 local n=assert(L.planet_index(p.index,p.settingsHash),'missing API planet '..p.index)
 assert(n.zhs and n.zht and n.en and n.index==p.index)
 assert(n.zhs==L.lookup(n.name_hash,'zh-Hans'),'missing Chinese text was silently guessed')
end
local ids={};local resolved=0
for _,entry in ipairs(G.effects)do
 ids[entry.definition.id]=entry
 for lang,locale in pairs({en='en',zhs='zh-Hans',zht='zh-Hant'})do
  for field,ref in pairs(entry.text_provenance[lang])do
   local text=assert(L.effect_text(entry,field,locale))
   assert(text==assert(data.strings[lang][tostring(ref.hash)]),'title/description did not match exact text hash')
  end
 end
 if entry.name_zh then resolved=resolved+1 end
end
assert(resolved==171)
assert(ids[1373].name_zh=='1级异界风暴')
assert(ids[1373].name_zht~=ids[1373].name_zh,'Traditional reused Simplified')
assert(ids[1373].text_provenance.zhs.name.hash==505181551)
assert(ids[1373].text_provenance.zhs.description.hash==4210400742)
assert(ids[1373].unresolved_text_hashes.zhs.nameHash==2399106303)
assert(ids[1202].text_provenance.zhs.name.source=='paired_icon')
assert(ids[1202].text_provenance.zhs.name.paired_id==1203)
assert(ids[1202].definition.id~=ids[1203].definition.id)
assert(ids[1202].definition.values[1]==2922304745 and ids[1203].definition.values[1]==1045188094)
assert(ids[1182].name_zh=='制霸高空')
assert(not ids[1191].name_zh and ids[1191].unresolved_text_hashes.zhs.nameHash)
local old=rawget(_G,'SHODAN_TEXTS')
SHODAN_TEXTS={localized={zhs={[505181551]='实时游戏原文'}}}
assert(L.effect_text(ids[1373],'name','zh-Hans')=='实时游戏原文')
SHODAN_TEXTS=old
if TEST_GAME then
 require('portable_io_guard')
 local I=require('install');I.mkdirs(TEST_WORK)
 local options={languages={[0x5942CCF7]='zhs',[0x9EBA952A]='zht'},ids=L.required_ids()}
 local t=require('game_texts').load(TEST_GAME..'/data',TEST_WORK..'/strings-index.bin','localization-test',
  function(dir,pattern)return I.list_files(dir,pattern)end,nil,options)
 local count=0
 for lang,strings in pairs(data.strings)do
  local actual=lang=='en'and t.english or t.localized[lang]
  for hash,text in pairs(strings)do assert(actual[tonumber(hash)]==text,'native text mismatch '..lang..':'..hash);count=count+1 end
 end
 assert(t.english[505181551]=='CLASS 1 EXOSTORM'and #t.files>=250)
 -- Existing all-language string patching stays independent of the read filter.
 local f=t.files[1];local entry=t.store:directory(f.archive).by[f.key]
 local bytes=t.store:read(f.archive,entry.main[1],entry.main[2]);local T=require('game_texts')
 local first=T.texts_of(bytes)[1];local changed=assert(T.rewrite(bytes,{[first[1]]='text rewrite check'}))
 assert(T.texts_of(changed)[1][2]=='text rewrite check')
 print('PASS exact installed text comparison:',count,'translations; string rewrite unchanged')
end
print('PASS native localization: 273 API planets, duplicate/debug identity safety, independent Chinese locales, 171 effect titles with exact provenance and honest gaps')
