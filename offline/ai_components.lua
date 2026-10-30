-- 敌人设置 › AI设置: the enemies' AI and senses components in full, one tab each (component browser, every entity
-- with the component): AiEnemy, AiCharacter (offline/enemy_components.lua), the sensor eye (the same fields as
-- 实体组件 › 炮塔与制导's 视觉传感 tab: offline/sensor_eye_components.lua), SensorEar, SensorDanger, Targeting. 生命与拆毁 › 接触伤害:
-- OverlapDamage. The enemy pages' movement speed and senses rows are these fields, so a change on one shows on the
-- other.
local EC=require('enemy_components')
local M={SPECS={},SUBS={ai={},overlap={},turret={}}}
local by={}
for _,s in ipairs(EC.SPECS)do by[s.TYPE]=s end
-- the sensor eye again, under its own key (its own tab and pages), the same fields
local eye={}
for k,v in pairs(require('sensor_eye_components'))do eye[k]=v end
eye.KEY,eye.SLOT,eye.FLAG,eye.HASH='ai_sensor_eye','AiSensorEyeComponents','ai_sensor_eye_component',0x14729B6A
eye.TAB={'Sight','视觉','視覺'}
eye.SUB='ai'
-- the sensor ear again for 实体组件 › 炮塔与制导 (beside the sensor eye there), its own key, the same fields
local ear={}
for k,v in pairs(by.SensorEarComponentData)do ear[k]=v end
ear.KEY,ear.SLOT,ear.FLAG='turret_sensor_ear','TurretSensorEarComponents','turret_sensor_ear_component'
ear.TAB={'Sensor ear','听觉传感组件','聽覺感測組件'}
ear.SUB='turret'
for _,s in ipairs({by.AiEnemyComponentData,by.AiCharacterComponentData,eye,by.SensorEarComponentData,
  by.SensorDangerComponentData,by.TargetingComponentData,by.OverlapDamageComponentData,ear})do
 M.SPECS[#M.SPECS+1]=s
 local t=M.SUBS[s.SUB];t[#t+1]=s.SLOT
end
return M
