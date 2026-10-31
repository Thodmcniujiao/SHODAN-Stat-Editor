-- Each app copy owns its Data/Presets folders, independent of profile and cwd.
assert(TEST_WORK and SHODAN_DATA_DIRECTORY,'use --isolated-profile --work <directory>')
local I=require('install');local original_getenv=os.getenv
os.getenv=function(name)
 assert(name~='APPDATA' and name~='LOCALAPPDATA','offline code consulted a profile directory')
 return original_getenv(name)
end
local saved=SHODAN_DATA_DIRECTORY;SHODAN_DATA_DIRECTORY=nil
local f=assert(io.open(TEST_ROOT..'/offline/user_paths.lua','rb'));local paths=f:read('*a');f:close()
local function make(name)
 local root=TEST_WORK..'/'..name;I.mkdirs(root..'/app')
 local file=assert(io.open(root..'/app/user_paths.lua','wb'));assert(file:write(paths));file:close()
 return root
end
local one,two=make('copy-one'),make('copy-two')
local a=assert(loadfile(one..'/app/user_paths.lua'))()
local b=assert(loadfile(two..'/app/user_paths.lua'))()
assert(a.home==one..'/Data' and b.home==two..'/Data' and a.home~=b.home)
assert(a.presets==one..'/Presets' and a.names==one..'/Names')
assert(a.logs==one..'/Data/Logs')
-- Requiring install from the relocated app must use the same root.
package.loaded.user_paths=a;package.loaded.install=nil
local isolated=require('install');assert(isolated.home==a.home and isolated.logs==a.logs)
isolated.mkdirs(isolated.home)
local file=assert(io.open(isolated.home..'/config.txt','wb'));file:write('hotkey F9\n');file:close()
assert(not isolated.read(b.home..'/config.txt'),'separate copies shared config')
-- The complete panel must use this root for settings, logs and preset imports.
SHODAN_PRESET_DIRECTORY=nil
SHODAN_OFFLINE=true;SHODAN_OFFLINE_LANG='en'
stingray=require('engine_shim').engine();update=function()end
local external=TEST_WORK..'/external-profile/Presets';isolated.mkdirs(external)
local library=require('preset_library').new{dir=external}
assert(library:create('global','Must not import',{values={}}))
file=assert(io.open(isolated.home..'/presets_folder.txt','wb'));file:write(external);file:close()
file=assert(io.open(TEST_ROOT..'/src/stat_editor_offline.lua','rb'));local source=file:read('*a');file:close()
source=source..'\nTEST_PORTABLE={save=save_config,flush=flush_log,log=log,hotkey=hotkey_name,presets=presets}\n'
assert(loadstring(source,'@'..TEST_ROOT..'/src/stat_editor_offline.lua'))()
local E=assert(TEST_PORTABLE)
assert(E.hotkey=='F9' and E.presets.directory==a.presets)
assert(E.save());E.log('portable path fixture');E.flush()
assert(isolated.read(a.logs..'/SHODANStatEditor.log'):find('portable path fixture',1,true))
assert(isolated.read(a.home..'/config.txt'):find('hotkey F9',1,true))
-- A copied Data folder cannot resurrect the last machine's preset location.
for _,preset in ipairs(E.presets.library.document.items)do
 assert(preset.name~='Must not import','imported presets from another profile')
end
os.getenv=original_getenv;SHODAN_DATA_DIRECTORY=saved
print('PASS: relocated app copies, portable config/log/preset paths, no AppData access or previous-profile import')
