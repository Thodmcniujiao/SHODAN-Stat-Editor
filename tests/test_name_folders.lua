local I=require('install');local F=require('preset_files');local J=require('json_data')
local N=require('entity_names');local IDs=require('name_ids')
I.mkdirs(TEST_WORK)
assert(IDs.hex('18446744073709551615')=='FFFFFFFFFFFFFFFF')
assert(IDs.decimal('FFFFFFFFFFFFFFFF')=='18446744073709551615')
assert(IDs.hex('17842374123104475103')=='F79CD8BB654397DF')
assert(not IDs.hex('18446744073709551616'))
assert(IDs.index('0x120')=='288'and IDs.index('00000288')=='288')
assert(not IDs.index('0xF79CD8BB654397DF'))
local folder=TEST_WORK..'/EntityNames'
local cfg={default_category='other',categories={{id='bugs',name={en='Bugs',['zh-Hans']='虫族'},order=1},
 {id='other',name='other',order=2}},entities={F79CD8BB654397DF={name='legacy design name'}},hash_names={FFFFFFFFFFFFFFFF='old hash name'}}
local rows={{id='EF79CD8BB654397DF',hash='F79CD8BB654397DF',category='bugs',base_name='Alpha',kind='entity'}}
local t=N.open(folder,cfg,rows)
assert(t.entities.EF79CD8BB654397DF.name=='legacy design name')
assert(t.entities.EFFFFFFFFFFFFFFFF.name=='old hash name')
assert(F.read(folder..'/未分类.json'))
assert(F.write(folder..'/新实体组.json',J.encode({group='新实体组',entities={{hash='9007199254740993',name='精确十进制哈希'}}})))
t=N.open(folder,cfg,rows)
assert(t.entities.E0020000000000001.name=='精确十进制哈希')
assert(t.entities.E0020000000000001.category~='bugs')
rows[#rows+1]={id='E0000000000000002',hash='0000000000000002',category='bugs',base_name='new after game update',kind='entity'}
t=N.open(folder,cfg,rows)
assert(t.entities.E0000000000000002.category=='other','new hashes must go into unclassified JSON')
assert(F.write(folder..'/重复组.json',J.encode({entities={{hash='0xF79CD8BB654397DF',name='duplicate'}}})))
local ok,why=pcall(N.load,folder);assert(not ok and tostring(why):find('duplicate hash',1,true))
assert(F.remove(folder..'/重复组.json'))
assert(N.load(folder).entities.EF79CD8BB654397DF.name=='legacy design name')
print('PASS: exact uint64 hex/decimal, group JSON migration, Unicode names/files, new groups/unclassified entities, duplicate rejection')
