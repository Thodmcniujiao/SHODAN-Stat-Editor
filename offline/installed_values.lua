-- Read installed numeric values from owned game files, independently of config.txt.
-- Original buffers remain the reset/build baseline. Only matching LDLD record
-- layouts are read; serialized pointers are never copied into host memory.
local ffi=require('ffi')
local G=require('gamedata')
local M={};M.__index=M
local sizes={flag=1,u8=1,i8=1,u16=2,i16=2,u32=4,i32=4,f32=4,enum=4}
local float=ffi.new('float[1]')
function M.new(files,installed,log)
 local self=setmetatable({files=files,installed={},blocks={},log=log or function()end},M)
 self:update(installed or{});return self
end
function M:update(writes)
 for name,cipher in pairs(writes)do
  local file=self.files[name]
  if file then
   self.installed[name]=cipher~=file.cipher and cipher or nil
   for address,b in pairs(self.blocks)do if b.file==name then self.blocks[address]=nil end end
   if self.installed[name]then
    local current,n=G.open_sealed(cipher)
    local original,on=G.open_sealed(file.cipher)
    if current and original and G.murmur64(current,n)==file.hash then
     G.clear_correction(current,n);G.clear_correction(original,on)
     local by_kind,counts={},{}
     for _,h in ipairs(G.headers(current,n))do
      by_kind[h.type]=by_kind[h.type]or{};by_kind[h.type][#by_kind[h.type]+1]=h
     end
     for _,h in ipairs(G.headers(original,on))do
      counts[h.type]=(counts[h.type]or 0)+1
      local ch=by_kind[h.type]and by_kind[h.type][counts[h.type]]
      if ch and ch.size>=h.size then
       local a=ffi.string(original+h.at+24,h.size)
       local b=ffi.string(current+ch.at+24,ch.size)
       if a~=b and a:sub(1,16)==b:sub(1,16)then
        self.blocks[tonumber(ffi.cast('uintptr_t',file.p))+h.at]={file=name,original=a,current=b}
       end
      end
     end
    else self.log('installed values: could not verify '..name)end
    if current then G.free(current)end;if original then G.free(original)end
   end
  end
 end
end
function M:changed(entry,offset,size)
 local b=entry and self.blocks[entry.copies[1]]
 if not b or offset<0 or offset+size>#b.original or offset+size>#b.current then return false end
 return b.original:sub(offset+1,offset+size)~=b.current:sub(offset+1,offset+size)
end
function M:value(field,entry)
 local size=field.storage=='bits'and field.bit_bytes or sizes[field.storage]
 if not size or field.demolition or not self:changed(entry,field.offset,size)then return nil end
 local bytes=self.blocks[entry.copies[1]].current:sub(field.offset+1,field.offset+size)
 local value=0;for i=size,1,-1 do value=value*256+bytes:byte(i)end
 if field.mask then return math.floor(value/field.mask)%2 end
 if field.storage=='bits'then return math.floor(value/2^field.bit_shift)%2^field.bit_width end
 if field.storage=='f32'then ffi.copy(float,bytes,4);return tonumber(float[0])end
 if field.storage:match('^i%d+$')and value>=2^(size*8-1)then value=value-2^(size*8)end
 return value
end
return M
