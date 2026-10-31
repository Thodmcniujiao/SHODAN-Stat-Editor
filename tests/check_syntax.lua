for _,name in ipairs({'demolition','demolition_panel','demolition_bridge','health_components','drown_components','shield_components','component_view','throwable_components','thrower_components','minefield_components','mine_spawner_components','faction_components','mount_components','inventory_components','sensor_eye_components','turret_components','eagle_components','eagle_spawner_components','weapon_components','stratagem_components','damage_components','projectile_components','explosion_components','arc_components', 'beam_components', 'status_components','entity_catalog','json_data','record_names','unit_aliases','entity_assets','host','hostdata','gamedata','install','engine_shim','update'})do
 assert(loadfile(TEST_ROOT..'/offline/'..name..'.lua'))
end
assert(loadfile(TEST_ROOT..'/src/stat_editor_offline.lua'))
assert(loadfile(TEST_ROOT..'/offline/orbital_components.lua'))
assert(loadfile(TEST_ROOT..'/offline/identity_components.lua'))
assert(loadfile(TEST_ROOT..'/offline/preload_components.lua'))
assert(loadfile(TEST_ROOT..'/offline/preload_data.lua'))
for _,name in ipairs({'preload_store','preload_io','preload_authoring','archives','game_texts','physics','enemy_anim'})do assert(loadfile(TEST_ROOT..'/offline/'..name..'.lua'))end
assert(loadfile(TEST_ROOT..'/offline/planet_components.lua'))
assert(loadfile(TEST_ROOT..'/offline/planet_data.lua'))
for _,name in ipairs({'player_save','player_save_io','player_save_view'})do assert(loadfile(TEST_ROOT..'/offline/'..name..'.lua'))end
for _,name in ipairs({'preset_library','preset_files','preset_controller','preset_panel','editor_footer'})do assert(loadfile(TEST_ROOT..'/offline/'..name..'.lua'))end
for _,name in ipairs({'modifier_components','modifier_data','mission_components','hellpod_components','spawn_components','enemy_components','ai_components'})do assert(loadfile(TEST_ROOT..'/offline/'..name..'.lua'))end
assert(loadfile(TEST_ROOT..'/offline/typeid_groups.lua'))
assert(loadfile(TEST_ROOT..'/offline/component_records.lua'))
assert(loadfile(TEST_ROOT..'/offline/spawn_queue_components.lua'))
assert(loadfile(TEST_ROOT..'/offline/health_schema.lua'))
assert(loadfile(TEST_ROOT..'/offline/global_preset.lua'))
assert(loadfile(TEST_ROOT..'/offline/preset_details.lua'))
assert(loadfile(TEST_ROOT..'/offline/stratagem_entity_editor.lua'))
assert(loadfile(TEST_ROOT..'/offline/stratagem_entity_specs.lua'))
for _,name in ipairs({'name_ids','entity_names'})do assert(loadfile(TEST_ROOT..'/offline/'..name..'.lua'))end
assert(loadfile(TEST_ROOT..'/offline/vehicle_tips.lua'))
assert(loadfile(TEST_ROOT..'/offline/numeric_policy.lua'))
assert(loadfile(TEST_ROOT..'/offline/creature_components.lua'))
assert(loadfile(TEST_ROOT..'/offline/creature_component_specs.lua'))
assert(loadfile(TEST_ROOT..'/offline/component_names.lua'))
assert(loadfile(TEST_ROOT..'/offline/reference_component_names.lua'))
assert(loadfile(TEST_ROOT..'/offline/startup_work.lua'))
assert(loadfile(TEST_ROOT..'/offline/weapon_component_groups.lua'))
assert(loadfile(TEST_ROOT..'/offline/field_baselines.lua'))
assert(loadfile(TEST_ROOT..'/offline/installed_values.lua'))
assert(loadfile(TEST_ROOT..'/offline/parameter_preferences.lua'))
print('PASS: all offline modules and the original panel compile with the bundled LuaJIT')
