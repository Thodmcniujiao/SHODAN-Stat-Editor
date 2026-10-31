local M=require('install_state');local J=require('json_data')
local disk={};local fs={read=function(p)return disk[p]end,write=function(p,s)disk[p]=s;return true end,
 move=function(a,b)disk[b],disk[a]=disk[a],nil;return true end,remove=function(p)disk[p]=nil;return true end}
local current={tables={health='125'},passives='',codes='',names='',demolition='',preload='',physics=''}
local identity='game-build-a';local revision=0
local function copy(v)return J.decode(J.encode(v))end
local function options()return{path='state.json',fs=fs,identity=function()return identity end,
 snapshot=function()return copy(current)end,empty=function()return{tables={},passives='',codes='',names='',demolition='',preload='',physics=''}end}end
local s=M.new(options());s:read_baseline();assert(not s:pending(revision))
current.tables.health='99999';revision=revision+1;assert(s:pending(revision))
current.tables.health='125';revision=revision+1;assert(not s:pending(revision),'A -> B -> A remained dirty')
for _,category in ipairs({'passives','codes','names','demolition','preload','physics'})do
 current[category]='edit';revision=revision+1;assert(s:pending(revision),category)
 current[category]='';revision=revision+1;assert(not s:pending(revision),category..' undo')
end
current.tables.health='99999';assert(s:committed());assert(not s:pending(revision))
s=M.new(options());s:read_baseline();assert(not s:pending(0),'verified installed baseline did not survive reopening')
current.tables.health='125';assert(s:pending(1),'Reset to original must differ from installed 99999')
-- A failed transaction must never call committed, so its last successful baseline stays intact.
current.tables.health='77777';assert(s:pending(2));current.tables.health='99999';assert(not s:pending(3))
identity='game-build-b';current.tables.health='125';s=M.new(options());s:read_baseline();assert(not s:pending(0))
current.preload='staged';assert(s:pending(1));s:restored();current.preload='';s:read_baseline();assert(not s:pending(2))
print('PASS: actual content equality, scalar/auxiliary undo, installed versus original, reopen, failed install baseline, game update and restore')
