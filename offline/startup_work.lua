-- Cooperative startup work. Outside startup, checkpoints are no-ops.
local M={}
function M.checkpoint()
 local active=M.active
 if active and active.now()>=active.deadline then coroutine.yield()end
end
function M.run(progress,deadline,now,work)
 if now()>=deadline then return false end
 local thread=progress.startup_thread
 if not thread then thread=coroutine.create(work);progress.startup_thread=thread end
 M.active={now=now,deadline=deadline}
 local ok,why=coroutine.resume(thread)
 M.active=nil
 if not ok then error(debug.traceback(thread,tostring(why)),0)end
 if coroutine.status(thread)~='dead'then return false end
 return true
end
return M
