local D=require('demolition')
local function read(p)local f=assert(io.open(p,'rb'));local s=f:read('*a');f:close();return s end
local root=assert(TEST_FIXTURES,'--fixtures must name an authenticated plaintext folder')
local es,ds,ts=read(root..'/generated_entities.dl_bin'),read(root..'/generated_destruction_settings.dl_bin'),read(root..'/dl_library.dl_typelib')
local model=D.new(es,ds,ts)
assert(D.hex(D.hash_resource('unit'))=='E0A48D0BE9A7453F')
assert(D.hex(D.hash_resource('content/fac_helldivers/hellpod/turret/gatling_turret'))=='EF85D6CF58E31D70')
local a,b='EEF85D6CF58E31D70','E7FF0FD4572F5996F'
assert(model.by_id[a].unit=='61D9DDA22A59E9BC' and model.by_id[a].shared==6)
local base=model.by_id[a].levels[1].value
local cfg={[a]={['0:normal']=999},[b]={['0:normal']=1234,['0:hit']=567}}
local out=model:build(cfg)
assert(#out.aliases==2 and out.aliases[1].alias_unit~=out.aliases[2].alias_unit)
local re=D.new(out.entities,out.destruction,ts)
local function value(t,key)for _,l in ipairs(t.levels)do if l.key==key then return l.value end end end
assert(value(re.by_id[a],'0:normal')==999 and value(re.by_id[b],'0:normal')==1234)
assert(value(re.by_id[b],'0:hit')==567)
assert(re.data.templates[4].bytes==model.data.templates[4].bytes)
assert(re.data.mapping[D.unhex('61D9DDA22A59E9BC')]==1296)
for _,hex in ipairs(model.unit_users[D.unhex('61D9DDA22A59E9BC')])do
    if 'E'..hex~=a and 'E'..hex~=b then
        assert(re.by_id['E'..hex].unit=='61D9DDA22A59E9BC')
        assert(value(re.by_id['E'..hex],'0:normal')==base)
    end
end
-- All other entity bytes are preserved, not just their selected fields.
local spans={}
for _,id in ipairs({a,b})do local o=model.by_id[id].record.offset;for i=o,o+7 do spans[i+1]=true end end
for i=1,#es do if not spans[i]then assert(es:byte(i)==out.entities:byte(i),'unrelated entity data changed')end end
local again=model:build(cfg)
assert(again.entities==out.entities and again.destruction==out.destruction,'build accumulates private records')
assert(model:build({}).entities==es)
assert(not pcall(function()model:build({[a]={['0:normal']=-1}})end))
assert(not pcall(function()model:build({[a]={['0:normal']=1.5}})end))
assert(not pcall(function()model:build({[a]={['99:normal']=1}})end))
local bounds=model:build({[a]={['0:normal']=0,['0:hit']=4294967295}})
local br=D.new(bounds.entities,bounds.destruction,ts)
assert(value(br.by_id[a],'0:normal')==0 and value(br.by_id[a],'0:hit')==4294967295)
local many={};local count=0
for _,t in ipairs(model.targets)do
    if not t.why and #t.levels>0 then
        count=count+1;many[t.id]={[t.levels[1].key]=1000+count}
    end
end
local all=model:build(many)
local ar=D.new(all.entities,all.destruction,ts)
for id,values in pairs(many)do for key,v in pairs(values)do assert(value(ar.by_id[id],key)==v)end end
print(string.format('PASS: %d targets catalogued; %d independent overrides round-tripped; shared templates unchanged',#model.targets,count))
