local D=require('demolition')
local function r(n)local f=assert(io.open(TEST_FIXTURES..'/'..n,'rb'));local s=f:read('*a');f:close();return s end
local m=D.new(r('generated_entities.dl_bin'),r('generated_destruction_settings.dl_bin'),r('dl_library.dl_typelib'))
local f=assert(io.open(TEST_WORK..'/target_hashes.txt','wb'))
for _,t in ipairs(m.targets)do f:write(t.hash,'\n',t.unit,'\n')end
f:close()
