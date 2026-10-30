local ffi=require('ffi')
local function read(path)local f=assert(io.open(path,'rb'));local s=f:read('*a'):gsub('\r\n','\n');f:close();return s end
local function extract(s,name)
 local first=assert(s:find('KINDS[TYPES.custom].'..name..' = function',1,true))
 local last=assert(s:find('\nend',first,true))+3
 return s:sub(first,last)
end
local function probe(defaults_enabled)
 local path=TEST_ROOT..'/src/stat_editor_offline.lua'
 local source=read(path)
 local factory=assert(loadstring('return function(KINDS,TYPES,tables,defaults,api,peek4,HEADER_BYTES,T_WEAPON)\n'..
  extract(source,'projectile')..'\n'..extract(source,'feeds')..'\nreturn KINDS[TYPES.custom] end'))()
 local custom,item,delta=ffi.new('uint8_t[72]'),ffi.new('uint8_t[40]'),ffi.new('uint8_t[1024]')
 local function set(p,off,v)ffi.cast('uint32_t *',p+off)[0]=v end
 set(custom,4,123);ffi.copy(item+32,'abcdefgh',8)
 set(delta,0,1);set(delta,4,0);set(delta,128,321);set(delta,132,0);set(delta,136,2)
 set(delta,256,0);set(delta,260,4);set(delta,264,0)
 set(delta,268,64);set(delta,272,4);set(delta,276,4)
 set(delta,512,999);set(delta,516,888)
 local K={[1]={},[2]={find=function(id)if id==123 then return {copies={item}},0 end end},[3]={layout={0,128,256,512}},[99]={stride=1}}
 local types={custom=1,items=2,deltas=3}
 local tables={[1]={index={unit=0},copies={custom}},[3]={index={abcdefgh=0},copies={delta}}}
 local names=defaults_enabled and {['3:512']=42,['3:516']=43}or{}
 local f=factory(K,types,tables,names,{read=function(p,n)return ffi.string(p,n)end},function(p)return ffi.cast('uint32_t *',p)[0]end,0,99)
 local projectile=f.projectile('unit');local feeds=f.feeds('unit',{[64]=43})
 
 return projectile,feeds[64]
end
local a,b=probe(true);assert(a==42 and b==516,'swapped memory must not replace the original attachment baseline')
local c,d=probe(false);assert(c==999 and d==nil,'unrecorded defaults must fall back to current memory')
print('PASS: real attachment projectile/feed readers preserve saved defaults after swaps and retain memory fallback')
