local Q=require('quick_modifications');local J=require('json_data')
local values={health=125,zone=50,stims=4};local original={health=125,zone=50,stims=4}
local restore={};local calls,fail_at=0;local persist_fail=false;local enabled=true
local function target(id,value)return{key='0000000000000001/'..id,id=id,target=value}end
local lists={god={target('health',99999),target('zone',99999)},stims={target('stims',99)}}
local c={targets=function(id)return lists[id]end,restore=function()return restore end,set_restore=function(v)restore=v end,
 read=function(t)return values[t.id]end,default=function(t)return original[t.id]end,enabled=function()return enabled end,
 valid=function(_,v)return v%1==0 and v>=0 and v<=2147483647 end,
 write=function(t,v)calls=calls+1;values[t.id]=v;if calls==fail_at then return nil,'write failure'end;return true end,
 persist=function()if persist_fail then persist_fail=false;return nil,'disk failure'end;return true end}
local m=Q.new(c);assert(not m:state('god').active)
assert(m:toggle('god'));assert(values.health==99999 and values.zone==99999 and m:state('god').active)
assert(restore.god['0000000000000001/health']==125)
assert(m:toggle('stims'));assert(values.stims==99)
-- A fresh model uses portable restore metadata, with no independent enabled flag.
restore=J.decode(J.encode(restore));m=Q.new(c);assert(m:state('god').active and m:state('stims').active)
assert(m:toggle('god'));assert(values.health==125 and values.zone==50 and not restore.god)
assert(values.stims==99 and m:state('stims').active)
-- A manual change is kept when reapplying a partially customized recipe.
assert(m:toggle('god'));values.zone=888;assert(m:state('god').custom and not m:state('god').active)
assert(m:toggle('god'));assert(m:toggle('god'));assert(values.health==125 and values.zone==888)
assert(m:toggle('god'));values.zone=777;assert(m:toggle('god',false))
assert(values.health==125 and values.zone==777 and restore.god==nil,'page reset clobbered a manual field or kept owned targets')
values.zone=50
-- Imported matching values without an undo snapshot reset to original defaults.
values.health,values.zone=99999,99999;assert(m:toggle('god'));assert(values.health==125 and values.zone==50)
local before=J.encode(restore);calls,fail_at=0,2
assert(not m:toggle('god'));assert(values.health==125 and values.zone==50 and J.encode(restore)==before)
fail_at=nil;persist_fail=true;assert(not m:toggle('god'))
assert(values.health==125 and values.zone==50 and J.encode(restore)==before,'disk failure did not restore fields/context')
local writer=c.write
c.write=function(t,v)if t.id=='zone'and v==99999 then error('exception during write')end;return writer(t,v)end
assert(not m:toggle('god'));assert(values.health==125 and values.zone==50 and J.encode(restore)==before)
c.write=writer
enabled=false;assert(not m:toggle('god'));enabled=true
assert(not m:toggle('unknown'));assert(not m:state('unknown').available)
assert(Q.valid_restore(restore)and not Q.valid_restore({god={bad=5}}))
assert(not Q.valid_restore({god={['0000000000000001/health']=math.huge}}))
local source={data={game={quick_restore={god={['0000000000000001/health']=222,['0000000000000001/zone']=333}}}}}
local dest={data={game={quick_restore={god={['0000000000000001/health']=111}}}}}
Q.merge_restore(dest,source,{hash='0000000000000001',ids={'zone'}})
assert(dest.data.game.quick_restore.god['0000000000000001/health']==111)
assert(dest.data.game.quick_restore.god['0000000000000001/zone']==333)
print('PASS quick recipes: fixed finite values, separate switches, restore snapshots, manual edits, derived gold state, portable restart/merge, atomic write and disk rollback')
