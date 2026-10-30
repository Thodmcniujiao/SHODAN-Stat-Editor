-- record_names.lua: external planning names for enum/record row ids (no game files needed).
local I = require('install')
local R = require('record_names')
local dir = TEST_WORK .. '/record-names'
I.mkdirs(dir)
local function write(name, text)
    local f = assert(io.open(dir .. '/' .. name, 'wb'))
    f:write(text)
    f:close()
end
write('record_names.json', [[
{
  "version": 1,
  "types": {
    "projectile": { "282": "轨道炮射弹", "0x120": "hex alias" },
    "orbital_ability": { "AC129AA2DB5EABC9": "轨道炮攻击" },
    "bombardment": { "AC129AA2DB5EABC9": "轨道轰炸" },
    "eagle": { "7A3F19D20C4B8E61": "飞鹰空袭" }
  }
}
]])
write('record_names.txt', [[
# type id name
damage 123 主武器伤害
beam	45	激光设计名
projectile 283 another name with spaces
]])
local count, errors = R.load(dir)
assert(count == 5, 'count ' .. count)
assert(R.name('projectile', 282) == '轨道炮射弹')
assert(R.name('projectile', '0x120') == 'hex alias')
assert(R.hash_names.AC129AA2DB5EABC9)
assert(R.name('orbital_ability', 'AC129AA2DB5EABC9') == nil)
assert(R.name('bombard', '0xAC129AA2DB5EABC9') == nil)
assert(R.name('orbital_bombardment', 'AC129AA2DB5EABC9') == nil)
assert(R.hash_names['7A3F19D20C4B8E61'] == '飞鹰空袭')
assert(R.name('damage', '0123') == '主武器伤害')
assert(R.name('laser', 45) == '激光设计名')
assert(R.name('projectile', 283) == 'another name with spaces')
assert(R.name('projectile', 999) == nil)
assert(#errors == 0, errors[1])
-- a new load replaces the names and counts malformed lines
write('record_names.txt', 'broken\n')
local count2, errors2 = R.load(dir)
assert(count2 == 5, 'count2 ' .. count2)   -- JSON still loads
assert(#errors2 == 0, errors2[1]) -- legacy TXT no longer overrides the migrated folder
local F=require('preset_files');local J=require('json_data')
assert(F.read(R.folder..'/projectile.json') and F.read(R.folder..'/eagle.json'))
assert(F.move(R.folder..'/projectile.json',R.folder..'/射弹.json'));R.reload()
R.seed('projectile',{[900]='new local index'})
local _,renamed_errors=R.reload();assert(#renamed_errors==0 and R.name('projectile',900)=='new local index')
assert(not F.read(R.folder..'/projectile.json'),'renamed TypeID file must not be duplicated during seeding')
assert(F.write(R.folder..'/damage.json',J.encode({type='damage',names={['282']='damage only'}})))
R.reload();assert(R.name('damage',282)=='damage only'and R.name('projectile',282)=='轨道炮射弹')
assert(F.write(R.folder..'/damage.json','{broken'))
local _,bad=R.reload();assert(#bad==1 and R.name('damage',282)=='damage only','bad JSON must preserve last valid names')
R.seed('damage',{[999]='must not overwrite invalid user JSON'})
assert(F.read(R.folder..'/damage.json')=='{broken')
print('PASS: per-TypeID JSON migration, scoped collisions, aliases, separated entity hashes, legacy preservation and invalid-file recovery')
