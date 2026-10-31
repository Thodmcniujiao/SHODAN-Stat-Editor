local S=require('preload_store');local D=require('demolition');local F=require('preset_files');local I=require('install')
I.mkdirs(TEST_WORK)
local path=TEST_WORK..'/preload.json';local o={path=path,load=function()error('no resource reads expected')end}
local m=S.new(o);assert(m:mutate(function()m.cfg.selected.A=true end));assert(m:mutate(function()m.cfg.selected.B=true end))
local bak=assert(F.read(path..'.bak'));assert(F.write(path,'truncated'))
local recovered=S.new(o);assert(recovered.cfg.selected.A and not recovered.cfg.selected.B)
assert(recovered:save());assert(F.read(path..'.corrupt')=='truncated'and F.read(path..'.bak')==bak)
local demo=TEST_WORK..'/demolition.txt';local id='EEF85D6CF58E31D70'
assert(D.save_overrides(demo,{[id]={['0:normal']=123}}));assert(D.save_overrides(demo,{[id]={['0:normal']=456}}))
assert(F.write(demo,'# SHODAN independent entity demolition overrides v1\ntruncated row'))
local values=D.load_overrides(demo);assert(values[id]['0:normal']==123)
assert(D.save_overrides(demo,values));assert(F.read(demo..'.corrupt'):find('truncated row',1,true))
print('PASS: JSON preload and demolition store previous-revision recovery and damaged-input preservation')
