for _,name in ipairs({'demolition','demolition_panel','demolition_bridge','unit_aliases','entity_assets','host','hostdata','gamedata','install','engine_shim','update'})do
 assert(loadfile(TEST_ROOT..'/offline/'..name..'.lua'))
end
assert(loadfile(TEST_ROOT..'/src/stat_editor_offline.lua'))
print('PASS: all offline modules and the original panel compile with the bundled LuaJIT')
