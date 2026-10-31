-- Native controller state machine, with process/Steam calls replaced in-memory.
local S=require('steam_integration');local I=require('install')
local original_running,original_game,original_time=S.running,I.game_running,os.time
local undo={}
local function replace(fn,key,value)
 for n=1,100 do
  local name,old=debug.getupvalue(fn,n);if not name then break end
  if name==key then undo[#undo+1]=function()debug.setupvalue(fn,n,old)end;debug.setupvalue(fn,n,value);return end
 end
 error('missing controller dependency '..key)
end
local running,game,now=true,false,100
local calls={};local fail_start=false
local model={pending=nil}
function model:run(operation)self.inspected=operation;return{state='needed',message='needed'}end
function model:repair()self.repaired=(self.repaired or 0)+1;return{state='ready',message='ready'}end
function model:restore()self.restored=(self.restored or 0)+1;return{state='restored',message='restored'}end
function model:poll()return{state='ready',message='ready'}end
replace(S.restart_and_repair,'resolve',function()return{root='/test/Steam',account='123'}end)
replace(S.restart_and_repair,'instance',function()return model end)
replace(S.restart_and_repair,'native_start',function(root,args)calls[#calls+1]={root,args};return not fail_start end)
S.running=function()return running end;I.game_running=function()return game end;os.time=function()return now end
game=true;assert(not S.restart_and_repair()and #calls==0,'shutdown while game running')
game=false;assert(S.restart_and_repair());assert(calls[1][2]=='-shutdown')
assert(S.poll(true,true).state=='restarting')
running=false;assert(S.poll(true,true).state=='ready'and model.repaired==1 and calls[2][2]=='-silent')
-- Restoration also waits for clean shutdown, then restarts the client.
running=true;model.pending='restore';assert(S.restart_and_repair()and model.inspected=='restore')
running=false;assert(S.poll(false,true).state=='restored'and model.restored==1 and calls[#calls][2]=='-silent')
-- Refused shutdown times out; no kill and no configuration action.
running=true;model.pending=nil;assert(S.restart_and_repair());local count=#calls
now=146;assert(S.poll(true,true).state=='error'and #calls==count and model.repaired==1)
model.run=function()return{state='conflict',message='foreign wrapper'}end
assert(not S.restart_and_repair()and #calls==count,'restarted on conflicting configuration')
for n=#undo,1,-1 do undo[n]()end
S.running,I.game_running,os.time=original_running,original_game,original_time
print('PASS Steam restart controller: game guard, normal shutdown/wait, repair/restore, reopen, timeout without kill, conflict skip; no client/process changes')
