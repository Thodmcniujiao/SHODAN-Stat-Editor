-- Existing component regression cases use test labels to remember named library IDs.
-- This helper is not shipped; the production quick-slot API has been removed.
local M={ids={}}
local function key(weapon,label)return weapon.hash..'/'..label end
function M.save(E,weapon,label)
 local scope=weapon.save_loadout and'loadout'or(weapon.preload_parameters or weapon.custom_preset)and rawget(_G,'SHODAN_PRELOAD_MODEL')and'preload'or'game'
 assert(E.presets.select_scope(scope));local id=assert(E.presets.new_full_preset());assert(E.presets.finish_rename(false))
 M.ids[key(weapon,label)]=id;return id
end
function M.load(E,weapon,label)
 local id=assert(M.ids[key(weapon,label)]);local p=assert(E.presets.library:get(id));assert(E.presets.select_scope(p.scope));return assert(E.presets.load_full_preset(id))
end
function M.values(E,weapon,label)
 local p=assert(E.presets.library:get(assert(M.ids[key(weapon,label)])))
 local out={};for _,v in ipairs(p.values)do if v.hash==weapon.hash then out[#out+1]=v end end;return out
end
function M.delete(E,weapon,label)
 local id=assert(M.ids[key(weapon,label)]);local p=assert(E.presets.library:get(id));assert(E.presets.select_scope(p.scope))
 assert(E.presets.confirm('delete',id));assert(E.presets.confirm('delete',id));M.ids[key(weapon,label)]=nil
end
function M.get(E,weapon,label)local id=M.ids[key(weapon,label)];return id and E.presets.library:get(id)end
return M
