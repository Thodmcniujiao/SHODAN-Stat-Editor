for _,name in ipairs({'demolition','demolition_panel','demolition_bridge','health_components','drown_components','shield_components','component_view','throwable_components','thrower_components','minefield_components','mine_spawner_components','faction_components','mount_components','inventory_components','sensor_eye_components','turret_components','eagle_components','eagle_spawner_components','weapon_components','stratagem_components','damage_components','projectile_components','explosion_components','arc_components', 'beam_components', 'status_components','entity_catalog','json_data','unit_aliases','entity_assets','host','hostdata','gamedata','install','engine_shim','update'})do
 assert(loadfile(TEST_ROOT..'/offline/'..name..'.lua'))
end
assert(loadfile(TEST_ROOT..'/src/stat_editor_offline.lua'))
print('PASS: all offline modules and the original panel compile with the bundled LuaJIT')
assert(loadfile(TEST_ROOT..'/offline/orbital_components.lua'))
