local I=require('install')
local A=require('entity_assets')
local work=assert(TEST_WORK)
assert(I.home:gsub('\\','/'):sub(1,#work)==work,'use --isolated-profile for this test')
I.game_running=function()return false end
local game=work..'/fake/data/game';I.mkdirs(game)
local function write(p,s)local f=assert(io.open(p,'wb'));f:write(s);f:close()end
local a,b='generated_fake_a.dl_bin','generated_fake_b.dl_bin'
local original={[a]='old A',[b]='old B'}
for n,s in pairs(original)do write(game..'/'..n,s)end
local patch='0123456789abcdef.patch_0'
local asset=A.begin(game,{[patch]='new asset'})
assert(asset:activate())
local actual_move=I.move_file;local calls=0
I.move_file=function(from,to,flags)
 calls=calls+1;if calls==2 then return 0 end;return actual_move(from,to,flags)
end
local ok,why=I.write_files(game,{[a]='new A',[b]='new B'},original)
assert(not ok and why:find('restored',1,true))
I.move_file=actual_move
assert(asset:rollback())
assert(I.read(game..'/'..a)=='old A'and I.read(game..'/'..b)=='old B')
assert(not I.read(work..'/fake/data/'..patch)and not next(A.owned()))
assert(#I.installed(game)==0,'ownership was not rolled back')
local asset2=A.begin(game,{[patch]='installed asset'})
assert(asset2:activate())
assert(I.write_files(game,{[a]='installed A',[b]='installed B'},original))
assert(asset2:commit())
assert(#I.installed(game)==2 and A.owned()[patch])
local asset3=A.begin(game,{})
assert(asset3:activate());assert(I.write_files(game,original,original,true));assert(asset3:commit())
assert(I.read(game..'/'..a)=='old A'and not I.read(work..'/fake/data/'..patch))
assert(not pcall(function()A.begin(game,{['../outside']='bad'})end))
write(work..'/fake/data/'..patch,'another mod')
assert(not pcall(function()A.begin(game,{[patch]='overwrite'})end))
assert(I.read(work..'/fake/data/'..patch)=='another mod')
-- Read-only game files must install and restore through the same transaction wrapper.
local ffi=require('ffi');local name='generated_readonly.dl_bin';local target=game..'/'..name
write(target,'readonly original');assert(ffi.C.SetFileAttributesA(target,1)~=0)
assert(I.write_files(game,{[name]='readonly changed'},{[name]='readonly original'}))
assert(I.read(target)=='readonly changed')
assert(I.write_files(game,{[name]='readonly original'},{[name]='readonly original'},true))
assert(I.read(target)=='readonly original')
assert(ffi.C.SetFileAttributesA(target,1)~=0)
local moved,code=I.move_file(work..'/missing-source',target,9)
assert(moved==0 and code==2 and ffi.C.GetFileAttributesA(target)%2==1)
assert(ffi.C.SetFileAttributesA(target,0x80)~=0)
-- Preserve the move's error even when rollback makes further system calls.
I.move_file=function(from,to,flags)
 if from:match('%.shodan%-new$')then return 0,32 end
 return actual_move(from,to,flags)
end
local blocked,reason=I.write_files(game,{[name]='blocked'},{[name]='readonly original'})
assert(not blocked and reason:find('in use by another program',1,true)and reason:find('restored',1,true))
assert(I.read(target)=='readonly original');I.move_file=actual_move
-- A rejected buffer reload must keep the complete previous editing session alive.
local H=require('hostdata');local G=require('gamedata')
write(game..'/game.dll','test DLL data')
local previous={sentinel={p=G.alloc(16)}};previous.sentinel.p[0]=171
local previous_modded={sentinel=true};H.files,H.modded=previous,previous_modded
local loaded,load_error=H.reload(game,{['generated_invalid.dl_bin']='not a sealed game file'})
assert(not loaded and load_error and H.files==previous and H.modded==previous_modded)
assert(previous.sentinel.p[0]==171,'failed reload freed the active buffer')
G.free(previous.sentinel.p);H.files,H.modded={},{}
print('PASS: partial-write rollback, coordinated asset rollback, install/restore and foreign-file protection')
