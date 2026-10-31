# 生物组件与现有组件入口核查

核查日期：2026-10-30。数据来自本机安装的游戏 `generated_entities.dl_bin` 与 `dl_library.dl_typelib`，以实际加载结果为准。本次核查覆盖 `stratagem_entity_specs.ROOTS` 中 272 类键值实体组件，其中 61 类已有类型名称，其余 211 类仍以哈希命名；不代表游戏所有非实体表。

## 已补齐的生物入口

“敌人设置”更名为“生物设置”。“生物组件”紧邻“敌人替换器”左侧：

- 新增完整生物入口：Unit（单位）、HitReact、StatusEffectReceiver、Locomotion、Rotation、MeleeAttack、DamageZoneShield、StatusEffectVolume、UnitCustomization，共 9 类、11243 个内联字段。
- 复用并移动入口：SensorDanger（压制感知）、Targeting（瞄准与压制），不另建一套参数。两类合计 24 个字段。
- 原 AI设置保留 AiEnemy、AiCharacter、SensorEye、SensorEar；生命、阵营、护盾、接触伤害等保留原实体组件入口。
- Avatar 已由“人物数据 → 人物数据”完整提供，移除重复的“角色控制”入口；CharacterVoice 移至“人物数据 → 角色语音”，保留原字段和保存 ID。
- 生物组件现有 11 类已逐项按类型哈希检查，与 AI设置的 4 类组件没有交集；功能相关的不同组件没有合并，例如 Locomotion 与 AiCharacter 分属不同组件记录。
- EnemyPackage、LoadoutPackage 已在“杂项与预载 → 预载设置 → 敌人包／装备包”列出，因此没有重复新增到生物组件。

详细字段数、实体数及压制字段归属见 [ENEMY_DATA.md](ENEMY_DATA.md)。

## 已加载、但没有独立标签的 9 类

这些组件已进入当前通用实体解析器。只有从已选战备能够到达其所属实体时，才在“军械库 → 战备编辑”的关联实体组件中显示；尚无单独的全实体浏览标签。关联组件仍按所属实体分开，未命名组件单独置底。

| 组件 | 类型哈希 | 实际加载实体 | 当前用途／入口 |
| --- | --- | ---: | --- |
| SpawnOnPlayersComponentData | 10BF0FB3 | 29 | 玩家相关生成；关联实体反射，尚未放入刷怪组件标签 |
| WeatherControlComponentData | 5CB52A3E | 9 | 天气控制；关联实体反射 |
| EncyclopediaEntryComponentData | 8A40FE2F | 675 | 百科条目；关联实体的已命名组件 |
| StickyComponentData | 9AF175A4 | 19 | 附着；武器／战备关联实体 |
| DisplacementComponentData | A7813546 | 1 | 位移；战备关联实体 |
| SeekingMissileComponentData | BF3A6789 | 29 | 制导导弹；武器／战备关联实体 |
| DepositComponentData | C435BA85 | 30 | 背包补给与释放；战备关联实体 |
| VehicleComponentData | EAEB2B0D | 20 | 载具；战备编辑中的载具实体 |
| ExplosiveComponentData | F5CF9B8C | 71 | 爆炸实体；武器／战备关联实体 |

这 9 类没有混入生物组件；它们分别属于生成、环境、资料、武器和战备。已命名的 61 类中，50 类存在明确的浏览入口或专用编辑入口，其中 49 类的实体表本次加载成功；另 9 类加载成功但仅通过关联实体访问。

## 已有类型名称、但当前表尚未成功加载的 3 类

| 组件 | 类型哈希 | 当前入口 | 核查结果 |
| --- | --- | --- | --- |
| WeaponWielderComponentData | 1F5AB323 | 实体组件 → 武器配件 | 已有入口；当前键值表解析未匹配，不能把空列表解释为游戏不存在该组件 |
| ObjectiveSecureAreaComponentData | 5634CD08 | 无独立入口 | 已登记记录大小，当前键值表解析未匹配 |
| ResourceDependencyComponentData | 904F65F4 | 无独立入口 | 已登记记录大小，当前键值表解析未匹配 |

以上三类保持原有行为；未把未经校验的字节作为可编辑字段开放。生成的 10 类组件（9 类生物组件与 CharacterVoice）均已通过完整类型布局校验并实际加载，包含此前需要补齐尾部对齐的 Locomotion 与 Rotation。

## 复核方法

运行 `tests/test_creature_browser.lua`，使用隔离配置和实际游戏数据，会在 `TEST_WORK/component-audit.json` 导出 61 类组件的类型、哈希、记录大小、加载状态、实体数和入口。测试同时检查 11 个生物标签与 AI设置去重、Avatar 沿用原人物数据入口、语音导航迁移与读写、逐实体字段归属、延迟建行、压制参数共享、星号与重置，并生成原生界面截图。`tests/test_creature_components.lua` 单独检查 11244 个生成字段的布局、类型、边界、重复 ID 和字节重叠。
