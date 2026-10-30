local I=require('install');local F=require('preset_files');local J=require('json_data');local R=require('record_names')
local dir=TEST_WORK..'/names';I.mkdirs(dir)
local _,errors=R.load(dir);assert(#errors==0,errors[1])
local function ordered(raw,keys)
 local last=0
 for _,key in ipairs(keys)do
  local at=assert(raw:find('"'..key..'":',1,true),'missing '..key)
  assert(at>last,'wrong numerical order at '..key);last=at
 end
end
-- Newly seeded files must use numeric order, including zero and the uint32 limit.
R.seed('damage',{[0]='zero',[1]='one',[2]='two',[10]='ten',[11]='eleven',[100]='hundred',[4294967295]='last'})
ordered(assert(F.read(R.folder..'/damage.json')),{'0','1','2','10','11','100','4294967295'})
-- Existing files must be reordered on load even without new records; preserve values and metadata.
local path=R.folder..'/damage.json'
local data={type='damage',version=1,annotation='preserve me',names={['1']='一',['2']='二',['10']='十',['11']='十一',['100']='一百'}}
local legacy=J.encode(data,true);assert(F.write(path,legacy))
R.reload();assert(#R.errors==0,R.errors[1])
local raw=assert(F.read(path));ordered(raw,{'1','2','10','11','100'})
assert(raw~=legacy and J.encode(J.decode(raw))==J.encode(data),'reordering changed JSON values')
assert(R.name('damage',2)=='二'and R.name('damage',100)=='一百')
R.reload();assert(F.read(path)==raw,'sorted JSON must remain stable on repeated loads')
-- Alternate hexadecimal keys and records-array input also follow their numeric index.
assert(F.write(path,J.encode({type='damage',names={['100']='a',['0x2']='b',['10']='c'}})))
R.reload();assert(#R.errors==0,R.errors[1]);ordered(F.read(path),{'0x2','10','100'})
local array_path=R.folder..'/extra.json'
assert(F.write(array_path,J.encode({type='extra',records=J.array({{index=100,name='a'},{index=2,name='b'},{index=10,name='c'}})})))
R.reload();assert(#R.errors==0,R.errors[1])
local rows=J.decode(F.read(array_path)).records
assert(rows[1].index==2 and rows[2].index==10 and rows[3].index==100)
-- Invalid JSON anywhere prevents sorting other files in that load.
assert(F.write(path,legacy));assert(F.write(R.folder..'/eagle.json','{broken'))
local _,bad=R.reload();assert(#bad==1 and F.read(path)==legacy)
-- Default JSON object encoding elsewhere keeps its original lexicographic order.
local default=J.encode({['1']='',['2']='',['10']=''})
assert(default:find('"10":',1,true)<default:find('"2":',1,true))
print('PASS: numeric TypeID JSON order on seed/load, uint32/hex keys, records arrays, stable rewrites, preserved names/metadata and invalid-file protection')
