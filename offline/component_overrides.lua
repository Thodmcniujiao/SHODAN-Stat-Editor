-- Curated names, groups and help text for component pages, applied from
-- component_view.prepare. Labels only: the field id (the config/preset key) and the
-- offsets never change, so values saved before this file existed keep loading.
-- Keyed by the component type hash (spec.HASH, else spec.TYPE).
local M = {}
local D = {}

-- BeamInfo (Beam settings, 112 bytes) and ExplosionInfo (152 bytes) have their own
-- page builders in the panel (MOD.beam / MOD.explosion), not component_view specs:
-- their names and notes live in offline/beam_components.lua / explosion_components.lua
-- and in those builders.

-- BeamWeapon (120 bytes): the four fields that decide how a beam weapon fires were
-- scattered through "General". One "Beam mechanics" section, with what each one does.
D[0xF0721C2C] = {
 groups = {{'mechanics', 'Beam mechanics', '光束机制', '光束機制'}},
 move = {[100] = 'mechanics', [104] = 'mechanics', [108] = 'mechanics', [112] = 'mechanics'},
 notes = {
  [100] = {'Existing native firing-mode slot: 1 automatic, 2 single, 3 burst. It changes a mode the record already has; it does not add a selector.',
           '记录已有的射击模式：1 自动、2 单发、3 连发；只改记录已有的模式，不会新增选择项。',
           '記錄已有的射擊模式：1 自動、2 單發、3 連發；只改記錄已有的模式，不會新增選擇項。'},
  [104] = {'Rounds per minute the engine fires at; 0 may leave the cadence to the animation.',
           '引擎射速（发/分）；0 可能交由动画决定。',
           '引擎射速（發/分）；0 可能交由動畫決定。'},
  [108] = {'Beams generated per firing emitter; it does not create new emitters.',
           '每次发射生成的光束数；不会新增发射器。',
           '每次發射生成的光束數；不會新增發射器。'},
  [112] = {'How long each beam pulse stays after the shot; some continuous lasers ignore it.',
           '单发光束开火后保留的时间；部分连续激光会忽略。',
           '單發光束開火後保留的時間；部分連續雷射會忽略。'},
 },
}

-- WeaponData (1240 bytes): the fire-mode slots and the AI noise pair get their own
-- sections; +568 on ProjectileWeapon is the burst cadence that goes with them.
local fireNote = {'Existing firing-mode slot: 0 none, 1 automatic, 2 single, 3 burst, 4 all barrels. Only changes a mode the record already has.',
                  '已有射击模式槽：0 无、1 自动、2 单发、3 连发、4 全管齐射；只改记录已有的模式。',
                  '已有射擊模式槽：0 無、1 自動、2 單發、3 連發、4 全管齊射；只改記錄已有的模式。'}
D[0x88E4DBB1] = {
 groups = {{'fire', 'Fire modes', '射击模式', '射擊模式'},
           {'noise', 'AI noise', 'AI 噪音', 'AI 噪音'}},
 move = {[140] = 'fire', [144] = 'fire', [148] = 'fire', [152] = 'fire', [156] = 'fire',
         [112] = 'noise', [132] = 'noise'},
 notes = {
  [140] = {'Rounds per burst; only used when a burst mode is set.',
           '连发发数；仅在设置了连发模式时生效。',
           '連發發數；僅在設置了連發模式時生效。'},
  [144] = fireNote, [148] = fireNote, [152] = fireNote, [156] = fireNote,
  [112] = {'Suppressor flag; the AI hearing check uses it together with the noise template.',
           '消音标记；AI 听觉判定会与噪音模板一起使用。',
           '消音標記；AI 聽覺判定會與噪音模板一起使用。'},
  [132] = {'Noise template the AI hears: 6-9 weapon small to huge, 10-13 suppressed small to huge; it works as a pair with the suppressor flag (approximate hearing: small 35 m, medium 50 m, large 60 m, huge 70 m).',
           'AI 听到的噪音模板：6-9 为武器小到巨大，10-13 为消音小到巨大；与消音标记成对生效（听觉半径约：小 35 米、中 50 米、大 60 米、巨大 70 米）。',
           'AI 聽到的噪音模板：6-9 為武器小到巨大，10-13 為消音小到巨大；與消音標記成對生效（聽覺半徑約：小 35 米、中 50 米、大 60 米、巨大 70 米）。'},
 },
}

