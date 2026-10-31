local G=require('galactic_effects')
local J=require('json_data')
local files,fail={},false
local fs={read=function(p)return files[p]end,mkdir=function()return true end,
 write=function(p,v)files[p]=v;return true end,
 move=function(a,b)if fail then return nil,'simulated disk failure'end;files[b]=files[a];files[a]=nil;return true end,
 remove=function(p)files[p]=nil end}
local function model()return G.new{folder='portable/Data',fs=fs}end
local m=model();assert(not m.error and not m.cfg.enabled)
local four,previous=0,0
for _,e in ipairs(G.data.effects)do
 local b=e.definition;assert(b.id>previous);previous=b.id
 if b.id>=1000 and b.id<10000 then four=four+1 end
 for _,key in ipairs(G.fields)do assert(G.valid(key,b[key]),key)end
end
assert(#G.data.effects==312 and four==290)
assert(m.roles[1202].kind=='effect'and m.roles[1202].other==1203)
assert(m.roles[1203].kind=='icon'and m.roles[1203].other==1202)
assert(m.roles[1307].other==1308 and not m.roles[1373]) -- type 71 alone is not an icon
local count=0;for _ in pairs(m.roles)do count=count+1 end;assert(count==26)
local changed=J.decode(J.encode(G.data));for _,e in ipairs(changed.effects)do if e.definition.id==1203 then e.definition.effectType=40 end end
local _,roles=G.index(changed);assert(not roles[1202]and not roles[1203])
local original=J.encode(m:read(1202,'values'))
assert(m:set(1202,'values',J.array{2313485354,0}));assert(m:changed(1202)and not m:enabled(1202))
assert(m:set(1202,'enabled',true));assert(m:master(true))
m=model();assert(m.cfg.enabled and m:enabled(1202));assert(m:read(1202,'values')[1]==2313485354)
assert(J.encode(m:read(1202,'values',true))==original)
assert(J.encode(m:read(1203,'values'))==J.encode(m.catalog[1203].definition.values))
assert(not m:set(1202,'id',1203));assert(not m:set(1202,'effectType',-1));assert(not m:set(1202,'flags',1.5))
assert(not m:set(1202,'flags',4294967296));assert(not m:set(1202,'values',{0/0}));assert(not m:set(1202,'values',{math.huge}))
assert(not m:set(1202,'values',{}));assert(not m:set(1202,'valueTypes',J.array{-1,0}))
assert(m:set(1202,'values',J.array{-1e100,1e100})) -- wire JSON, no invented slider bound
local before=files[m.path];local old=J.encode(m.cfg);fail=true
assert(not m:set(1202,'flags',3));assert(J.encode(m.cfg)==old and files[m.path]==before)
fail=false;assert(m:reset(1202));assert(not m:changed(1202)and m.cfg.enabled)
assert(m:set(1202,'values',J.array{0,0}));assert(m:reset(1202,'values'));assert(not m:changed(1202))
local stale={version=1,enabled=true,effects={['1202']={enabled=true,base={id=1202},changes={values=J.array{0,0}}}}}
files[m.path]=J.encode(stale);m=model();assert(m.stale['1202']and not m:enabled(1202))
assert(not m:set(1202,'flags',2));assert(J.encode(m:read(1202,'values'))==original)
assert(m:reset(1202));assert(not m.stale['1202']);assert(m:set(1202,'flags',2))
files[m.path]='{ broken';m=model();assert(m.error);assert(not m:master(true));assert(files[m.path]=='{ broken')
print('PASS 312 effect definitions / 290 four-digit IDs; explicit icon pairs; portable authoring, stale guard and atomic rollback')
