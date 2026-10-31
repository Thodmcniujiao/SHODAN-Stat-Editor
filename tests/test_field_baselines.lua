local M=require('field_baselines')
local entry={copies={1000}}
local function reader(bytes)return function(_,size)return bytes:sub(1,size)end end
M.remember(1,0,string.char(240))
assert(M.value({kind=1,offset=0,storage='flag',mask=1},entry,reader(string.char(241)),24)==0)
assert(M.value({kind=1,offset=0,storage='flag',mask=16},entry,reader(string.char(225)),24)==1)
assert(M.value({kind=1,offset=0,storage='u8'},entry,reader(string.char(0)),24)==240)
M.remember(1,0,string.char(0));assert(M.bytes[1][0]==240,'later edits replaced the baseline')
M.remember(2,0,string.char(255,255,255,255))
assert(M.value({kind=2,offset=0,storage='i32'},entry,reader(string.rep('\0',4)),24)==-1)
assert(M.value({kind=2,offset=0,storage='bits',bit_bytes=4,bit_shift=8,bit_width=12},entry,reader(string.rep('\0',4)),24)==4095)
M.remember(3,0,string.char(0,0,192,63)) -- float32 1.5
assert(M.value({kind=3,offset=0,storage='f32'},entry,reader(string.rep('\0',4)),24)==1.5)
M.remember(4,1,string.char(255))
assert(M.value({kind=4,offset=0,storage='u16'},entry,reader(string.char(52,0)),24)==65332)
local _,found=M.value({kind=5,offset=0,storage='u32'},entry,reader(string.rep('\0',4)),24)
assert(not found,'untouched fields should use the ordinary live/default path')
print('PASS: late packed/raw aliases preserve original bytes across overlapping edits; signed integers, float32 and repeated writes keep correct reset baselines')
