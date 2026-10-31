-- Standalone creature component browsers. Existing suppression fields keep their keys and shared owners.
local Generated=require('creature_component_specs')
local M={SPECS=Generated.SPECS,SUBS={creature={},character={}},TAB_LABELS={
 SensorDangerComponents={'Suppression sense','压制感知','壓制感知'},
 TargetingComponents={'Targeting / suppression','瞄准与压制','瞄準與壓制'},
 CreatureUnitComponents={'Unit','单位','單位'},
}}
for i,s in ipairs(M.SPECS)do
 s.STRICT=true
 -- Avatar is already fully exposed by Character data. Voice belongs beside it.
 if s.TYPE=='CharacterVoiceComponentData'then s.SUB='character'end
 M.SUBS[s.SUB][#M.SUBS[s.SUB]+1]=s.SLOT
 if i==1 then
  M.SUBS.creature[#M.SUBS.creature+1]='SensorDangerComponents'
  M.SUBS.creature[#M.SUBS.creature+1]='TargetingComponents'
 end
end
return M
