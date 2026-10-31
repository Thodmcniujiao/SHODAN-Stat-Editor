-- All offline user data belongs to this copy of the program. Resolve the module's
-- location, never the working directory or a Windows user-profile directory.
local ffi = require('ffi')
pcall(ffi.cdef, 'uint32_t GetFullPathNameA(const char *path, uint32_t size, char *out, char **file);')
local function absolute(path)
    local out = ffi.new('char[32768]')
    local n = ffi.C.GetFullPathNameA(path, 32768, out, nil)
    assert(n > 0 and n < 32768, 'Cannot resolve portable data directory: ' .. path)
    return ffi.string(out, n):gsub('\\', '/'):gsub('/+$', '')
end
local source = assert(debug.getinfo(1, 'S').source:match('^@(.+)$'), 'User paths require a file location')
local directory = absolute(source):match('^(.*)/[^/]+$')
-- Release: <program>/app/user_paths.lua. Source checkout: offline/user_paths.lua.
local root = directory:gsub('/app$', '')
local data = absolute(rawget(_G, 'SHODAN_DATA_DIRECTORY') or (root .. '/Data'))
return {root=root, home=data, logs=data .. '/Logs', presets=root .. '/Presets', names=root .. '/Names'}