-- ProjectileWeapon (616 bytes): +568 is the independent burst cadence.
D[0x45171B68] = {
 groups = {{'fire', 'Fire modes', '射击模式', '射擊模式'}},
 move = {[568] = 'fire'},
 notes = {
  [568] = {'Burst cadence when a burst mode is active; 0 uses the normal rate.',
           '连发模式下的射速；0 使用常规射速。',
           '連發模式下的射速；0 使用常規射速。'},
 },
}

-- ExplosiveComponentData (360 bytes): +12 is the life of the placed device.
D[0xF5CF9B8C] = {
 notes = {
  [12] = {'Time before the physical device (for example the G/SH-39 shield grenade) terminates; it does not change shield capacity or recharge.',
          '实体装置（例如 G/SH-39 护盾手雷）存在的时间；不改变护盾容量或回复速度。',
          '實體裝置（例如 G/SH-39 護盾手雷）存在的時間；不改變護盾容量或回復速度。'},
  [16] = {'Delay before the spent device is removed.',
          '装置用完后被移除的延迟。',
          '裝置用完後被移除的延遲。'},
 },
}

-- SeekingMissile (272 bytes): the reference dump names only the missile-trail vectors;
-- the guidance scalars were left as raw offsets.
D[0xBF3A6789] = {
 groups = {{'guidance', 'Missile guidance', '导弹制导', '導彈製導'}},
 move = {[20] = 'guidance', [24] = 'guidance', [32] = 'guidance', [84] = 'guidance',
         [96] = 'guidance', [100] = 'guidance', [104] = 'guidance', [108] = 'guidance', [168] = 'guidance'},
 fields = {
  [20] = {'Guidance starts after distance (m)', '制导开始距离（米）', '製導開始距離（米）'},
  [24] = {'Guidance stops after distance (m)', '制导停止距离（米）', '製導停止距離（米）'},
  [32] = {'Movement prediction', '移动预测强度', '移動預測強度'},
  [84] = {'Full-turn threshold (deg)', '全转阈值（度）', '全轉閾值（度）'},
  [96] = {'Speed controller P', '速度控制 P', '速度控制 P'},
  [100] = {'Speed controller I', '速度控制 I', '速度控制 I'},
  [104] = {'Speed controller D', '速度控制 D', '速度控制 D'},
  [108] = {'Target update interval (s)', '目标刷新间隔（秒）', '目標刷新間隔（秒）'},
  [168] = {'Target tracking alignment', '目标对准阈值', '目標對準閾值'},
 },
 known = {[20] = true, [24] = true, [32] = true, [84] = true, [96] = true, [100] = true,
          [104] = true, [108] = true, [168] = true},
 notes = {
  [20] = {'-1 disables the distance trigger.', '-1 表示关闭该距离触发。', '-1 表示關閉該距離觸發。'},
  [24] = {'-1 disables the distance trigger.', '-1 表示关闭该距离触发。', '-1 表示關閉該距離觸發。'},
  [32] = {'Higher values lead the target more strongly.', '数值越高，预测目标移动越强。', '數值越高，預測目標移動越強。'},
  [84] = {'Angle at which the missile slows down for a tighter turn.', '导弹减速以进行更小半径转向的角度。', '導彈減速以進行更小半徑轉向的角度。'},
  [96] = {'Proportional speed correction.', '比例速度修正。', '比例速度修正。'},
  [100] = {'Integral speed correction.', '积分速度修正。', '積分速度修正。'},
  [104] = {'Derivative speed correction.', '微分速度修正。', '微分速度修正。'},
  [108] = {'How often the missile updates the tracked target position.', '导弹刷新被追踪目标位置的间隔。', '導彈刷新被追蹤目標位置的間隔。'},
  [168] = {'-1 disables the forward-alignment requirement.', '-1 表示关闭正前方对准要求。', '-1 表示關閉正前方對準要求。'},
 },
}

