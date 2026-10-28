-- Exercise direct discovery, yielding, rescans and failure handling without game files.
assert(TEST_WORK and os.getenv('LOCALAPPDATA'):match('[/\\]profile%-root$'),
    'run with --isolated-profile --work <temporary directory>')
local ffi = require('ffi')
local I = require('install'); I.mkdirs(os.getenv('LOCALAPPDATA'))
SHODAN_OFFLINE = true
stingray = require('engine_shim').engine()
update = function() end
local function u32(n)
    return string.char(n%256,math.floor(n/256)%256,math.floor(n/65536)%256,math.floor(n/16777216)%256)
end
local DAMAGE = 0xE0A72CF0
local function buffer(id)
    local payload = string.rep('\0',8)..u32(1)..u32(0)..u32(id)..string.rep('\0',72)
    local text = 'LDLD\1\0\0\0'..u32(DAMAGE)..u32(#payload)..'\1'..string.rep('\0',7)..payload
    local p = ffi.new('uint8_t[?]',#text); ffi.copy(p,text,#text)
    return p,{address=tonumber(ffi.cast('uintptr_t',p)),kind=DAMAGE,payload=#payload}
end
local p,a = buffer(42)
local q,b = buffer(42)
local r,c = buffer(99)
local source = {a,b,a,{address=a.address,kind=0x12345678,payload=16}}
local calls = 0
SHODAN_OFFLINE_TABLES = function() calls=calls+1; return source end
SHODAN_OFFLINE_TABLE_ADDRESS = function(address)
    return address==a.address or address==b.address or address==c.address
end
local f=assert(io.open(TEST_ROOT..'/src/stat_editor_offline.lua','rb'))
local text=f:read('*a');f:close()
text=text..[[
TEST_TABLES={state=state,api=api,hub=hub,tables=function()return tables end,rescan=rescan,
    job=BUS.jobs[MOD.global],start_frame=START_FRAME,budget=FRAME_BUDGET}
]]
assert(loadstring(text,'@'..TEST_ROOT..'/src/stat_editor_offline.lua'))()
local E=assert(TEST_TABLES)
assert(E.state.offline_direct and not E.hub,'offline host must bypass the shared scanner')
assert(E.start_frame==1 and E.budget==.004)
E.api.allocation=function()error('direct discovery tried to enumerate process memory')end
-- An expired budget must yield after one descriptor instead of parsing the whole list.
E.state.read_offline_tables(E.api.now()-1)
assert(E.state.phase=='searching' and E.state.offline_scan.next==2)
assert(E.tables()[DAMAGE].entries==1 and E.tables()[DAMAGE].index[42]==16)
while E.state.phase=='searching' do E.state.read_offline_tables(E.api.now()-1) end
assert(E.state.phase=='building' and calls==1)
assert(#E.tables()[DAMAGE].copies==2,'duplicate headers must not become duplicate copies')
assert(E.state.offline_table_count==4 and not E.state.offline_scan)
-- A rescan must ask the host again and use its new buffers and index.
source={c}; E.rescan()
E.state.read_offline_tables(E.api.now()+1)
assert(calls==2 and E.state.phase=='building')
assert(E.tables()[DAMAGE].index[99]==16 and not E.tables()[DAMAGE].index[42])
assert(E.tables()[DAMAGE].copies[1]==c.address)
-- A changed header must stop initialization and must not be retried on later frames.
r[0]=0; E.rescan(); E.job()
assert(E.state.phase=='gave_up' and E.state.failure:find('header changed',1,true))
assert(not E.state.offline_scan)
local before=calls
for _=1,100 do E.job() end
assert(calls==before)
-- Even with a host provider present, the in-game path keeps its original scanner and budget.
SHODAN_OFFLINE=nil
ShodanStatEditor=nil
CowboyBingusModLoader={api=1}
assert(loadstring(text,'@'..TEST_ROOT..'/src/stat_editor_offline.lua'))()
assert(not TEST_TABLES.state.offline_direct and TEST_TABLES.hub)
assert(TEST_TABLES.start_frame==120 and TEST_TABLES.budget==.0007)
print('PASS: direct parsing, per-batch yield, duplicate suppression, fresh-buffer rescans, header failure and unchanged in-game scanner')
