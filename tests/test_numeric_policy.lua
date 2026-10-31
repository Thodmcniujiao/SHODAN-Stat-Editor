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
assert(N.validate(float,tonumber(N.input({storage='f32'},N.validate(float,1e-30))))==N.validate(float,1e-30))
assert(N.accept({hash64=true},'x')and N.accept({hash64=true},'F'))
assert(N.accept({},'e')and N.accept({},'+'))
local meta={schemas={[1]={members={{},{offset=32,size=32,atom=2,storage=20,type=2}}},
 [2]={size=16,members={{offset=0,size=4,storage=2},{offset=4,size=12,storage=20,atom=2,count=3,type=3}}},
 [3]={size=4,members={{offset=0,size=4,storage=6}}}}}
assert(N.storage(meta,1,32,'u32')=='i32'and N.storage(meta,1,48,'u32')=='i32')
assert(N.storage(meta,1,36,'i32')=='u32'and N.storage(meta,1,44,'i32')=='u32')
assert(N.storage(meta,1,32,'gun')=='gun'and N.storage(meta,1,32,'flag')=='flag')
for _,case in ipairs({{200.20001220703125,'200.2'},{450.3000183105469,'450.3'},
 {0.10000000149011612,'0.1'},{-200.20001220703125,'-200.2'},{0,'0'},
 {1.0000004768371582,'1.0000005'},{4294967295,'4294967295'}})do
 assert(N.display(case[1])==case[2],N.display(case[1]))
 assert(N.input({storage='f32'},case[1])==case[2])
end
assert(N.display(N.validate(float,1e-30))=='1e-30')
assert(N.display(math.huge)==tostring(math.huge)and N.display(0/0)==tostring(0/0))
assert(N.display(N.F32_MAX)=='FLT_MAX'and N.display(-N.F32_MAX)=='-FLT_MAX')
assert(tonumber(N.input({storage='f32'},N.F32_MAX))==N.F32_MAX)
local current=N.validate(float,200)
for _=1,2 do current=N.validate(float,N.increment(current,.1))end
assert(current==N.validate(float,200.2),'increment accumulated float32 residue')
for _=1,2 do current=N.validate(float,N.increment(current,-.1))end
assert(current==200,'decrement did not return to baseline')
current=1024
for _=1,3 do current=N.validate(float,N.increment(current,.0001))end
assert(current>1024.0002,'fine increments became stuck at display precision')
print('PASS: storage-only integer/float/bool/bit limits, shared-row consistency, finite checks, tiny float precision and hex/scientific input')
print('PASS: clean float32 display/input, meaningful digits, tiny values, FLT_MAX and decimal stepping without drift')
