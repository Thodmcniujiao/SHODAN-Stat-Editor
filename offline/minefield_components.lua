-- MinefieldComponentData (地雷, 44 bytes): one mine's trigger, explosion and AI avoidance (the enemy minefields, the
-- MD-6 / MD-8 / MD-i4 / MD-17 mines, the G-11 Caltrops). Layout from the type-library dump of game 1.007.200
-- (Darctor/Helldivers2_RawData, MinefieldComponentData.json, 2026-10-20), checked against the game's type library
-- and data. The editor already had +8 trigger delay, +12 chain reaction delay and +24 explosion (the minefield pages).
local V=require('component_view')
local R,f=V.R,V.field
local S={TYPE='MinefieldComponentData',KEY='minefield',SIZE=44,SLOT='MinefieldComponents',FLAG='minefield_component',
 COMPONENT={'Minefield component','地雷组件（Minefield）','地雷組件（Minefield）'}}
S.GROUPS={
 {'trigger','Triggering','触发','觸發'},
 {'explosion','Explosion and AI','爆炸与 AI 回避','爆炸與 AI 迴避'},
 {'audio','Audio','音效','音效'},
 {'unknown','Unknown fields','未知字段','未知欄位'},
}
S.ENUMS={unit_size={[0]={'Small','小','小'},{'Medium','中','中'},{'Large','大','大'},{'Massive','巨型','巨型'}}}
local L={}
f(L,'trigger_time',8,'f32','trigger','Trigger delay (s)','触发延迟（秒）','觸發延遲（秒）',R.sec,{verified=true,id='mine_trigger'})
f(L,'chain_reaction_time',12,'f32','trigger','Chain reaction delay (s)','连锁引爆延迟（秒）','連鎖引爆延遲（秒）',R.sec,{verified=true,id='mine_chain'})
f(L,'arm_time',16,'f32','trigger','Arming time (s)','解除保险时间（秒）','解除保險時間（秒）',R.sec)
f(L,'trigger_on_touch',32,'flag','trigger','Triggers on touch','接触即触发','接觸即觸發',R.flag)
f(L,'step_detection_min_unit_size',36,'enum','trigger','Smallest unit that sets it off','可触发的最小单位体型','可觸發的最小單位體型',R.enum,{enum='unit_size',enum_type='UnitSize'})
f(L,'trigger_actor',20,'u32','trigger','Trigger actor (hash)','触发体（哈希）','觸發體（雜湊）',R.hash)
f(L,'explosion_type',24,'enum','explosion','Explosion ID','爆炸 ID','爆炸 ID',R.enum,{ref='explosion_id',enum_type='ExplosionType'})
f(L,'ai_avoidance_radius',28,'f32','explosion','AI avoidance radius (m)','AI 回避半径（米）','AI 迴避半徑（米）',R.m)
f(L,'unk_event_0x0000',0,'u32','audio','Unknown event +0x00 (hash)','未知事件 +0x00（哈希）','未知事件 +0x00（雜湊）',R.hash)
f(L,'on_mine_triggered_sound_event',4,'u32','audio','Triggered sound (hash)','触发音效（哈希）','觸發音效（雜湊）',R.hash)
f(L,'unk_bool_0x0028',40,'flag','unknown','Unknown switch +0x28','未知开关 +0x28','未知開關 +0x28',R.flag)
S.FIELDS=L
S.LAYOUT={{0,4},{4,4},{8,4},{12,4},{16,4},{20,4},{24,4},{28,4},{32,1},{36,4},{40,1}}
return V.prepare(S)
