local W=require('startup_work');local clock,n,slices=0,0,0;local progress={}
local function now()return clock end
local function work()for i=1,100 do W.checkpoint();n=n+1;clock=clock+1 end end
repeat
 local before=n;local done=W.run(progress,clock+4,now,work);slices=slices+1
 assert(n-before<=4 and n>before,'work did not respect the batch deadline')
 assert(not W.active,'yield leaked the active startup context')
 if done then break end
until false
assert(n==100 and slices==25)
W.checkpoint() -- ordinary page editing must not try to yield
local ok,why=pcall(W.run,{},clock+1,now,function()error('fixture startup failure')end)
assert(not ok and why:find('fixture startup failure',1,true)and not W.active)
print('PASS: startup yields between bounded batches, preserves progress and propagates errors; normal editing does not yield')
