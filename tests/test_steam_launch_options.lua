local O=require('steam_launch_options')
local J=require('json_data')
local bridge='C:\\新 目录\\app\\network\\steam_bridge.exe'
local old='C:\\old build\\app\\network\\steam_bridge.exe'
assert(O.recent_account('"users" {"76561197960265851" {"MostRecent" "1" "unrelated" "ignore"}}')=='123')
assert(not O.recent_account('"users" {"76561197960265851" {"MostRecent" "1"} "76561197960265852" {"MostRecent" "1"}}'))
assert(not O.recent_account('"users" {}'))
assert(not O.recent_account('broken'))
local function fixture(value,missing,app_missing)
 return '\239\187\191// brace in comment }\r\n"UserLocalConfigStore"\r\n{\r\n "Software" { "Valve" { "Steam" { "apps" {\r\n'
  ..'"999" {"LaunchOptions" "other-game-secret"}\r\n'
  ..(app_missing and''or('"553850" {"nested" {"553850" "decoy" "LaunchOptions" "ignore"} "future" "{keep} \\"quote\\"" '
  ..(missing and''or('"LaunchOptions" '..O.quote(value or'')))..'}\r\n'))
  ..'} } } }\r\n"unrelated" "private-placeholder"\r\n}'
end
local raw=fixture('/--use-d3d11 --name "a b" --path C:\\x\\')
local doc=assert(O.inspect(raw));assert(doc.value=='/--use-d3d11 --name "a b" --path C:\\x\\')
local changed=O.replace(doc,'"'..bridge..'" %command% '..doc.value,true)
assert(changed:sub(1,doc.option.vs-1)==raw:sub(1,doc.option.vs-1))
assert(changed:sub(-(#raw-doc.option.ve))==raw:sub(doc.option.ve+1),'unrelated bytes changed')
assert(O.inspect(changed).value:find(bridge,1,true))
for _,s in ipairs({'','"broken','"a" {','"a" "b" }',raw:gsub('"future"','"LaunchOptions"'),raw:gsub('"apps"','"apps" {} "APPS"')})do
 assert(not O.inspect(s),'accepted corrupt/ambiguous VDF')
end
for _,noapp in ipairs({false,true})do
 local absent=assert(O.inspect(fixture('',true,noapp)));assert(not absent.present)
 local inserted=assert(O.inspect(O.replace(absent,'new',true)));assert(inserted.value=='new')
 local removed=assert(O.inspect(O.replace(inserted,'',false)));assert(not removed.present)
end
local flags='/--use-d3d11 --name "a b"'
local desired='"'..bridge..'" %command% '..flags
assert(O.merge(flags,bridge)==desired)
assert(O.merge('%command% '..flags,bridge)==desired)
assert(O.merge(desired,bridge)==desired)
assert(O.merge('"'..old..'" %command% '..flags,bridge,{bridge=old})==desired)
assert(O.merge('"'..old..'" %command% "'..old..'" %command% '..flags,bridge,{bridge=old})==desired)
assert(not O.merge('"other-launcher.exe" %command% '..flags,bridge))
assert(not O.merge('foo %command% bar %command%',bridge))

local function model(value,missing,record)
 local files={['/steam/userdata/123/config/localconfig.vdf']=fixture(value,missing)}
 local account='123';local target={account=account,path='/steam/userdata/'..account..'/config/localconfig.vdf',bridge=bridge}
 local fs={};local state={running=false,writes=0,commits=0,fail=false,files=files,target=target}
 local journal='/portable/SteamLaunchOptions/123.json'
 if record then files[journal]=J.encode(record,true)end
 fs.read=function(p)return files[p]end
 fs.write=function(p,s)files[p]=s;state.writes=state.writes+1;return true end
 fs.move=function(a,b)files[b]=files[a];files[a]=nil;return true end
 fs.remove=function(p)files[p]=nil;return true end
 local c={fs=fs,home='/portable',mkdir=function()return true end,resolve=function()return state.target end,
  running=function()return state.running end,recognize=function(p)return p==old end,
  commit=function(p,before,after,guard)
   state.commits=state.commits+1
   if state.before_commit then state.before_commit()end
   if not guard()or files[p]~=before or state.fail then return nil,'injected concurrent change/write failure'end
   files[p]=after;return true
  end}
 state.model=O.new(c);state.c=c;state.journal=journal
 function state:value()return assert(O.inspect(files[target.path])).value end
 return state
end
local t=model(flags);local first=t.files[t.target.path];t.running=true
assert(t.model:poll(true).state=='waiting'and t:value()==flags and t.writes==0,'wrote while Steam running')
t.running=false;assert(t.model:poll(true).state=='ready'and t:value()==desired and t.commits==1)
local backup=assert(J.decode(t.files[t.journal]));assert(backup.original==flags and backup.present and backup.account=='123')
assert(not t.files[t.journal]:find('private-placeholder',1,true),'backed up whole Steam config')
local writes=t.writes;assert(t.model:poll(true).state=='ready'and t.commits==1 and t.writes==writes,'repeat startup rewrote files')
local reopened=O.new(t.c);assert(reopened:poll(true).state=='ready'and t.commits==1,'reopen not idempotent')
t.running=true;assert(reopened:restore().state=='waiting'and t:value()==desired)
t.running=false;assert(reopened:poll(false).state=='restored'and t:value()==flags)
assert(t.files[t.target.path]==first,'existing option did not restore exact bytes')
-- Later user-added flags survive restore; a subsequent new cycle backs up the new baseline.
assert(reopened:poll(true).state=='ready')
t.files[t.target.path]=O.replace(O.inspect(t.files[t.target.path]),desired..' --later',true)
assert(reopened:restore().state=='restored'and t:value()==flags..' --later')
assert(reopened:poll(true).state=='ready')
assert(J.decode(t.files[t.journal]).original==flags..' --later')
-- Missing key restoration removes only that key, not the rest of the app.
t=model('',true);assert(t.model:poll(true).state=='ready');assert(t.model:restore().state=='restored')
assert(not O.inspect(t.files[t.target.path]).present and t.files[t.target.path]:find('private-placeholder',1,true))
-- Disabled policy never writes; explicit repair can wait for shutdown even when disabled.
t=model(flags);assert(t.model:poll(false).state=='disabled'and t.writes==0)
t.running=true;assert(t.model:repair().state=='waiting');t.running=false
assert(t.model:poll(false).state=='ready'and t.commits==1)
-- Auto-off cancels a pending automatic repair.
t=model(flags);t.running=true;t.model:poll(true);t.running=false
assert(t.model:poll(false).state=='disabled'and t.commits==0)
-- Migrate a recognized preceding build; record handles a deleted old bridge in later builds.
t=model('"'..old..'" %command% '..flags);assert(t.model:poll(true).state=='ready'and t:value()==desired)
assert(t.model:restore().state=='restored'and t:value()==flags)
-- Correct, already-installed legacy option is adopted without touching Steam.
t=model(desired);t.running=true;assert(t.model:poll(true).state=='ready'and t.commits==0 and t.files[t.journal])
t.running=false;assert(t.model:restore().state=='restored'and t:value()==flags)
-- Corrupt journal, other wrappers, failed writes and races preserve the target.
t=model(flags);t.files[t.journal]='broken';assert(t.model:poll(true).state=='error'and t.commits==0)
t=model('"foreign.exe" %command%');assert(t.model:poll(true).state=='conflict'and t.writes==0)
t=model(flags);t.fail=true;assert(t.model:poll(true).state=='error'and t:value()==flags)
t=model(flags);t.before_commit=function()t.running=true end;assert(t.model:poll(true).state=='error'and t:value()==flags)
t=model(flags);t.before_commit=function()t.files[t.target.path]=fixture('new-user-flags')end
assert(t.model:poll(true).state=='error'and t:value()=='new-user-flags')
t=model(flags);t.before_commit=function()t.target={account='456',path='/other',bridge=bridge}end
assert(t.model:poll(true).state=='error')
print('PASS Steam options: lexical VDF, exact target/byte preservation, missing key/app, Unicode/quotes, idempotence, flags, restore, migration, no live writes, failures/races, portable journal')
