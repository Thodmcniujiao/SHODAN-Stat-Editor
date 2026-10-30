local ffi=require('ffi');local G=require('gamedata');local H=require('hostdata')
local function check(bits,expected,name)
 local original=ffi.new('uint8_t[8]');local data=ffi.new('uint8_t[8]')
 ffi.cast('uint32_t *',data)[0]=bits
 H.files={review={name=name or'review.dl_bin',p=data,n=8,cipher=G.seal(original,8),resolved={}}}
 local changes=H.diff()
 if bits==0 then assert(#changes==0);return end
 assert(#changes==1)
 local floats=changes[1].floats
 assert(#floats==(expected and 1 or 0),string.format('incorrect float classification: %08X',bits))
 if expected then assert(floats[1]==0)end
 G.free(changes[1].plain)
end
for _,bits in ipairs({0,0xFFFFFFFF,0x7FC00000,0x7F800000,0xFF800000,0x80000000,0x38D1B717,0x4B189680})do check(bits,false)end
for _,bits in ipairs({0x38D1B718,0xB8D1B718,0x3FA00000,0xBFA00000,0x4B18967F})do check(bits,true)end
-- A table restricted to schema-verified float fields must keep rejecting unclassified words.
check(0x3FA00000,false,'generated_stratagem_settings.dl_bin')
print('PASS: none/-1, NaN/Inf, signed zero, positive/negative float bounds and schema whitelist; no live data writes')
