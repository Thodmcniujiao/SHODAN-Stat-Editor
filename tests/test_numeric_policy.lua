local N=require('numeric_policy')
for _,case in ipairs({{'u8',0,255},{'i8',-128,127},{'u16',0,65535},{'i16',-32768,32767},
 {'u32',0,4294967295},{'i32',-2147483648,2147483647},{'flag',0,1},
 {'bits1_2_3',0,7},{'bit5',0,1},{'f32',-N.F32_MAX,N.F32_MAX}})do
 local f={storage=case[1]};local lo,hi=N.bounds(f);assert(lo==case[2]and hi==case[3],case[1])
 assert(N.validate(f,lo)==lo and N.validate(f,hi)==hi,case[1])
 assert(not N.validate(f,lo<0 and lo*2 or-1));assert(not N.validate(f,hi*2+1))
end
for _,v in ipairs({math.huge,-math.huge,0/0})do assert(not N.validate({storage='f32'},v))end
local f={storage='u32',limit=100,most=10,allowed={[1]=true}}
local a={storage='u32',min=1,max=100,parts={{field=f}}}
local b={storage='u32',min=0,max=10000000,parts={{field=f}}}
N.row(a);N.row(b);assert(a.min==b.min and a.max==4294967295 and a.max==b.max)
assert(N.validate(f,4294967295)==4294967295)
local float={storage='f32',signed=false,limit=1}
assert(N.validate(float,-1e30));assert(N.validate(float,1e-30)~=0)
assert(tonumber(N.input({storage='f32'},N.validate(float,1e-30)))==N.validate(float,1e-30))
assert(N.accept({hash64=true},'x')and N.accept({hash64=true},'F'))
assert(N.accept({},'e')and N.accept({},'+'))
local meta={schemas={[1]={members={{},{offset=32,size=32,atom=2,storage=20,type=2}}},
 [2]={size=16,members={{offset=0,size=4,storage=2},{offset=4,size=12,storage=20,atom=2,count=3,type=3}}},
 [3]={size=4,members={{offset=0,size=4,storage=6}}}}}
assert(N.storage(meta,1,32,'u32')=='i32'and N.storage(meta,1,48,'u32')=='i32')
assert(N.storage(meta,1,36,'i32')=='u32'and N.storage(meta,1,44,'i32')=='u32')
assert(N.storage(meta,1,32,'gun')=='gun'and N.storage(meta,1,32,'flag')=='flag')
print('PASS: storage-only integer/float/bool/bit limits, shared-row consistency, finite checks, tiny float precision and hex/scientific input')
