local P=require('portable_file');local J=require('json_data')
local function check(raw)local v=J.decode(raw);return type(v)=='table'and type(v.value)=='number'end
local disk={};local fail,corrupt,race
local fs={read=function(p)return disk[p]end,remove=function(p)disk[p]=nil;return true end}
fs.write=function(p,s)
 if fail==p then disk[p]='partial';return nil,'injected write failure'end
 disk[p]=corrupt==p and 'bad' or s;return true
end
fs.move=function(a,b)
 if fail==b then return nil,'injected rename failure'end
 disk[b],disk[a]=disk[a],nil;return true
end
local o={fs=fs,validate=check};local path='config.json'
assert(P.save(path,'{"value":1}',o))
assert(P.save(path,'{"value":2}',o));assert(disk[path..'.bak']=='{"value":1}')
assert(P.save(path,'{"value":2}',o));assert(disk[path..'.bak']=='{"value":1}','no-op replaced backup')
for _,at in ipairs({path..'.tmp',path..'.bak.tmp',path..'.bak',path})do
 fail=at;assert(not P.save(path,'{"value":3}',o));assert(disk[path]=='{"value":2}')
 assert(not disk[path..'.tmp']and not disk[path..'.bak.tmp'],'failed save left temporary files')
end
fail=nil;corrupt=path..'.tmp';assert(not P.save(path,'{"value":3}',o));assert(disk[path]=='{"value":2}')
corrupt=nil;assert(P.save(path,'{"value":3}',o));assert(disk[path..'.bak']=='{"value":2}')
disk[path]='truncated';local raw,why,recovered=P.read(path,o);assert(recovered and raw=='{"value":2}')
assert(P.save(path,raw,o));assert(disk[path..'.corrupt']=='truncated'and disk[path..'.bak']==raw)
local real_read=fs.read;local n=0
fs.read=function(p)if p==path then n=n+1;if n==2 then disk[path]='{"value":99}'end end;return real_read(p)end
assert(not P.save(path,'{"value":4}',o));assert(disk[path]=='{"value":99}')
fs.read=real_read;assert(not P.save(path,'bad',o))
-- Real Unicode paths and native write-through replacement, inside TEST_WORK only.
local F=require('preset_files');local I=require('install');I.mkdirs(TEST_WORK)
local name=TEST_WORK..'/配置.json'
assert(P.save(name,'{"value":1}',{validate=check}));assert(P.save(name,'{"value":2}',{validate=check}))
assert(F.read(name)=='{"value":2}'and F.read(name..'.bak')=='{"value":1}')
print('PASS: portable atomic saves, partial writes, read-back corruption, rename/backup failures, concurrent edits and valid backup recovery')
