-- EagleSpawnerComponentData (飞鹰生成器组件, 24 bytes): how an Eagle Storm entity periodically spawns Eagle strikes
-- around Helldivers (DSS Eagle Storm, Eagle Storm - Gas, Eagle Storm - Napalm). Layout from the game's type library
-- and Darctor/Helldivers2_RawData (EagleSpawnerComponentData.json, 2026-10-20, 3 entities).
local V=require('component_view')
local R,f=V.R,V.field
local S={TYPE='EagleSpawnerComponentData',KEY='eagle_spawner',SIZE=24,HASH=0x86B6558B,SLOT='EagleSpawnerComponents',
 FLAG='eagle_spawner_component',
 COMPONENT={'Eagle spawner component','飞鹰生成器组件（EagleSpawner）','飛鷹生成器組件（EagleSpawner）'}}
S.NAMES={
 ['86DBDB83634F153C']='DSS Eagle Storm',
 ['FA52B73C2D97DD72']='Eagle Storm - Gas',
 ['4CDE8B230AA4EAB0']='Eagle Storm - Napalm',
}
S.BY_EAGLE_ENTITY={
 ['23A60681DD4383EC']='86DBDB83634F153C',
 ['DBB286AD7ED9DF96']='FA52B73C2D97DD72',
 ['27BB558C893383CC']='4CDE8B230AA4EAB0',
}
S.OPEN_ENUMS=true
S.ENUMS={
 eagle_type={
  [0]={'None','无（None）','無（None）'},
  [9]={'Eagle Strafing Run','飞鹰机枪扫射（EagleStrafingRun）','飛鷹機槍掃射（EagleStrafingRun）'},
  [10]={'Eagle Airstrike','飞鹰空袭（EagleAirstrike）','飛鷹空襲（EagleAirstrike）'},
  [11]={'Eagle Cluster Bomb','飞鹰集束炸弹（EagleClusterBomb）','飛鷹集束炸彈（EagleClusterBomb）'},
  [12]={'Eagle Napalm Airstrike','飞鹰凝固汽油弹空袭（EagleNapalmAirstrike）','飛鷹凝固汽油彈空襲（EagleNapalmAirstrike）'},
  [13]={'Eagle Smoke Strike','飞鹰烟雾攻击（EagleSmokeStrike）','飛鷹煙霧攻擊（EagleSmokeStrike）'},
  [14]={'Eagle 110MM Rocket Pods','飞鹰110毫米火箭巢（EagleRocketPods）','飛鷹110毫米火箭巢（EagleRocketPods）'},
  [15]={'Eagle 500KG Bomb','飞鹰500公斤炸弹（Eagle500KGBomb）','飛鷹500公斤炸彈（Eagle500KGBomb）'},
  [36]={'DSS Eagle Strafing Run','民主空间站 飞鹰机枪扫射（EagleStrafingRun_DSS）','民主空間站 飛鷹機槍掃射（EagleStrafingRun_DSS）'},
  [107]={'Eagle Rearm','飞鹰重新武装（EagleRearm）','飛鷹重新武裝（EagleRearm）'},
  [121]={'Additional Strafing Runs','额外机枪扫射（EagleExtraStrafing）','額外機槍掃射（EagleExtraStrafing）'},
  [122]={'Eagle Air-to-Air Missiles','飞鹰空对空导弹（EagleAirToAirMissiles）','飛鷹空對空導彈（EagleAirToAirMissiles）'},
  [129]={'Eagle Gas Strike','飞鹰毒气攻击（EagleGasStrike）','飛鷹毒氣攻擊（EagleGasStrike）'},
  [136]={'Eagle Storm Napalm Airstrike','飞鹰风暴凝固汽油弹空袭（EagleAirstrikeNapalm）','飛鷹風暴凝固汽油彈空襲（EagleAirstrikeNapalm）'},
  [168]={'Eagle Fly By','飞鹰低空通场（EagleFlyBy）','飛鷹低空通場（EagleFlyBy）'},
 },
}
S.GROUPS={
 {'spawner','Eagle storm spawner','飞鹰风暴生成参数','飛鷹風暴生成參數'},
}
local L={}
f(L,'min_lifetime',0,'f32','spawner','Minimum lifetime (s)','最短持续时间（秒）','最短持續時間（秒）',R.sec,
 {id='min_lifetime',note={'Minimum lifetime of the Eagle storm spawner in seconds.','飞鹰风暴生成器的最短持续时间（秒）。','飛鷹風暴生成器的最短持續時間（秒）。'}})
f(L,'max_lifetime',4,'f32','spawner','Maximum lifetime (s)','最长持续时间（秒）','最長持續時間（秒）',R.sec,
 {id='max_lifetime',note={'Maximum lifetime of the Eagle storm spawner in seconds.','飞鹰风暴生成器的最长持续时间（秒）。','飛鷹風暴生成器的最長持續時間（秒）。'}})
f(L,'min_spawn_cooldown',8,'f32','spawner','Minimum spawn cooldown (s)','最短生成冷却（秒）','最短生成冷卻（秒）',R.sec,
 {id='min_spawn_cooldown',note={'Minimum cooldown in seconds between spawned Eagle strikes.','两次生成飞鹰空袭之间的最短冷却时间（秒）。','兩次生成飛鷹空襲之間的最短冷卻時間（秒）。'}})
f(L,'max_spawn_cooldown',12,'f32','spawner','Maximum spawn cooldown (s)','最长生成冷却（秒）','最長生成冷卻（秒）',R.sec,
 {id='max_spawn_cooldown',note={'Maximum cooldown in seconds between spawned Eagle strikes.','两次生成飞鹰空袭之间的最长冷却时间（秒）。','兩次生成飛鷹空襲之間的最長冷卻時間（秒）。'}})
f(L,'eagle_storm_radius',16,'f32','spawner','Eagle storm radius (m)','飞鹰风暴半径（米）','飛鷹風暴半徑（米）',R.m,
 {id='eagle_storm_radius',note={'Search and strike radius of the Eagle storm around Helldivers in meters.','飞鹰风暴在绝地潜兵周围索敌与发动攻击的半径（米）。','飛鷹風暴在絕地潛兵周圍索敵與發動攻擊的半徑（米）。'}})
f(L,'eagle_type',20,'enum','spawner','Eagle stratagem type','飞鹰战略配备类型','飛鷹戰略配備類型',R.enum,
 {id='eagle_type',enum='eagle_type',enum_type='StratagemType',ref='stratagem_id',
  note={'StratagemType ID spawned by this Eagle storm entity (double-click to open).','该飞鹰风暴实体所生成的战略配备类型（StratagemType ID，双击可跳转）。','該飛鷹風暴實體所生成的戰略配備類型（StratagemType ID，雙擊可跳轉）。'}})
S.FIELDS=L
S.LAYOUT={{0,4},{4,4},{8,4},{12,4},{16,4},{20,4}}
return V.prepare(S)
