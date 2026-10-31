# 生物设置：敌人编辑、AI设置、生物组件

顶部“敌人设置”更名为“生物设置”，保留内部页面 ID 和原有配置。子页依次为敌人编辑、AI设置、刷怪编辑器、生物组件、敌人替换器。

## 生物组件

“生物组件”位于“敌人替换器”左侧，共 11 个标签。单位、压制感知和瞄准与压制排在最前面。

| 标签 | 组件 | 内联字段 | 当前加载实体 |
| --- | --- | ---: | ---: |
| 单位 | UnitComponentData | 33 | 1719 |
| 压制感知 | SensorDangerComponentData | 3 | 191 |
| 瞄准与压制 | TargetingComponentData | 21 | 297 |
| 硬直反应 | HitReactComponentData | 1224 | 196 |
| 状态接收 | StatusEffectReceiverComponentData | 7162 | 329 |
| 移动运动 | LocomotionComponentData | 1172 | 206 |
| 转向旋转 | RotationComponentData | 80 | 226 |
| 近战攻击 | MeleeAttackComponentData | 4 | 167 |
| 部位护盾 | DamageZoneShieldComponentData | 1248 | 6 |
| 状态区域 | StatusEffectVolumeComponentData | 185 | 8 |
| 单位自定义 | UnitCustomizationComponentData | 135 | 96 |

Avatar 的全部参数沿用“人物数据 → 人物数据”，不另设“角色控制”入口。CharacterVoice 的 1 个内联字段、3 个实体移至“人物数据 → 角色语音”。

数量以本次安装的游戏类型库、实体数据为准。字段按实体自身的组件记录读取，延迟建立编辑行；动态数组和指针描述符不会成为可编辑整数。未知字段保留类型和偏移，不把推断名称当作已确认名称。Locomotion、Rotation 的键值数组包含 4 字节尾部对齐，解析时单独计入。

敌人编辑中的“受你火力影响的瞄准抖动”来自 Targeting +36，“射击生效范围”来自 SensorDanger +4。两者不属于 Unit。原来的压制相关入口从 AI设置移到生物组件，和原敌人编辑页共享字段，修改、星号、重置和预设仍互通。

生物组件中新增 9 类完整组件视图，共 11243 个内联字段；压制相关两个组件沿用原解析。按类型哈希逐一核对，这 11 类与 AI设置中的 AiEnemy、AiCharacter、SensorEye、SensorEar 均不重复；移动、硬直等相关功能的不同组件保留各自入口。其余已解析组件的入口核查见 [CREATURE_COMPONENT_AUDIT.md](CREATURE_COMPONENT_AUDIT.md)。

## 敌人编辑

标签：敌人 / SEAF / 敌人生成 / 敌人数据。

- **敌人：**
  - 原来的虫族、机器人、光能者三个标签合并为一个。左侧列表上方的“< 阵营 >”选择器负责分类（与武器编辑的分类选择器相同），可选：全部阵营、虫族、机器人、光能者。
  - 选“全部阵营”时，列表按虫族、机器人、光能者的顺序排列，名称前标注阵营。
  - 各阵营的“所有虫族 / 所有机器人 / 所有光能者”倍率页仍在各自阵营的最前面。
- **敌人数据：** 一页“所有敌人”，是全局倍率：
  - 包括生命值、护甲、硬直抗性、眩晕与毒气抗性、受到的火焰伤害、伤害、移动速度、视野范围，与阵营倍率页的行相同。
  - 同时作用于虫族、机器人、光能者的全部敌人（不含 SEAF）。
  - 与各阵营页的倍率相乘，例如全局伤害 ×2、虫族伤害 ×1.5 时，虫族为 ×3；护甲的加值相加。
  - 在敌人自己页面上改过的数值保持不变。
- 伤害记录（DamageType / DamageInfo）属于游戏数据，不在这里。

## 倍率行作用于哪些字段

| 行 | 组件 / 数据 |
| --- | --- |
| 伤害 (x) | 敌人攻击引用的 DamageInfo 伤害记录（游戏数据）的伤害与耐久伤害 |
| 移动速度 (x) | AiEnemyComponentData 各 AI 状态的速度（警戒 +0、巡逻 +36、调查 +60、战斗 +100、横移 +124、漂移 +152、撤退 +244、冲锋 +276）与 AiCharacterComponentData 偏好速度 +0、最大速度 +4 |
| 视野范围 (x) | SensorEyeComponentData +0 |
| 生命值、护甲、抗性 | HealthComponentData、StatusEffectReceiverComponentData |

## AI设置

原来的占位改为以下组件的完整字段，每个组件一个标签。实体列表与“实体组件”页相同，左侧可按分类筛选。

| 标签 | 组件 | 字段 | 实体 |
| --- | --- | ---: | ---: |
| 敌人AI | AiEnemyComponentData（警戒、巡逻、调查、战斗、撤退、冲锋、沿曲线飞行、喊话、包抄、隐身、障碍能力、待机语音等） | 193 | 160 |
| 角色AI | AiCharacterComponentData（速度、群聚、转向控制、感知包围盒） | 22 | 201 |
| 视觉 | SensorEyeComponentData（与“实体组件 › 炮塔与制导”的视觉传感是同一组字段） | 11 | 315 |
| 听觉 | SensorEarComponentData | 7 | 187 |

SensorDanger、Targeting 已移至“生物组件”；AI设置保留敌人AI、角色AI、视觉、听觉四个标签。

“实体组件 › 生命与拆毁”新增“接触伤害”标签：OverlapDamageComponentData，385 个字段，64 个实体。每个实体 8 个伤害区域，包括击退、撞击伤害、拆毁强度、激活速度、忽略的实体等。

以上字段与敌人页、倍率页共用同一组字段，改一处另一处同步。

字段名由 `tools/component_gen/gen_enemy.py` 生成：
- 布局来自游戏类型库，并已用当前游戏数据核对（全部记录都能完整读出）；
- 名称与 RawData dump 按数值逐项核对，5 个组件共 59744 个值全部一致。
