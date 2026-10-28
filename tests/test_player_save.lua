-- Real codec + file transactions against an in-memory filesystem. The live save is read only.
local S=require('player_save');local D=require('demolition');local I=require('install')
local fixture=assert(os.getenv('SHODAN_PLAYER_SAVE_FIXTURE'),'fixture path required')
local f=assert(io.open(fixture,'rb'));local original=f:read('*a');f:close()
local save=S.decode(original)
assert(S.crc32('123456789')==0xCBF43926)
assert(S.encode(save,save.data)==original,'no-op must be byte-identical')
for _,data in ipairs({'',string.rep('a',65536),string.rep('abcd',16384),
 (function()local a={};for i=0,65535 do a[#a+1]=string.char((i*137+math.floor(i/257))%256)end;return table.concat(a)end)()})do
 assert(S.inflate(S.deflate(data))==data,'LZ4 round trip differs')
end
assert(not pcall(S.decode,original:sub(1,50)),'truncated save accepted')
assert(not pcall(S.decode,original:sub(1,100)..string.char((original:byte(101)+1)%256)..original:sub(102)),'CRC damage accepted')
assert(not pcall(S.inflate,string.char(0,0,0)),'zero-distance LZ4 accepted')
assert(not pcall(S.inflate,string.char(0xf0,255)),'unterminated literal length accepted')
local cat={categories={},by_id={}}
for _,field in ipairs(S.FIELDS)do if field.category then
 local id=D.u32(save.data,field.offset);cat.categories[field.category]={[id]={id=id,category=field.category,name='Existing item'},[42]={id=42,category=field.category,name='Replacement item'}}
end end
local files={['save.sav']=original};local running,move_failure,write_failure=false,false,false
local writes,moves=0,0
local io_mock={read=function(p)return files[p]end,write=function(p,s)
 if write_failure then return nil,'write failure'end;writes=writes+1;files[p]=s;return true end,
 running=function()return running end,remove=function(p)files[p]=nil end,
 move=function(a,b)if move_failure then return nil,'move failure'end;moves=moves+1;files[b]=files[a];files[a]=nil;return true end}
local function model()return S.new{io=io_mock,catalog=cat,paths={'save.sav'},preset_path='presets.json'}end
local m=model();assert(m.save and m:count()==0 and writes==0 and moves==0,'load wrote files')
assert(not m:set('primary',43),'wrong-slot ID accepted')
assert(not m:set('unknown_11d',-1));assert(not m:set('unknown_11d',4294967296))
assert(S.integer('0xFFFFFFFF')==4294967295 and S.integer('4294967295')==4294967295)
assert(not S.integer('1e8')and not S.integer('1.1'))
assert(m:set('primary',42));assert(m:read('primary')==42 and files['save.sav']==original,'staging wrote live save')
local candidate=m:prepare();assert(files['save.sav']==original)
local decoded=S.decode(candidate)
for i=1,#save.data do
 if i<0x12 or i>0x15 then assert(decoded.data:byte(i)==save.data:byte(i),'unrelated byte changed at '..i)end
end
for i=2,#save.chunks do assert(save.chunks[i].compressed==decoded.chunks[i].compressed,'unchanged chunk recompressed')end
running=true;assert(not m:commit()and files['save.sav']==original);running=false
files['save.sav']=original..'x';assert(not m:commit(),'external change was overwritten');files['save.sav']=original
write_failure=true;assert(not m:commit()and files['save.sav']==original);write_failure=false
move_failure=true;assert(not m:commit()and files['save.sav']==original);move_failure=false
assert(m:commit()and S.decode(files['save.sav']).data==decoded.data)
assert(files[m.backup]==original and m:count()==0,'backup is not exact original')
assert(m:set('primary',42));assert(m:preset('save',1));local preset_raw=files['presets.json']
assert(preset_raw and #preset_raw>10)
local m2=model();assert(m2:preset('load',1)and m2:read('primary')==42,'persistent preset failed')
assert(m2:preset('clear',1));assert(not m2:preset('load',1))
assert(m:restore()and files['save.sav']==original,'restore did not preserve exact original bytes')
-- Six edits, all by whitelist; high unsigned values are represented exactly.
m=model();for _,field in ipairs(S.FIELDS)do if field.category then assert(m:set(field.key,42))end end
assert(m:set('unknown_11d',4294967295))
assert(D.u32(S.decode(m:prepare()).data,0x11d)==4294967295)
local named_snapshot=assert(m:snapshot());assert(named_snapshot.values.unknown_11d==4294967295)
assert(m:reset());assert(m:apply_snapshot(named_snapshot));assert(m:read('primary')==42 and m:read('unknown_11d')==4294967295)
local before_bad=m:prepare();named_snapshot.values.primary=43
assert(not m:apply_snapshot(named_snapshot)and m:prepare()==before_bad,'invalid named loadout was partially applied')
assert(files['save.sav']==original)
-- The native row builder and browser actions share the same staged model.
SHODAN_PLAYER_SAVE_MODEL=m
local View=require('player_save_view');local c={weapons={},by_hash={},kit_names={},tr=function(s)return s end,lang=function()return'zh-Hans'end}
local pages=View.build(c);assert(#pages==4 and #c.weapons==4)
local main=pages[1];local primary
for _,row in ipairs(main.rows)do if row.id=='primary'then primary=row end end
assert(primary and primary.custom_edit('42')and m:read('primary')==42 and primary.custom_text()=='Replacement item')
assert(primary.custom_reset()and m:read('primary')==m:read('primary',true))
assert(not primary.custom_edit('43'),'UI bypassed category validation')
assert(pages[4].rows[1].custom_edit('0xFFFFFFFF'))
assert(#View.list('CurrentLoadout')==4)
View.build(c);assert(#c.weapons==4,'rescan duplicated save pages')
I.mkdirs(TEST_WORK)
local out=assert(io.open(TEST_WORK..'/edited-save.sav','wb'));out:write(candidate);out:close()
-- Exercise the production Windows file adapter only inside the isolated work directory.
local IO=require('player_save_io');local adapter=IO.new();adapter.running=function()return false end
local isolated=TEST_WORK..'/transaction-fixture.sav';assert(adapter.write(isolated,original))
local disk=S.new{io=adapter,catalog=cat,paths={isolated}}
assert(disk:set('primary',42)and disk:commit())
assert(S.decode(adapter.read(isolated)).data==decoded.data and adapter.read(disk.backup)==original)
assert(disk:restore()and adapter.read(isolated)==original)
local detected=IO.discover(TEST_GAME);local matched=false
for _,path in ipairs(detected)do if path:gsub('\\','/'):lower()==fixture:gsub('\\','/'):lower()then matched=true end end
assert(matched,'Steam userdata save discovery failed')
local src=assert(io.open(fixture,'rb'));assert(src:read('*a')==original);src:close()
print('PASS: real save CRC/LZ4/no-op; staged six-slot edit; untouched bytes/chunks; malformed data; category/u32 validation; write/move/running/conflict failures; exact backup/restore; persistent presets; native rows/catalog/rescan; live fixture unchanged')
