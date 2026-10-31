local ffi=require('ffi');local G=require('gamedata');local H=require('hostdata');local I=require('install')
local PASSIVE,KIT=0x63CE0FEB,0xD9A55AA0
local originals={}
for _,name in ipairs(I.list_files(TEST_FIXTURES,'generated_*.dl_bin'))do
 local raw=assert(I.read(TEST_FIXTURES..'/'..name));originals[name]=G.seal(ffi.cast('const uint8_t *',raw),#raw)
end
assert(#H.load(TEST_GAME,originals)==0)
local function u32(p,at)return tonumber(ffi.cast('uint32_t *',p+at)[0])end
local passives,armors={},{}
for _,f in pairs(H.files)do for _,h in ipairs(G.headers(f.p,f.n))do
 local p=f.p+h.at+24
 if h.type==PASSIVE then passives[#passives+1]=u32(p,0)end
 if h.type==KIT and h.size>=44 and u32(p,40)==0 then armors[u32(p,16)]=u32(p,28)end
end end
table.sort(passives);assert(#passives>=14)
local first,second,base
for a,id in pairs(armors)do for b,other in pairs(armors)do if a~=b and id==other and id~=0 then first,second,base=a,b,id;break end end;if first then break end end
assert(first and second)
local list={};for i=1,14 do list[i]=passives[i]end
local changes=H.diff();assert(H.armor_passives(changes,{[first]=list},print))
local result={}
for _,c in ipairs(changes)do local hash=c.hash;local sealed=assert(H.build(c));local p,n=assert(G.open_sealed(sealed));assert(G.murmur64(p,n)==hash);result[c.name]={p=p,n=n}end
local assigned,untouched,clone
for _,f in pairs(result)do for _,h in ipairs(G.headers(f.p,f.n))do
 local p=f.p+h.at+24
 if h.type==KIT and u32(p,40)==0 then if u32(p,16)==first then assigned=u32(p,28)elseif u32(p,16)==second then untouched=u32(p,28)end end
end end
assert(assigned and assigned~=base and untouched==base,'armor selection affected another armor sharing its original passive')
for _,f in pairs(result)do for _,h in ipairs(G.headers(f.p,f.n))do if h.type==PASSIVE and u32(f.p+h.at+24,0)==assigned then clone=f.p+h.at+24 end end end
assert(clone);local count,shown,seen=u32(clone,24),0,{}
local offset=tonumber(ffi.cast('uint64_t *',clone+16)[0])
for i=0,count-1 do local p=clone+offset+i*16;local id=u32(p,0);assert(not seen[id],'duplicate modifier');seen[id]=true;if u32(p,12)~=0 then shown=shown+1 end end
assert(shown<=3 and count>3,'description cap removed effects or did not apply')
for _,f in pairs(result)do G.free(f.p)end
-- No passive is a legitimate per-armor choice; invalid IDs stop preparation.
changes=H.diff();assert(H.armor_passives(changes,{[first]={}}));for _,c in ipairs(changes)do G.free(c.plain)end
changes=H.diff();assert(not H.armor_passives(changes,{[first]={4294967295}}));for _,c in ipairs(changes)do G.free(c.plain)end
print('PASS: 14-passive private armor record, unrelated shared-passive armor unchanged, unique modifiers, <=3 displayed descriptions, empty list, invalid-ID refusal and authenticated builds; no game writes')
