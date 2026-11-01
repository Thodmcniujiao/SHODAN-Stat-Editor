-- Exact native text IDs. Simplified and Traditional are separate game locales.
local DATA=require('localization_data')
local M={data=DATA}
local function locale(lang)return lang=='zh-Hans'and'zhs'or lang=='zh-Hant'and'zht'or'en'end
function M.lookup(hash,lang)
 local key=locale(lang);local current=rawget(_G,'SHODAN_TEXTS')
 local live=current and(key=='en'and current.texts or current.localized and current.localized[key])
 return live and live[tonumber(hash)]or DATA.strings[key][tostring(hash)]
end
function M.required_ids()
 local ids={};for _,id in ipairs(DATA.required_ids)do ids[id]=true end;return ids
end
local function planet(record)
 if not record then return end
 local en=M.lookup(record.name_hash,'en');local zhs=M.lookup(record.name_hash,'zh-Hans');local zht=M.lookup(record.name_hash,'zh-Hant')
 if not(en or zhs or zht)then return end
 return{en=en or record.debug or record.local_debug,zhs=zhs or en,zht=zht or en,
  index=record.index,sector=record.sector or'',name_hash=record.name_hash,source=record.source or'native_hash'}
end
function M.planet(debug,name_hash)
 local records=DATA.planets[debug];if not records then return end
 local chosen
 for _,p in ipairs(records)do
  if not name_hash or name_hash==p.name_hash then
   if chosen and chosen.name_hash~=p.name_hash then return end -- ambiguous debug name
   chosen=p
  end
 end
 return planet(chosen)
end
function M.planet_index(index,settings_hash)
 local p=DATA.api_planets[tostring(index)]
 if p and(not settings_hash or p.settings_hash==settings_hash)then return planet(p)end
end
local fields={en='en',zhs='zh',zht='zht'}
function M.effect_text(entry,field,lang)
 local key=locale(lang);local ref=entry.text_provenance and entry.text_provenance[key]and entry.text_provenance[key][field]
 local value=ref and M.lookup(ref.hash,lang)or entry[field..'_'..fields[key]]
 if not value and key~='en'then return M.effect_text(entry,field,'en')end
 return value,ref
end
return M
