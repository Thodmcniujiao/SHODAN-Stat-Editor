local D=require('demolition');local P=require('demolition_panel');local B=require('demolition_bridge');local I=require('install')
local function read(path)local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s end
assert(I.home:gsub('\\','/'):sub(1,#TEST_WORK)==TEST_WORK,'use an isolated profile')
I.mkdirs(I.home)
local model=D.new(read(TEST_FIXTURES..'/generated_entities.dl_bin'),read(TEST_FIXTURES..'/generated_destruction_settings.dl_bin'),read(TEST_FIXTURES..'/dl_library.dl_typelib'))
local enabled,changes=true,0
local path=I.home..'/entity_demolition.txt'
local panel=P.new(model,{path=path,enabled=function()return enabled end,changed=function()changes=changes+1 end})
local bridge=B.new(panel,{config_path=I.home..'/config.txt'})
local a,b=model.by_id.EEF85D6CF58E31D70,model.by_id.E7FF0FD4572F5996F
assert(a.unit==b.unit)
local af,bf=bridge:rows(a.entity_key)[1].field,bridge:rows(b.entity_key)[1].field
assert(af~=bf and af.key~=bf.key,'sharing a Unit must not share authoring fields')
assert(bridge:write(af,20));assert(bridge:read(af)==20 and bridge:read(bf)==bf.level.value)
local count=changes;assert(bridge:write(af,20));assert(changes==count,'a duplicate write should not resave')
enabled=false;assert(bridge:read(af)==af.level.value and bridge:own(af)==20)
assert(not bridge:write(af,21));assert(bridge:own(af)==20);enabled=true
assert(bridge:migrate({{field=af,value=10},{field=bf,value=73}}))
assert(bridge:own(af)==20 and bridge:own(bf)==73,'canonical wins; legacy-only values migrate')
assert(read(bridge.migration_backup..'/entity_demolition.txt'):find('0:normal 20',1,true))
assert(read(bridge.migration_backup..'/migration.txt'):find('kept canonical',1,true))
local canonical=read(path)
assert(bridge:migrate({{field=bf,value=4294967296}})) -- existing valid slot wins this conflict
-- The previous slot exists, so an invalid losing legacy value cannot poison a valid canonical value.
assert(read(path)==canonical)
local save=D.save_overrides
D.save_overrides=function()return nil,'injected save failure'end
count=changes
assert(not bridge:write(af,999));assert(bridge:own(af)==20 and changes==count and read(path)==canonical)
assert(not bridge:write(af,nil));assert(bridge:own(af)==20)
assert(not bridge:clear());assert(bridge:own(af)==20 and bridge:own(bf)==73)
assert(not bridge:migrate({{field=bf,value=74}}));assert(bridge:own(bf)==73)
D.save_overrides=save
assert(bridge:clear()and not next(panel.values))
assert(not bridge:migrate({{field=bf,value=4294967296}}));assert(not next(panel.values))
print('PASS: distinct fields for shared Units, canonical migration priority, legacy-only import, settings switch, backups and save-failure rollback')
