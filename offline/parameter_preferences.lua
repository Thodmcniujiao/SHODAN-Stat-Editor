-- Presentation preferences, separate from staged/installed game changes. Keys use
-- component type + record-relative field locations, never native addresses or indices.
local J = require('json_data')
local M = {}
function M.identity(page, row, tables, kinds)
    local parts, kinds_seen = {}, {}
    for _, p in ipairs(row.parts or {}) do
        local f = p.field
        local t = f and tables[f.kind]
        local spec = f and kinds[f.kind]
        local layout = t and t.records_layout
        local relative
        if layout and type(f.offset) == 'number' and f.offset >= layout.data_offset
            and f.offset < layout.data_offset + layout.record_count * layout.stride then
            relative = (f.offset - layout.data_offset) % layout.stride
        elseif t and spec and type(f.offset) == 'number' then
            local owner = p.health_owner and p.health_owner.weapon or page
            local at = t.index and t.index[owner.key or page.key or false]
            if at and spec.stride and f.offset >= at and f.offset < at + spec.stride then relative = f.offset - at
            elseif not spec.keyed and spec.stride and t.entries and f.offset >= 16
                and f.offset < 16 + t.entries * spec.stride then relative = (f.offset - 16) % spec.stride end
        end
        if f then kinds_seen[tostring(f.kind)] = true end
        if relative then
            parts[#parts + 1] = string.format('%08X/+%X/%s/%s', f.kind, relative, f.storage,
                f.mask or (f.bit_bytes and (f.bit_bytes .. ':' .. f.bit_shift .. ':' .. f.bit_width)) or '')
        else parts = nil; break end
    end
    if parts and #parts > 0 then return table.concat(parts, '|') end
    local scope = {}
    for kind in pairs(kinds_seen) do scope[#scope + 1] = kind end
    table.sort(scope)
    return table.concat(scope, ',') .. '/' .. tostring(row.component or page.component_view or page.catalog_tab or page.slot)
        .. '/' .. tostring(row.section) .. '/' .. tostring(row.id)
end
function M.new(c)
    local fs = c.fs or require('preset_files')
    local self = { path = c.folder .. '/parameter_preferences.json', entries = {}, revision = 0 }
    local keys = setmetatable({}, { __mode = 'k' })
    local raw = fs.read(self.path)
    if raw then
        local ok, data = pcall(J.decode, raw)
        if not ok or type(data) ~= 'table' or data.version ~= 1 or type(data.parameters) ~= 'table' then
            self.error = 'Cannot read parameter_preferences.json; preserve and repair this file before saving.'
        else
            for key, value in pairs(data.parameters) do
                if type(key) == 'string' and type(value) == 'table' then
                    local name = type(value.name) == 'string' and value.name or nil
                    if value.favorite == true or (name and name ~= '') then
                        self.entries[key] = { favorite = value.favorite == true or nil, name = name }
                    end
                end
            end
        end
    end
    function self:source(row) return row and (row.parameter_source or row) end
    function self:key(page, row)
        row = self:source(row)
        if not row or row.collapsed_component or row.parameter_hint or row.custom_action
            or (row.empty and not row.readonly_text) then return nil end
        if not keys[row] then keys[row] = c.identity(page, row) or false end
        return keys[row] or nil
    end
    function self:get(page, row)
        local key = self:key(page, row)
        return key and self.entries[key] or nil
    end
    function self:original_label(row)
        row = self:source(row)
        if row.parameter_hint then return '' end
        local label = row.label_of and row.label_of() or row.label or row.id or ''
        return c.translate and c.translate(label) or label
    end
    function self:label(page, row)
        local pref = self:get(page, row)
        return (pref and pref.favorite and '★ ' or '') .. (pref and pref.name or self:original_label(row))
    end
    function self:set(page, row, property, value)
        if self.error then return nil, self.error end
        local key = self:key(page, row)
        if not key or (property ~= 'favorite' and property ~= 'name') then return nil, 'Not a parameter' end
        if property == 'name' then
            value = tostring(value or ''):gsub('[%z\1-\31]', ' '):match('^%s*(.-)%s*$')
            if #value > 512 then return nil, 'Parameter name exceeds 512 UTF-8 bytes' end
            if value == '' then value = nil end
        else value = value == true or nil end
        local previous = self.entries[key]
        local next_value = { favorite = previous and previous.favorite, name = previous and previous.name }
        next_value[property] = value
        if not next_value.favorite and not next_value.name then next_value = nil end
        self.entries[key] = next_value
        local tmp = self.path .. '.tmp'
        local ok, why = c.mkdir(c.folder)
        if ok then ok, why = fs.write(tmp, J.encode({ version = 1, parameters = self.entries }, true)) end
        if ok then ok, why = fs.move(tmp, self.path) end
        if not ok then
            self.entries[key] = previous
            fs.remove(tmp)
            return nil, why or 'Cannot save parameter preferences'
        end
        self.revision = self.revision + 1
        return true
    end
    -- Decorate visible rows only. Favorites share the original parts and editing
    -- callbacks; canonical groups, by_id and config/preset ownership stay intact.
    function self:refresh(page, focus)
        if not page then return end
        if page.rows ~= page.parameter_view_rows then page.parameter_raw_rows = page.rows end
        local rows = page.parameter_raw_rows or page.rows
        if page.parameter_revision == self.revision and page.rows == page.parameter_view_rows then return end
        local out, i, target = {}, 1, nil
        focus = self:source(focus)
        local function append_favorites(source, first, last, component)
            local favorites, eligible, seen = {}, false, {}
            for n = first, last do
                local row = source[n]
                local key = self:key(page, row)
                if key then eligible = true end
                local pref = key and self.entries[key]
                if pref and pref.favorite and not seen[key] then favorites[#favorites + 1] = row; seen[key] = true end
            end
            if not eligible then return end
            local section = '__parameter_favorites:' .. tostring(component or page.component_view or page.hash)
            local function wrap(row)
                return setmetatable({ parameter_source = row, parameter_favorite = true,
                    section = section, section_level = 'group', section_of = c.favorite_label,
                    note = '', after_h = 0 }, { __index = row })
            end
            if #favorites == 0 then
                local hint = { id = '__favorite_hint', label = '', storage = 'u32', parts = {},
                    empty = true, parameter_hint = true, readonly_text = c.empty_label }
                for _, name in ipairs({ 'component', 'component_of', 'component_sub', 'component_sub_of',
                    'component_count', 'component_modified', 'collapsible' }) do hint[name] = source[first][name] end
                out[#out + 1] = wrap(hint)
            else
                for _, row in ipairs(favorites) do out[#out + 1] = wrap(row) end
            end
        end
        -- Health is one component whose body/parts are themselves foldable groups.
        -- Its favorites belong above those groups, even while the source group is closed.
        local whole_component = page.health_full and page.all_component_rows
        if whole_component and #whole_component > 0 then
            append_favorites(whole_component, 1, #whole_component, 'HealthComponentData')
        end
        while i <= #rows do
            local first, last, component = i, i, rows[i].component
            while last < #rows and rows[last + 1].component == component do last = last + 1 end
            if not whole_component and not rows[first].collapsed_component then
                append_favorites(rows, first, last, component)
            end
            for n = first, last do
                if rows[n] == focus then target = #out + 1 end
                out[#out + 1] = rows[n]
            end
            i = last + 1
        end
        page.parameter_revision, page.parameter_view_rows, page.rows = self.revision, out, out
        return target
    end
    return self
end
return M
