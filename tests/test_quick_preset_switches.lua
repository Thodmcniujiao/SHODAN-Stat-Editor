local Q=require('quick_modifications');local J=require('json_data');local Merge=require('preset_merge')
local hash='0000000000000001'
local values,defaults={health=777,zone=50,stims=4},{health=125,zone=50,stims=4}
local undo={};local saved=0
local function t(id,target)return{key=hash..'/'..id,id=id,target=target}end
local targets={god={t('health',99999),t('zone',99999)},stims={t('stims',99)}}
local m=Q.new{targets=function(id)return targets[id]end,read=function(t)return values[t.id]end,
 default=function(t)return defaults[t.id]end,valid=function(_,v)return type(v)=='number'end,
 restore=function()return undo end,set_restore=function(v)undo=v end,
 write=function(t,v)values[t.id]=v;return true end,persist=function()saved=saved+1;return true end}
assert(Q.valid_switches({god=true,stims=false})and Q.valid_switches({}))
assert(not Q.valid_switches({god='on'})and not Q.valid_switches({unknown=true})and not Q.valid_switches(false))
assert(m:toggle('god'));assert(m:toggle('stims'))
local raw={{hash=hash,id='health',value=99999},{hash=hash,id='zone',value=99999},{hash=hash,id='stims',value=99},
 {hash=hash,id='unrelated',value=123}}
local game={stacks={},own_off={},quick_restore=undo}
local projected,g=assert(m:capture(raw,game))
assert(#projected==2 and #raw==4 and game.quick_restore==undo,'capture mutated runtime/cache values')
local by_id={};for _,v in ipairs(projected)do by_id[v.id]=v.value end
assert(by_id.health==777 and by_id.unrelated==123 and by_id.zone==nil and by_id.stims==nil)
assert(g.quick_switches.god==true and g.quick_switches.stims==true and g.quick_restore==nil)
assert(not J.encode(g):find('99999',1,true)and not J.encode(g):find(hash,1,true),'recipe effects or undo fields serialized')
-- The same logical preset resolves an additional body part in a newer layout.
assert(m:toggle('god',false));assert(m:toggle('stims',false));assert(values.health==777)
values.health=125;values.new_part=88;defaults.new_part=88;targets.god[#targets.god+1]=t('new_part',99999)
values.health=by_id.health
local writes=saved;assert(m:apply_switches(g.quick_switches,true))
assert(values.health==99999 and values.zone==99999 and values.new_part==99999 and values.stims==99)
assert(saved==writes,'preset staging persisted a half-applied transaction')
assert(m:apply_switches({god=false},false));assert(values.health==777 and values.new_part==88 and values.stims==99)
-- Off precedes explicit manual values; the missing switch in a patch remains unchanged.
values.health=321;assert(m:apply_switches({god=false},true));assert(values.health==321 and values.stims==99)
assert(not m:apply_switches({god=1},true))
local p={scope='global',kind='snapshot',values=projected,data={version=3,game=g}}
local target={scope='global',kind='snapshot',values={},data={version=3,game={stacks={},own_off={},quick_switches={god=false,stims=false}}}}
local ref={store='game',key='quick_switches',id='god'}
local plan=Merge.plan(p,target,{ref});assert(plan.payload.data.game.quick_switches.god==true)
assert(plan.payload.data.game.quick_switches.stims==false and #plan.payload.values==0,'merging a switch copied recipe effects or other settings')
assert(Merge.get(target,ref)==false,'an explicit off state became missing')
local off=Merge.plan(target,p,{ref});assert(off.payload.data.game.quick_switches.god==false)
assert(off.payload.data.game.quick_switches.stims==true,'off merge changed another switch')
local c={by_hash={},navigation={{id='features',name={'Quick modifications','快速修改','快速修改'},
 subs={{name={'Player','玩家主体','玩家主體'},quick=true}}}},lang=function()return'zh-Hans'end,tr=function(v)return v end}
local preview=require('preset_details').build(p,c);local page=preview[1]
assert(page.id=='features'and page.count==2 and #page.sections==1 and page.sections[1].id==Q.PRESET_TAB)
for _,row in ipairs(page.sections[1].rows)do
 assert(row.value=='开启'and row.baseline=='关闭'and row.changed and row.ref.key=='quick_switches'and row.jump.quick==row.id)
end
assert(require('global_preset').count({values={},data={game=g}})==2,'saved switches not counted')
print('PASS quick preset switches: logical states, manual baselines, new-layout targets, off/apply order, independent patch/merge, preview and counts')