-- Bombardment (192 bytes): +40 is where the salvo as a whole is aimed.
D[0xCDBC43D8] = {
 fields = {[40] = {'Salvo-center scatter (m)', '弹幕中心散布（米）', '彈幕中心散布（米）'}},
 known = {[40] = true},
 notes = {[40] = {'Maximum offset of the salvo centre from the target; independent of the per-shell spread and drift.',
                  '弹幕中心相对目标的最大偏移；与单发散布和漂移相互独立。',
                  '彈幕中心相對目標的最大偏移；與單發散布和漂移相互獨立。'}},
}

-- TargetDetector (24 bytes): no reference entry at all, so the browser showed
-- "Component_0xFF67A367" and raw offsets.
D[0xFF67A367] = {
 component = {'Target detector component', '目标探测器组件', '目標探測器組件'},
 fields = {
  [0] = {'Target search interval, min (s)', '目标搜索间隔下限（秒）', '目標搜尋間隔下限（秒）'},
  [4] = {'Target search interval, max (s)', '目标搜索间隔上限（秒）', '目標搜尋間隔上限（秒）'},
 },
 known = {[0] = true, [4] = true},
 notes = {
  [0] = {'How often a turret or launcher rescans for targets (native TargetDetector timing).',
         '炮塔或发射器重新搜索目标的间隔（原生 TargetDetector 计时）。',
         '砲塔或發射器重新搜尋目標的間隔（原生 TargetDetector 計時）。'},
  [4] = {'Upper bound of that rescan interval.', '重新搜索间隔的上限。', '重新搜尋間隔的上限。'},
 },
}

-- CorpseDecayer (8 bytes): the reference names the two members, only the component
-- title was missing.
D[0xC2D64A76] = {
 component = {'Corpse decayer component', '尸体消散组件', '屍體消散組件'},
}

-- Health (22096 bytes): the decay block is named, except the internal extra delay at
-- +21548; the notes say what the mode and delays do.
D[0xB3915DE3] = {
 fields = {[21548] = {'Corpse decay · extra (s)', '尸体消散 · 额外延时（秒）', '屍體消散 · 額外延時（秒）'}},
 known = {[21548] = true},
 notes = {
  [21532] = {'Decay mode: 0 none, 1 regular, 2 long, 3 instant. At 0 the delays and acceleration below are not used.',
             '消散模式：0 不消散、1 常规、2 长时间、3 立即；为 0 时下面的延迟和加速度不会生效。',
             '消散模式：0 不消散、1 常規、2 長時間、3 立即；為 0 時下面的延遲和加速度不會生效。'},
  [21536] = {'Sinking acceleration once decay starts (m/s²); most units use 1.',
             '开始消散后的下沉加速度（米/秒²）；多数单位为 1。',
             '開始消散後的下沉加速度（米/秒²）；多數單位為 1。'},
  [21540] = {'Shortest delay before the corpse disappears (s).',
             '尸体消失前的最短延迟（秒）。', '屍體消失前的最短延遲（秒）。'},
  [21544] = {'Longest delay before the corpse disappears (s).',
             '尸体消失前的最长延迟（秒）。', '屍體消失前的最長延遲（秒）。'},
  [21548] = {'Internal extra delay used with the min and max delays; keep the game value unless testing.',
             '与最短/最长延迟配合的内部额外量；除非测试，保持游戏原值。',
             '與最短/最長延遲配合的內部額外量；除非測試，保持遊戲原值。'},
 },
}

local function hasGroup(spec, key)
 for _,g in ipairs(spec.GROUPS or {}) do if g[1] == key then return true end end
 return false
end

-- Called by component_view.prepare before the group table is built and the rows sorted.
function M.apply(spec)
 local d = D[spec.HASH or spec.TYPE]
 if not d then return end
 if d.component then spec.COMPONENT = d.component end
 if d.groups then
  spec.GROUPS = spec.GROUPS or {}
  for _,g in ipairs(d.groups) do
   if not hasGroup(spec, g[1]) then spec.GROUPS[#spec.GROUPS + 1] = g end
  end
 end
 for _,f in ipairs(spec.FIELDS or {}) do
  local off = f[2]
  local label = d.fields and d.fields[off]
  if label then f[5], f[6], f[7] = label[1], label[2], label[3] end
  local group = d.move and d.move[off]
  if group then f[4] = group end
  local note = d.notes and d.notes[off]
  if note then f[9] = f[9] or {}; f[9].note = note end
  if d.known and d.known[off] then f[9] = f[9] or {}; f[9].known = true end
 end
end

return M
