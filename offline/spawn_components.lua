-- 敌人设置 › 刷怪编辑器: the components enemy spawning is read from, in full.
--  * HiveMindComponentData (敌人调度, 1084 bytes, one record per mission type; +0 the faction): the spec of
--    offline/mission_components.lua (layout from the type library, names checked against the RawData dump and entity
--    deltas; 星球任务 › 任务编辑 no longer shows it), grouped as 敌人生成's three groups (增援 / 巡逻 / 前哨与生成点),
--    then the mission's progress and the rest.
--  * SeafObjectivesComponentData (SEAF 目标, 96 bytes, one record): the values 敌人生成 › 所有阵营 scales. Layout
--    from the type library (game 1.007.200); no public dump or schema names it, the names of the six float pairs are
--    FileDiver's (as the editor's 所有阵营 page has them).
-- 敌人生成's rows are multipliers over these fields (every record of a faction at once); a field one of them scales
-- says so in its tip.
local V=require('component_view')
local R,f=V.R,V.field
R.mult=R.mult or{-1e9,1e9,.05,.25,true}
local MC=require('mission_components')
local M={SPECS={},SUBS={spawn={}}}

-- 敌人生成's rows (MOD.enemy.SPAWN): record offset -> its label; the four player-count multipliers from there
local SCALED={
 [316]={'Reinforcement size (x)','增援规模 (x)','增援規模 (x)'},[376]={'Reinforcement frequency (x)','增援频率 (x)','增援頻率 (x)'},
 [496]={'Patrol frequency (x)','巡逻频率 (x)','巡邏頻率 (x)'},[436]={'Patrols at once (x)','同时巡逻数 (x)','同時巡邏數 (x)'},
 [976]={'Modifier patrol frequency (x)','修正巡逻频率 (x)','修正巡邏頻率 (x)'},[1036]={'Modifier patrol size (x)','修正巡逻规模 (x)','修正巡邏規模 (x)'},
 [856]={'Outpost garrison size (x)','前哨驻军规模 (x)','前哨駐軍規模 (x)'},[556]={'Fabricator / bug hole queue (x)','构筑者 / 虫洞队列 (x)','構築者 / 蟲洞隊列 (x)'},
 [676]={'Fabricator / bug hole batch size (x)','构筑者 / 虫洞批量 (x)','構築者 / 蟲洞批量 (x)'},
 [616]={'Fabricator / bug hole refill speed (x)','构筑者 / 虫洞补充速度 (x)','構築者 / 蟲洞補充速度 (x)'},
 [796]={'Fabricator / bug hole release speed (x)','构筑者 / 虫洞释放速度 (x)','構築者 / 蟲洞釋放速度 (x)'},
}
local SINGLE={[128]={'Enemy cap (x)','敌人数量上限 (x)','敵人數量上限 (x)'},
 [1077]={'Reinforcements (flares, breaches, drops)','增援 (信号弹、虫潮、空投)','增援 (信號彈、蟲潮、空投)'}}
local function scaled_by(off)
 if SINGLE[off]then return SINGLE[off]end
 for base,l in pairs(SCALED)do if off>=base and off<base+16 then return l end end
end

-- the hive mind: the mission editor's spec, regrouped
local hive
for _,s in ipairs(MC.SPECS)do if s.TYPE=='HiveMindComponentData'then hive=s end end
assert(hive,'mission_components has no HiveMindComponentData')
local function group_of(path)
 if path:find('encounter',1,true)then return'reinforce'end
 if path:find('patrol',1,true)or path:find('traveler',1,true)then return'patrol'end
 if path:find('spawner',1,true)or path:find('guard_force',1,true)then return'outpost'end
 if path:find('progress_settings',1,true)or path=='mission_time_start_paused'or path=='starting_time_limit'then return'progress'end
 return'other'
