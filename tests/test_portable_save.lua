-- Synthetic valid two-chunk save; production codec/transactions never touch a live save.
assert(TEST_WORK and SHODAN_DATA_DIRECTORY,'use --isolated-profile --work <directory>')
local app=os.getenv('SHODAN_TEST_APP')
if app then package.path=app..'/?.lua;'..package.path;SHODAN_DATA_DIRECTORY=nil;SHODAN_PRESET_DIRECTORY=nil end
local S=require('player_save');local D=require('demolition');local I=require('install');local IO=require('player_save_io')
require('portable_io_guard')
local function put(s,at,bytes)return s:sub(1,at)..bytes..s:sub(at+#bytes+1)end
local bytes={};for i=1,100000 do bytes[i]=string.char((i*137+math.floor(i/257))%256)end
local data=put(table.concat(bytes),0,D.p32(0x107))
for _,field in ipairs(S.FIELDS)do if field.category then data=put(data,field.offset,D.p32(1))end end
local padded=data..string.rep('\0',131072-#data);local chunks={}
for at=1,#padded,65536 do local compressed=S.deflate(padded:sub(at,at+65535));chunks[#chunks+1]=D.p32(#compressed)..compressed end
local raw=string.char(0xD4,0xFD,0x1C,0x6B,0x5F,0x7B,0x23,0xCC)..D.p32(1)..D.p32(0)..D.p32(0)..D.p32(#data)..D.p32(0xF0000001)..D.p32(#data)..D.p32(0)..table.concat(chunks)
raw=put(raw,16,D.p32(#raw-28));raw=put(raw,12,D.p32(S.crc32(raw:sub(17))))
assert(S.decode(raw).data==data)
local steam=TEST_WORK..'/Steam'
TEST_GAME=steam..'/steamapps/common/Helldivers 2/data/game'
TEST_PLAYER_SAVE_FIXTURE=steam..'/userdata/123/553850/remote/testament_new.sav'
I.mkdirs(steam..'/userdata/123/553850/remote');assert(IO.write(TEST_PLAYER_SAVE_FIXTURE,raw))
assert(loadfile(TEST_ROOT..'/tests/test_player_save.lua'))()
-- Numeric collision suffixes remain ordered after ten writes in one second.
local adapter=IO.new();local ranked=TEST_WORK..'/rank-fixture.sav'
local prefix=adapter.backup_prefix(ranked,'backup')..'-20000101-010101'
assert(adapter.write(prefix..'-9',raw)and adapter.write(prefix..'-10',raw))
assert(adapter.latest_backup(ranked)==prefix..'-10')
-- Partial temporary writes on either operation must be removed, with the target intact.
local catalog={categories={},by_id={}}
for _,field in ipairs(S.FIELDS)do if field.category then catalog.categories[field.category]={[1]={id=1},[42]={id=42}}end end
local target=TEST_WORK..'/partial-fixture.sav';assert(adapter.write(target,raw));adapter.running=function()return false end
local m=S.new{io=adapter,catalog=catalog,paths={target}};assert(m:set('primary',42))
local real_write=adapter.write
adapter.write=function(path,content)
 if path:match('%.shodan%-tmp$')then real_write(path,'partial');return nil,'injected partial write'end
 return real_write(path,content)
end
assert(not m:commit()and adapter.read(target)==raw and not adapter.read(target..'.shodan-tmp'))
adapter.write=real_write;assert(m:commit());local edited=assert(adapter.read(target))
adapter.write=function(path,content)
 if path:match('%.shodan%-tmp$')then real_write(path,'partial');return nil,'injected partial restore'end
 return real_write(path,content)
end
assert(not m:restore()and adapter.read(target)==edited and not adapter.read(target..'.shodan-tmp'))
print('PASS: portable save backups, account/relocation identity, collision ordering, and partial temporary-write cleanup')
