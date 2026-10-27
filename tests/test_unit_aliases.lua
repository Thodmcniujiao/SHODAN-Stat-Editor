local D=require('demolition')
local A=require('unit_aliases')
local I=require('install')
local p32=D.p32
local source=D.unhex('61D9DDA22A59E9BC')
local unit=D.hash_resource('unit');local package=D.hash_resource('package')
local one,two=D.hash_resource('shodan/test/unit/one'),D.hash_resource('shodan/test/unit/two')
local original='PACK'..p32(0)..p32(1)..p32(0)..unit..source
local rewritten,count=A.patch_package(original,{[source]={one,two}})
assert(count==2 and D.u32(rewritten,8)==3)
assert(rewritten:sub(17,32)==original:sub(17,32),'original dependency changed')
assert(A.patch_package(rewritten,{[source]={one,two}})==nil,'package aliases accumulate')
local src={['09985dc611a3a8b6']={
 units={[source]={main='unit bytes',gpu='GPU bytes',stream='stream bytes'}},
 packages={[D.hash_resource('test/package')]={main=original}}}}
local requests={{entity='ONE',source_unit=D.hex(source),alias_unit=D.hex(one)},
 {entity='TWO',source_unit=D.hex(source),alias_unit=D.hex(two)}}
local writes,report=A.plan(requests,src,function(id)return id..'.patch_0'end)
assert(#report==1 and report[1].resources==3 and report[1].packages==1)
local back=A.read_archive(writes['09985dc611a3a8b6.patch_0'],writes['09985dc611a3a8b6.patch_0.gpu_resources'],writes['09985dc611a3a8b6.patch_0.stream'])
assert(back[one..unit].main=='unit bytes' and back[two..unit].gpu=='GPU bytes')
assert(back[source..unit]==nil,'original Unit should not be overwritten')
assert(not pcall(function()A.plan(requests,{['09985dc611a3a8b6']={units=src['09985dc611a3a8b6'].units,packages={}}},function(id)return id..'.patch_0'end)end))
print('PASS: alias resource archive round-trip and package dependency isolation')
if TEST_GAME then
 local work=assert(TEST_WORK,'--work is required for real asset export')
 local alias=D.hex(D.hash_resource('shodan/entity_demolition/ef85d6cf58e31d70'))
 local actual={{entity='EF85D6CF58E31D70',source_unit=D.hex(source),alias_unit=alias}}
 local out,details=A.prepare(actual,{game=TEST_GAME,cache=work..'/exports',filediver=assert(A.find_filediver(TEST_ROOT..'/offline/')),
  owned={},log=print,pump=function()return true end})
 I.mkdirs(work..'/candidate_assets');local n=0
 for name,s in pairs(out)do local f=assert(io.open(work..'/candidate_assets/'..name,'wb'));f:write(s);f:close();n=n+1 end
 print('PASS: real Gatling aliases exported and dependency-patched; '..#details..' source triads; '..n..' files; no game writes')
end
