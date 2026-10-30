-- offline/archives.lua on synthetic game data: a loose archive (full edition) and the same archive packed into a bundle
-- (slim edition: bundles.nxa listing it, its chunk LZ4-packed), read by offset, by directory and by resource, and the
-- index over both (built, then read back from its cache file).
--   python tests/run_lua.py tests/test_archives.lua   (no game files needed)
local A=require('archives')
local function p32(v)return string.char(v%256,math.floor(v/256)%256,math.floor(v/65536)%256,math.floor(v/16777216)%256)end
local function p64(v)return p32(v%4294967296)..p32(math.floor(v/4294967296))end
local function pad(s,n)return s..string.rep('\0',n-#s)end
-- an archive: two files of one type (main data only), then the companion .stream with one file's stream part
local TYPE,N1,N2=A.raw('AD9C6D9ED1E5E77A'),A.raw('1111111111111111'),A.raw('2222222222222222')
local body1,body2,stream2='first file\0',string.rep('second ',40),'streamed part'
local data_at=72+32+80*2
local function rec(name,mo,mn,so,sn)return pad(name..TYPE..p64(mo)..p64(so)..p64(0),56)..p32(mn)..p32(sn)..p32(0)..string.rep('\0',12)end
local main=pad(p32(0xF0000011)..p32(1)..p32(2),72)..pad('',32)..rec(N1,data_at,#body1,0,0)..rec(N2,data_at+#body1,#body2,0,#stream2)
     ..body1..body2
assert(#main==data_at+#body1+#body2)
-- an LZ4 block of literals only (a valid last sequence)
local function lz4_literals(s)
 local n=#s;local token,extra=math.min(n,15)*16,''
 if n>=15 then local r=n-15;while r>=255 do extra=extra..'\255';r=r-255 end;extra=extra..string.char(r)end
 return string.char(token)..extra..s
end
assert(A.lz4(lz4_literals('hello lz4'),9)=='hello lz4')
-- a match: 'abcabcabcabc' = literals 'abc' then a match of 9 back 3 (token 0x35: 3 literals, length 9-4=5)
assert(A.lz4('\53abc\3\0',12)=='abcabcabcabc','overlapping LZ4 match')
local dir=os.tmpname();os.remove(dir)
assert(os.execute('mkdir "'..dir..'"'))
local function put(name,s)local f=assert(io.open(dir..'/'..name,'wb'));f:write(s);f:close()end
-- full edition: loose files
put('aaaaaaaaaaaaaaaa',main);put('aaaaaaaaaaaaaaaa.stream',stream2)
local S=A.open(dir)
assert(not S.slim and S:has('aaaaaaaaaaaaaaaa'))
local d=S:directory('aaaaaaaaaaaaaaaa');assert(#d==2 and d.by[N2..TYPE].main[2]==#body2)
local r=S:resource('aaaaaaaaaaaaaaaa',N2..TYPE);assert(r.main==body2 and r.stream==stream2 and r.gpu=='')
assert(S:resource('aaaaaaaaaaaaaaaa',A.raw('3333333333333333')..TYPE)==nil)
-- slim edition: the archive (and its stream) inside bundles.00.nxa, one LZ4 chunk each, listed by bundles.nxa
local function dsar(chunks)   -- chunks: { {unpacked offset, data, packing} }
 local head='DSAR'..p32(0)..p32(#chunks)..string.rep('\0',20)
 local at,list,blobs=32+32*#chunks,{},{}
 for _,c in ipairs(chunks)do
  local packed=c[3]==3 and lz4_literals(c[2])or c[2]
  list[#list+1]=p64(c[1])..p64(at)..p32(#c[2])..p32(#packed)..string.char(c[3])..string.rep('\0',7)
  blobs[#blobs+1]=packed;at=at+#packed
 end
 return head..table.concat(list)..table.concat(blobs)
end
put('bundles.00.nxa',dsar({{0,main,3},{#main,stream2,3}}))
local names='bbbbbbbbbbbbbbbb\0bbbbbbbbbbbbbbbb.stream\0bundles.00.nxa\0'
local list_at=24+24*2+4
local entries_at=list_at+#names
local d2=pad('DSAA'..p32(0)..p32(0)..p32(1)..p32(2),24)
 ..p64(#main)..p32(list_at)..p32(1)..p64(entries_at)
 ..p64(#stream2)..p32(list_at+17)..p32(1)..p64(entries_at+16)
 ..p32(list_at+17+24)..names
 ..p32(0)..p32(0)..p32(0)..p32(0)..p32(0)..p32(0)..p32(#main)..p32(0)
d2=d2:sub(1,entries_at+15)..string.char(0)..d2:sub(entries_at+17)   -- (byte 15 of an entry: the bundle, 0)
put('bundles.nxa',dsar({{0,d2,0}}))
local S2=A.open(dir)
assert(S2.slim and S2.bundles[0]=='bundles.00.nxa'and S2.archives.bbbbbbbbbbbbbbbb)
assert(S2:read('bbbbbbbbbbbbbbbb',data_at,#body1)==body1,'read across the bundle')
local r2=S2:resource('bbbbbbbbbbbbbbbb',N2..TYPE);assert(r2.main==body2 and r2.stream==stream2,'resource out of the bundle')
-- the index: both archives (the loose one and the bundled one), then from its cache
local function list_files(_,pattern)return pattern=='????????????????'and{'aaaaaaaaaaaaaaaa'}or{}end
local idx=A.index(S2,{[TYPE]=true},dir..'/idx.bin','stamp 1',list_files)
assert(#idx[N1..TYPE]==2 and idx[N1..TYPE][1]=='aaaaaaaaaaaaaaaa'and idx[N1..TYPE][2]=='bbbbbbbbbbbbbbbb')
local again=A.index(S2,{},dir..'/idx.bin','stamp 1',list_files)
assert(#again[N2..TYPE]==2 and again[N2..TYPE][2]=='bbbbbbbbbbbbbbbb','index cache read back')
local other=A.index(S2,{},dir..'/idx.bin','stamp 2',list_files)
assert(next(other)==nil,'a cache of other game files is not used')
for _,n in ipairs({'aaaaaaaaaaaaaaaa','aaaaaaaaaaaaaaaa.stream','bundles.00.nxa','bundles.nxa','idx.bin'})do os.remove(dir..'/'..n)end
os.remove(dir)
print('archives: ok (loose and bundled archives, LZ4, directories, resources, index and its cache)')
