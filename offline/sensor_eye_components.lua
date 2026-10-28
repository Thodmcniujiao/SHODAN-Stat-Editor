-- SensorEyeComponentData (视觉 / sensor eyes, 44 bytes): how far and how wide an entity sees. Layout from the
-- type-library dump of game 1.007.200 (Darctor/Helldivers2_RawData, SensorEyeComponentData.json, 2026-10-20),
-- checked against the game's type library and data (315 entities). The enemy pages' sight range (+0) and sight
-- cone (+12 / +16) and the sentries' spotting range are the same fields.
local V=require('component_view')
local R,f=V.R,V.field
local S={TYPE='SensorEyeComponentData',KEY='sensor_eye',SIZE=44,SLOT='SensorEyeComponents',FLAG='sensor_eye_component',
 COMPONENT={'Sensor eye component','视觉传感组件（SensorEye）','視覺感測組件（SensorEye）'}}
S.GROUPS={
 {'range','Sight range','视野范围','視野範圍'},
 {'sight','Line of sight','视线','視線'},
 {'foliage','Foliage','植被','植被'},
}
S.ENUMS={eye={[0]={'None','无','無'},{'Humanoid','人形','人形'},{'Cone','锥形','錐形'},{'Omni','全向','全向'}}}
local L={}
f(L,'distance',0,'f32','range','Sight range (m)','视距（米）','視距（米）',R.m,{verified=true,id='sight'})
f(L,'peripheral_distance',4,'f32','range','Peripheral distance (m; -1: off)','余光距离（米，-1 为无）','餘光距離（米，-1 為無）',R.sm)
f(L,'back_distance',8,'f32','range','Behind distance (m; -1: off)','背后感知距离（米，-1 为无）','背後感知距離（米，-1 為無）',R.sm)
f(L,'angle_horizontal',12,'f32','range','Sight cone width (degrees)','视野水平角（度）','視野水平角（度）',R.deg,{verified=true,id='sight_h'})
f(L,'angle_vertical',16,'f32','range','Sight cone height (degrees)','视野垂直角（度）','視野垂直角（度）',R.deg,{verified=true,id='sight_v'})
f(L,'eye_type',32,'enum','sight','Eye type','视觉类型','視覺類型',R.enum,{enum='eye',enum_type='EyeType'})
f(L,'sight_node',20,'u32','sight','Eye node (hash)','视点节点（哈希）','視點節點（雜湊）',R.hash)
f(L,'use_sight_node_for_direction',24,'flag','sight','Looks where the eye node points','视线方向跟随视点节点','視線方向跟隨視點節點',R.flag)
f(L,'vision_raycast_template',28,'enum','sight','Vision raycast template','视线检测模板','視線檢測範本',R.enum,{enum_type='RaycastTemplate'})
f(L,'ignore_inside_foliage_distance',36,'f32','foliage','Sees into foliage within (m)','此距离内无视植被（米）','此距離內無視植被（米）',R.m)
f(L,'inside_foliage_distance',40,'f32','foliage','Sight inside foliage (m)','植被内可见距离（米）','植被內可見距離（米）',R.m)
S.FIELDS=L
S.LAYOUT={{0,4},{4,4},{8,4},{12,4},{16,4},{20,4},{24,1},{28,4},{32,4},{36,4},{40,4}}
return V.prepare(S)
