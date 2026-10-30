-- Current game tables are read only; profile, snapshots and rendered output are isolated.
local live=assert(io.open(TEST_GAME..'/generated_entities.dl_bin','rb'));local live_entity=live:read('*a');live:close()
TEST_LIVE_ENTITY=live_entity
local f=assert(io.open(TEST_ROOT..'/tests/test_editor_demolition_sync.lua','rb'))
local bootstrap=f:read('*a'):gsub('\r\n','\n');f:close()
local start=assert(bootstrap:match('^(.-)local weapon=assert'))
start=start:gsub('SHODAN_DEMOLITION_BRIDGE=bridge','SHODAN_DEMOLITION_BRIDGE=bridge;SHODAN_COMPONENT_CATALOG_SOURCE=model',1)
start=start:gsub('MOD=MOD,','MOD=MOD,tables=tables,',1)
start=start:gsub('assert%(#H.load%(TEST_GAME,original%)==0%)',[[
for _,name in ipairs({'generated_projectile_settings.dl_bin','generated_stratagem_settings.dl_bin',
 'generated_damage_settings.dl_bin','generated_explosion_settings.dl_bin','generated_status_effect_settings.dl_bin',
 'generated_arc_settings.dl_bin','generated_beam_settings.dl_bin'})do original[name]=read(TEST_GAME..'/'..name)end
local problems=H.load(TEST_GAME,original);assert(#problems==0,table.concat(problems,'; '))
]],1)

local old="write(I.home..'/config.txt','changes on\\nlang en\\n'..hash..' unit_demolition 10\\n')"
local at=assert(start:find(old,1,true),'bootstrap config seed missing')
start=start:sub(1,at-1).."write(I.home..'/config.txt',read(TEST_WORK..'/saved_config.txt'))"..start:sub(at+#old)

assert(loadstring(start..[==[
local p=require('json_data').decode(read(TEST_WORK..'/saved_probe.json'))
local page=assert(E.by_hash[p.hash],'canonical entity component page missing after restart')
if page.ensure_rows then page.ensure_rows()end
local part=assert(page.by_id[p.id],'saved component field missing after restart')
assert(math.abs(E.row_value(part.row)-p.value)<.001,'saved ECS value was not restored on a fresh startup')
local staged=H.diff();assert(#staged==1 and staged[1].name=='generated_entities.dl_bin','only the edited entity blob should be staged in private memory')
assert(read(TEST_GAME..'/generated_entities.dl_bin')==TEST_LIVE_ENTITY,'config reload must not write the installed game file')
gdi.DeleteDC(S.dc)
print('PASS: saved canonical entity-component config is restored on fresh editor startup')
]==],'@stratagem-editor-reload'))()
