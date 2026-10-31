-- Remember only bytes that have actually been edited. A lazily opened packed
-- alias must still see the original value after another alias changed its byte.
local ffi=require('ffi')
local M={bytes={}}
local sizes={flag=1,u8=1,i8=1,u16=2,i16=2,u32=4,i32=4,f32=4,enum=4}
local float=ffi.new('float[1]')
function M.remember(kind,offset,before)
 if type(before)~='string'then return end
 local bytes=M.bytes[kind];if not bytes then bytes={};M.bytes[kind]=bytes end
 for i=1,#before do local at=offset+i-1;if bytes[at]==nil then bytes[at]=before:byte(i)end end
end
function M.value(field,entry,read,header)
 local saved=M.bytes[field.kind];local size=field.storage=='bits'and field.bit_bytes or sizes[field.storage]
 if not saved or not size or not entry then return nil,false end
 local hit=false;for i=0,size-1 do if saved[field.offset+i]~=nil then hit=true;break end end
 if not hit then return nil,false end
 local live=read(entry.copies[1]+header+field.offset,size)
 if not live or #live~=size then return nil,false end
 local bytes,value={},0
 for i=size,1,-1 do
  local byte=saved[field.offset+i-1];if byte==nil then byte=live:byte(i)end
  bytes[i]=string.char(byte);value=value*256+byte
 end
 if field.mask then return math.floor(value/field.mask)%2,true end
 if field.storage=='bits'then return math.floor(value/2^field.bit_shift)%2^field.bit_width,true end
 if field.storage=='f32'then ffi.copy(float,table.concat(bytes),4);return tonumber(float[0]),true end
 if field.storage:match('^i%d+$')and value>=2^(size*8-1)then value=value-2^(size*8)end
 if field.storage=='flag'and value>1 then return nil,true end
 return value,true
end
return M
