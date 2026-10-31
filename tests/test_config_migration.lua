-- Run the real config loader, retry queue and serializer against isolated fields.
assert(TEST_WORK and SHODAN_DATA_DIRECTORY, 'use --isolated-profile --work <directory>')
local I=require('install'); I.mkdirs(I.home)
SHODAN_OFFLINE=true; SHODAN_OFFLINE_LANG='en'
stingray=require('engine_shim').engine(); update=function()end
local hash='0000000000000001'
local function write(s)local f=assert(io.open(I.home..'/config.txt','wb'));assert(f:write(s));f:close()end
write('changes on\ncache_clear_on_exit off\n'..hash..' capacity 99\n'..hash..' unrelated 7\n')
local file=assert(io.open(TEST_ROOT..'/src/stat_editor_offline.lua','rb'))
local source=file:read('*a');file:close()
source=source..[[
TEST_MIGRATION={by_hash=by_hash,state=state,settings=settings,MOD=MOD,
 apply=apply_config,save=save_config,set=set_override,default=default_of,write=write_field,
 values=function()return overrides end,
 queue=function()
   pending,apply_at={},1
   for _,o in ipairs(overrides)do pending[#pending+1]={hash=o.hash,id=o.id,value=o.value}end
 end,
 reload=function()overrides={};load_config()end}
]]
assert(loadstring(source,'@'..TEST_ROOT..'/src/stat_editor_offline.lua'))()
local E=assert(TEST_MIGRATION)
local w={hash=hash,name='Migration fixture',by_id={},legacy={capacity={'itemA_capacity','itemB_capacity'}}}
E.by_hash[hash]=w
local function part(id,baseline,installed)
 local p={id=id,field={key='fixture:'..id,storage='virtual',default=baseline,installed_value=installed}}
 w.by_id[id]=p;return p
end
local a,b,other=part('itemA_capacity',30,80),part('itemB_capacity',45),part('unrelated',1)
E.queue();assert(E.apply())
assert(E.state.applied==2 and E.state.refused==0)
assert(a.field.value==99 and b.field.value==99 and other.field.value==7)
local function values()
 local out={};for _,o in ipairs(E.values())do assert(not out[o.id],'duplicate override');out[o.id]=o.value end;return out
end
local v=values();assert(not v.capacity and v.itemA_capacity==99 and v.itemB_capacity==99 and v.unrelated==7)
assert(E.save());local migrated=assert(I.read(I.home..'/config.txt'))
assert(not migrated:find(' capacity ',1,true) and migrated:find(' itemA_capacity 99',1,true))
-- Restart/reapply uses only new ids, and an expired deadline resumes without losing entries.
a.field.value,b.field.value,other.field.value=nil,nil,nil
E.reload();E.queue()
while not E.apply(-1)do end
assert(a.field.value==99 and b.field.value==99 and other.field.value==7)
assert(E.save() and I.read(I.home..'/config.txt')==migrated,'migration is not idempotent')
-- Removing an id-only entry never removes unrelated unresolved ids with nil fields.
w.by_id.unresolved={id='unresolved'}
write('changes on\n'..hash..' capacity 99\n'..hash..' unresolved 4\n')
E.reload();E.set(w,{id='capacity'},nil)
v=values();assert(not v.capacity and v.unresolved==4)
assert(not pcall(E.set,w,{id='invalid'},1),'fieldless writes must fail explicitly')
-- Reset retains the vanilla baseline even when a different value is already installed.
E.set(w,a,nil);v=values();assert(v.itemA_capacity==30 and v.unresolved==4)
assert(E.write(a.field,80));E.set(w,a,80)
local installed;for _,o in ipairs(E.values())do if o.id==a.id then installed=o.installed end end
assert(installed==true)
-- Shared fields still deduplicate overrides; a baseline value removes ordinary overrides.
w.by_id.alias={id='alias',field=b.field}
E.set(w,b,99);E.set(w,w.by_id.alias,88)
v=values();assert(not v.itemB_capacity and v.alias==88)
E.set(w,w.by_id.alias,nil);assert(not values().alias)
print('PASS: legacy config migration, multiple attachments, save/reload, yielding, id-only deletion, installed reset and shared-field deduplication')
