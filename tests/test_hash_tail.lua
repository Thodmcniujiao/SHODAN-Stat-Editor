local ffi=require('ffi');local G=require('gamedata');local H=require('hostdata')
local function block(size,kind)
 local p=G.alloc(24+size);ffi.copy(p,'LDLD\1\0\0\0',8)
 ffi.cast('uint32_t *',p+8)[0]=kind or 123
 ffi.cast('uint32_t *',p+12)[0]=size;p[16]=1
 for i=24,23+size do p[i]=(i*29+size)%256 end
 local s=ffi.string(p,24+size);G.free(p);return s
end
local began=os.clock();local count=0
for size=0,199 do
 for _,prefix in ipairs({'',block(16,456)})do
  local raw=prefix..block(size);local n=#raw
  local p=G.alloc(n);ffi.copy(p,raw,n)
  local target=G.murmur64(p,n)
  if size>=4 then ffi.cast('float *',p+n-size)[0]=200.2 end
  if size>=12 then ffi.cast('uint64_t *',p+n-size+4)[0]=10045530214660760388ULL end
  local before=ffi.string(p,n);local hs=G.headers(p,n);local last=hs[#hs]
  local sealed,why=H.build({plain=p,n=n,hash=target,floats={},demolition_schemas={}})
  assert(sealed,why)
  local back,m=assert(G.open_sealed(sealed));assert(m%8==0 and m>n and m-n<=15)
  assert(G.murmur64(back,m)==target)
  local changed=ffi.string(back,n)
  assert(changed:sub(1,last.at+12)==before:sub(1,last.at+12))
  assert(changed:sub(last.at+17)==before:sub(last.at+17),'a live parameter changed')
  local newhs=G.headers(back,m);assert(#newhs==#hs and newhs[#newhs].at+24+newhs[#newhs].size==m)
  assert(G.pristine(back,m),'header flag/reserved bytes changed')
  G.free(back);count=count+1
 end
end
local p=G.alloc(32);assert(not G.correct_tail(p,7,0ULL));assert(not G.correct_tail(p,9,0ULL));G.free(p)
print(string.format('PASS: %d exact tail builds, all alignments, f32/u64 bytes, multi-block and authenticated round trips (%.3fs)',count,os.clock()-began))
