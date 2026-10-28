local ffi=require('ffi');local I=require('install');local D=require('demolition');local G=require('gamedata')
local S=require('preload_store');local IO=require('preload_io');local UA=require('unit_aliases');local H=require('hostdata')
I.mkdirs(TEST_WORK);I.mkdirs(I.home)
local raw=assert(os.getenv('SHODAN_PRELOAD_RAW'),'raw package fixture directory required')
local reader=IO.new({raw=raw,game=TEST_GAME,owned=function()return{}end})
local model=S.new({path=TEST_WORK..'/preload.json',load=function(h)return reader:load(h)end})
local arctic='7371C64D957E5C74';local desert='324E128327AC29AB'
local base=model:original(arctic);local entries=S.parse_package(base)
assert(S.package_bytes(base,entries)==base,'no-op package roundtrip differs')
assert(S.input_hash('18446744073709551615')=='FFFFFFFFFFFFFFFF')
assert(S.input_hash('8318648023252884596')==arctic)
local original_count=#entries
assert(model:edit_entry(arctic,#entries+1,'texture 0xFFFFFFFFFFFFFFFF'))
assert(#model:entries(arctic)==original_count+1)
assert(model:edit_entry(arctic,1,'unit content/test/example'))
assert(model:entries(arctic)[1].type==S.hash('unit'))
assert(model:edit_entry(arctic,#model:entries(arctic),'-'));assert(#model:entries(arctic)==original_count)
assert(model:preset('save',arctic,1,'package'));assert(model:reset('package',arctic));assert(model:entries(arctic)[1].type==entries[1].type)
assert(model:preset('load',arctic,1,'package'));assert(model:entries(arctic)[1].type==S.hash('unit'))
assert(model:reset('all'));assert(model:toggle('selected',desert,true))
assert(model:mutate(function()model.cfg.targets={[arctic]=true}end))
local outputs=model:package_outputs();local merged=S.parse_package(outputs[arctic]);local present={}
for _,e in ipairs(merged)do assert(not present[e.type..e.name],'merge duplicate');present[e.type..e.name]=true end
for _,e in ipairs(entries)do assert(present[e.type..e.name],'original arctic resource removed')end
for _,e in ipairs(model:entries(desert))do if e.type~=S.PTYPE then assert(present[e.type..e.name],'desert resource missing')end end
assert(#merged>original_count,'cross-environment resources not appended')
local writes,report=reader:prepare(model,{},{});assert(next(writes)and #report>0)
for name,bytes in pairs(writes)do if name:match('%.patch_%d+$')then
 local resources=UA.read_archive(bytes,writes[name..'.gpu_resources'],writes[name..'.stream'])
 assert(resources[D.unhex(arctic)..D.unhex(S.PTYPE)].main==outputs[arctic])
 local f=assert(io.open(TEST_WORK..'/'..name,'wb'));f:write(bytes);f:close()
end end
local loaded=S.new({path=TEST_WORK..'/preload.json',load=function(h)return reader:load(h)end})
assert(loaded.cfg.selected[desert]and loaded.cfg.targets[arctic])
-- All-package closure: finite despite boot referring back into its own descriptor graph.
assert(model:select_many(S.keys(model.catalog),true));local all,packages=model:expand(model.cfg.selected)
assert(#packages==3632,#packages);assert(#all>10000,#all)
print('all package closure',#packages,'packages',#all,'unique leaf resources')
assert(model:reset('all'))
assert(model:toggle('selected',desert,true));assert(model:mutate(function()model.cfg.merge_enabled=false;model.cfg.targets={}end))
assert(not next(model:package_outputs()),'array-only mode unexpectedly generated merge patches')
assert(model:reset('all'))
-- Respect an existing ordinary mod and combine with the entity-alias patch transaction.
local fake=TEST_WORK..'/fake/data/game';I.mkdirs(fake)
local third=TEST_WORK..'/fake/data/9ba626afa44a3aa3.patch_2'
local third_entries=S.parse_package(base);third_entries[#third_entries+1]={type=S.hash('texture'),name='FFFFFFFFFFFFFFFF'}
local third_raw=S.package_bytes(base,third_entries)
local third_archive=UA.archive({{name=D.unhex(arctic),type=D.unhex(S.PTYPE),main=third_raw}})
local f=assert(io.open(third,'wb'));f:write(third_archive.main);f:close()
local combined_io=IO.new({raw=raw,game=fake,owned=function()return require('entity_assets').owned()end})
local combined=S.new({load=function(h)return combined_io:load(h)end})
assert(#combined:entries(arctic)==#entries+1,'third-party package overlay was ignored')
combined.cfg.targets={[arctic]=true};combined.cfg.selected={[desert]=true}
local alias_key=D.hash_resource('shodan/test/alias')
local alias_archive=UA.archive({{name=alias_key,type=D.hash_resource('unit'),main='unit',gpu='gpu',stream='stream'}})
local alias_name='9ba626afa44a3aa3.patch_3'
local combined_writes=combined_io:prepare(combined,{[alias_name]=alias_archive.main,[alias_name..'.gpu_resources']=alias_archive.gpu,[alias_name..'.stream']=alias_archive.stream},{})
local merged_resources=UA.read_archive(combined_writes[alias_name],combined_writes[alias_name..'.gpu_resources'],combined_writes[alias_name..'.stream'])
assert(merged_resources[alias_key..D.hash_resource('unit')].gpu=='gpu','unit alias GPU lost')
local present={};for _,e in ipairs(S.parse_package(merged_resources[D.unhex(arctic)..D.unhex(S.PTYPE)].main))do present[e.type..e.name]=true end
assert(present[S.hash('texture')..'FFFFFFFFFFFFFFFF'],'third-party addition lost during merge')
local A=require('entity_assets');I.game_running=function()return false end
local transaction=A.begin(fake,combined_writes);assert(transaction:activate());assert(transaction:commit())
assert(I.read(third)==third_archive.main,'unowned mod overwritten')
local restore=A.begin(fake,{});assert(restore:activate());assert(restore:commit())
assert(I.read(third)==third_archive.main and not I.read(TEST_WORK..'/fake/data/'..alias_name),'restore removed third-party data or retained own patch')
-- Real empty EnvironmentSettings array grows inside its own block and survives sealing.
local original={};local names={'generated_environment_settings.dl_bin'}
for _,name in ipairs(names)do original[name]=assert(I.read(TEST_GAME..'/'..name))end
assert(#H.load(TEST_GAME,original)==0)
local file=H.files[names[1]];local hs=G.headers(file.p,file.n);local h=hs[1]
assert(h.type==0x68E17506)
local key='environment-test';model:register_array(key,{file=names[1],root=h.type,ordinal=1,offset=504},{})
assert(model:set_array(key,{arctic,desert}))
local types=assert(I.read(TEST_FIXTURES..'/dl_library.dl_typelib'));local schemas=D.schemas(types)
model.cfg.arrays[key].spec.offset=40
assert(not pcall(function()model:apply_arrays({},H,schemas)end),'accepted a redirected array descriptor')
model.cfg.arrays[key].spec.offset=504
local changes={};model:apply_arrays(changes,H,schemas);assert(#changes==1)
local before=ffi.string(changes[1].plain,changes[1].n)
local ph=G.headers(changes[1].plain,changes[1].n)[1];local P=ph.at+24
local ptr=D.u32(before,P+504);assert(D.u32(before,P+512)==2)
assert(D.hex(before:sub(P+ptr+1,P+ptr+8))==arctic)
assert(D.hex(before:sub(P+ptr+9,P+ptr+16))==desert)
local cipher,why=H.build(changes[1]);assert(cipher,why)
local back,n=G.open_sealed(cipher);assert(back and G.murmur64(back,n)==file.hash);G.free(back)
print('PASS: package add/edit/delete, exact IDs, persistence/presets, cross-environment leaf merge, all-package closure, triad readback, empty DL array growth and authenticated build; no game writes')
