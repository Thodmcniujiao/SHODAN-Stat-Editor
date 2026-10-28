local D=require('demolition')
local function r(n)local f=assert(io.open(TEST_FIXTURES..'/'..n,'rb'));local s=f:read('*a');f:close();return s end
local d=D.parse_destruction(r('generated_destruction_settings.dl_bin'))
local bad,total=0,0
for key in pairs(d.mapping)do
 total=total+1;local at=D.u32(key,0)%d.capacity;local seen=0
 while d.buckets[at] and d.buckets[at]~=key and seen<d.capacity do at=(at+1)%d.capacity;seen=seen+1 end
 if d.buckets[at]~=key then bad=bad+1 end
end
print('native map linear-probe check',total,bad)
assert(bad==0)