end
local H={}
for k,v in pairs(hive)do H[k]=v end
H.KEY,H.SLOT,H.FLAG='spawn_hive_mind','SpawnHiveMindComponents','spawn_hive_mind_component'
H.TAB={'Enemy director','敌人调度（HiveMind）','敵人調度（HiveMind）'}
H.SUB='spawn'
H.GROUPS={
 {'reinforce','Reinforcements','增援','增援'},
 {'patrol','Patrols','巡逻','巡邏'},
 {'outpost','Outposts and spawners','前哨与生成点','前哨與生成點'},
 {'progress','Mission progress and time','任务进度与时间','任務進度與時間'},
 {'other','Faction and other fields','阵营与其他字段','陣營與其他欄位'},
}
H.NAMES={
 ['87F3B48D9D744885']='Hive mind: None · 40 min · 87F3B48D',
 ['44FD712DDCA794B9']='Hive mind: Terminids · 12 min · 44FD712D',
 ['0E5F20CAB6E2EA5D']='Hive mind: Terminids · 15 min · 0E5F20CA',
 ['2EE781A5B42E9904']='Hive mind: Terminids · 15 min · 2EE781A5',
 ['84B4FD5378D79D27']='Hive mind: Terminids · 40 min · 84B4FD53',
 ['D337A7BFDA8F4B10']='Hive mind: Terminids · 40 min · D337A7BF',
 ['D47AFFEE94BD098F']='Hive mind: Terminids · 40 min · D47AFFEE',
 ['E2262DC92FA7A896']='Hive mind: Terminids · 40 min · E2262DC9',
 ['B451E82DEA028938']='Hive mind: Illuminate · 12 min · B451E82D',
 ['252C22DE9FBE9801']='Hive mind: Illuminate · 15 min · 252C22DE',
 ['7D6CFDB4F41AD1C1']='Hive mind: Illuminate · 15 min · 7D6CFDB4',
 ['392C6D2A6B9934FF']='Hive mind: Illuminate · 40 min · 392C6D2A',
 ['3F868B515FC33402']='Hive mind: Illuminate · 40 min · 3F868B51',
 ['74DF12368C8F2B4A']='Hive mind: Illuminate · 40 min · 74DF1236',
 ['33296F9C47993942']='Hive mind: Automatons · 12 min · 33296F9C',
 ['014814C021721D41']='Hive mind: Automatons · 15 min · 014814C0',
 ['E074A822F551274F']='Hive mind: Automatons · 15 min · E074A822',
 ['0CE050AB214FEC85']='Hive mind: Automatons · 40 min · 0CE050AB',
 ['9BA2E41C218B41FF']='Hive mind: Automatons · 40 min · 9BA2E41C',
}
local L={}
for _,s in ipairs(hive.FIELDS)do
 local c={};for i=1,9 do c[i]=s[i]end
 c[4]=group_of(s[1])
 local by=scaled_by(s[2])
 if by then
  local x={};for k,v in pairs(s[9]or{})do x[k]=v end
  local n=x.note or{'','',''}
  local sep=n[1]~=''and' 'or''
  x.note={n[1]..sep..'Scaled by 敌人生成\'s "'..by[1]..'" (every record of the faction at once).',
   n[2]..(n[2]~=''and' 'or'')..'敌人生成页的“'..by[2]..'”按阵营同时缩放此值。',
   n[3]..(n[3]~=''and' 'or'')..'敵人生成頁的「'..by[3]..'」按陣營同時縮放此值。'}
  c[9]=x
 end
 L[#L+1]=c
end
H.FIELDS=L
H.GROUP,H.VERIFIED=nil,nil
M.SPECS[1]=V.prepare(H)

-- SEAF objectives: five counts, five fractions, two counts, six float pairs (arrays of 2 in the type library)
local S={TYPE='SeafObjectivesComponentData',KEY='seaf_objectives',SIZE=96,HASH=0xD74E6E1A,SLOT='SeafObjectivesComponents',
 FLAG='seaf_objectives_component',COMPONENT={'SEAF objectives component','SEAF 目标组件（SeafObjectives）','SEAF 目標組件（SeafObjectives）'},
 TAB={'SEAF objectives','SEAF 目标（所有阵营）','SEAF 目標（所有陣營）'},SUB='spawn'}
S.NAMES={['A56F9F7E8CD25D04']='SEAF objectives (all factions)'}
S.GROUPS={
 {'seaf','SEAF','SEAF','SEAF'},
 {'floors','Lowest rates','最低频率','最低頻率'},
 {'unknown','Unnamed fields','未命名字段','未命名欄位'},
}
local FD={'Name from FileDiver (tested with Little Enemy Kontrol and HD2Runtime 0.40); the type library has it as one of six arrays of two floats.',
 '名称来自 FileDiver（经 Little Enemy Kontrol、HD2Runtime 0.40 测试）；类型库中是 6 个“2 个浮点数”数组之一。',
 '名稱來自 FileDiver（經 Little Enemy Kontrol、HD2Runtime 0.40 測試）；類型庫中是 6 個「2 個浮點數」陣列之一。'}
local UN={'No public dump or schema names it; position and type checked against the type library.',
 '公开的 dump 和结构都没有它的名字；位置与类型已按类型库核对。','公開的 dump 和結構都沒有它的名字；位置與類型已按類型庫核對。'}
local P={}
for i=0,4 do f(P,'unk_counts['..i..']',i*4,'u32','unknown','Unknown count '..(i+1),'未知计数 '..(i+1),'未知計數 '..(i+1),R.count,{id='seaf_count'..(i+1),note=UN})end
for i=0,4 do f(P,'unk_fractions['..i..']',20+i*4,'f32','unknown','Unknown value '..(i+1),'未知数值 '..(i+1),'未知數值 '..(i+1),R.raw,{id='seaf_value'..(i+1),note=UN})end
for i=0,1 do f(P,'unk_pair['..i..']',40+i*4,'u32','unknown','Unknown count pair · '..(i+1),'未知计数对 · '..(i+1),'未知計數對 · '..(i+1),R.count,{id='seaf_pair'..(i+1),note=UN})end
for i=0,3 do f(P,'seaf_reinforcement_cooldown['..i..']',48+i*4,'f32','seaf','SEAF reinforcement cooldown '..(i+1)..' (s)','SEAF 增援冷却 '..(i+1)..'（秒）','SEAF 增援冷卻 '..(i+1)..'（秒）',R.ssec,{id='seaf_reinf'..(i+1),note=FD})end
for i=0,3 do f(P,'seaf_wave_cooldown['..i..']',64+i*4,'f32','seaf','SEAF wave cooldown '..(i+1)..' (s)','SEAF 波次冷却 '..(i+1)..'（秒）','SEAF 波次冷卻 '..(i+1)..'（秒）',R.ssec,{id='seaf_wave'..(i+1),note=FD})end
for i=0,1 do f(P,'lowest_patrol_rate['..i..']',80+i*4,'f32','floors','Lowest patrol frequency '..(i+1)..' (x)','巡逻频率下限 '..(i+1)..'（倍）','巡邏頻率下限 '..(i+1)..'（倍）',R.mult,{id='floor_patrol'..(i+1),note=FD})end
for i=0,1 do f(P,'lowest_reinforcement_rate['..i..']',88+i*4,'f32','floors','Lowest reinforcement frequency '..(i+1)..' (x)','增援频率下限 '..(i+1)..'（倍）','增援頻率下限 '..(i+1)..'（倍）',R.mult,{id='floor_reinf'..(i+1),note=FD})end
S.FIELDS=P
S.LAYOUT={{0,20},{20,20},{40,8},{48,8},{56,8},{64,8},{72,8},{80,8},{88,8}}
S.NESTED={}
M.SPECS[2]=V.prepare(S)

local Q=require('spawn_queue_components')
for _,spec in ipairs(Q.SPECS)do M.SPECS[#M.SPECS+1]=spec end
H.CATEGORIES={}
for hash,name in pairs(H.NAMES)do
 local fac=name:match('Hive mind: (%a+)')
 H.CATEGORIES[hash]=({Terminids='terminids',Automatons='automatons',Illuminate='illuminate'})[fac]or'other'
end
for _,s in ipairs(M.SPECS)do M.SUBS.spawn[#M.SUBS.spawn+1]=s.SLOT end

-- the hive minds' page names ('Hive mind: Terminids · 40 min · D337A7BF'), translated
local FACTION={None={'无','無'},Terminids={'虫族','蟲族'},Illuminate={'光能者','光能者'},Automatons={'机器人','機器人'}}
function M.translate_name(v,lang)
 local queue=Q.translate_name(v,lang);if queue then return queue end
 if type(v)~='string'then return nil end
 if v=='SEAF objectives (all factions)'then
  return lang=='zh-Hans'and'SEAF 目标（所有阵营）'or lang=='zh-Hant'and'SEAF 目標（所有陣營）'or nil
 end
 local fac,min,h=v:match('^Hive mind: (%a+) · (%d+) min · (%x+)$')
 if not fac or not FACTION[fac]then return nil end
 if lang=='zh-Hans'then return'敌人调度：'..FACTION[fac][1]..' · '..min..' 分钟任务 · '..h end
 if lang=='zh-Hant'then return'敵人調度：'..FACTION[fac][2]..' · '..min..' 分鐘任務 · '..h end
 return nil
end
return M
