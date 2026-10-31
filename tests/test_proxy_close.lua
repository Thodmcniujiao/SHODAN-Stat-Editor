local N=require('network_proxy')
local original_status,original_stop=N.status,N.stop
local inspected,stopped=0,0
N.status=function()inspected=inspected+1;return{alive=true}end
N.stop=function()stopped=stopped+1;return true end
assert(N.editor_closed(false)and N.editor_closed(nil))
assert(inspected==0 and stopped==0,'default exit inspected or stopped the proxy')
assert(N.editor_closed(true)and stopped==1,'enabled exit did not stop a live proxy')
N.status=function()return{alive=false,starting=true}end
assert(N.editor_closed(true)and stopped==2,'starting owned proxy survived enabled exit')
N.status=function()return{alive=false,starting=false}end
assert(N.editor_closed(true)and stopped==2,'exit touched an inactive proxy')
N.status=function()return{alive=true}end
N.stop=function()return nil,'cannot write stop request'end
local ok,why=N.editor_closed(true)
assert(not ok and why=='cannot write stop request','stop failure was hidden')
N.status,N.stop=original_status,original_stop
print('PASS proxy exit policy: default keep, live/start stop, inactive skip, failure reporting')
