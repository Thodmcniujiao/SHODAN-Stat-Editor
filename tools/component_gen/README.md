# 组件解析生成器

由游戏类型库与 [Darctor/Helldivers2_RawData](https://github.com/Darctor/Helldivers2_RawData) 的 dump 生成 `offline/weapon_components.lua`（武器类组件的完整字段表）。生成文件头部会写明这一来源。

1. 克隆 https://github.com/Darctor/Helldivers2_RawData 到本目录的 `Helldivers2_RawData`（或用环境变量 `RAWDATA` 指定），
   克隆 https://github.com/shalzuth/HelldiversData 到本目录的 `HelldiversData`（或用环境变量 `SHALZUTH` 指定）。
2. 解密游戏文件到 `work/`（或用环境变量 `COMPONENT_GEN_WORK` 指定）：

   ```
   python unseal.py ../../offline/gamedata.lua "<游戏目录>/data/game/dl_library.dl_typelib" work/typelib.bin
   python unseal.py ../../offline/gamedata.lua "<游戏目录>/data/game/generated_entities.dl_bin" work/entities.bin
   ```
   需要 `numpy` 与 `cryptography`。
3. `python gen.py`：逐层展开类型库中每个组件的记录，与 dump 的字段按全部实体的数值对齐取名（偏移变化后仍能对上），中文标签来自 `zh.py` 的词表，结果写入 `offline/weapon_components.lua`。
   dump 里没有名字的字段，再用 `shal.py` 从 2024 年的组件结构（shalzuth/HelldiversData）补名：结构名的哈希即类型哈希，
   成员按类型顺序（LCS）与当前类型库配对；整结构逐成员一致的标“结构一致”，否则标“按顺序推断”，与已有名字重复的不采用。
   两边名字相同的字段附上 2024 年的英文说明。公开资料都没有名字的字段（制导武器、屏幕、架设武器）在 `gen.py` 的 `OVERRIDE`
   里按各实体所用的数值写标签与说明，并注明是推断。

`walk.py` 展开结构，`align.py` 做数值对齐，`build_names.py` 合并字段名，`shal.py` 读取 2024 年结构，`zh.py` 是词表（新增词在此补充）。

`python -X utf8 gen.py --orbital` 使用相同的类型库、实体和参考数据生成 `offline/orbital_components.lua`。轨道字段分为持续时间与追踪、伤害区域、射弹生成、特效与音效、阵营过滤、移动轨迹、56 个二维控制点七组；四项既有参数保留 `beam_*` 保存 ID。该模式不会改写 `weapon_components.lua`。

## 任务组件与修饰符

- `python gen_mission.py`：生成 `offline/mission_components.lua`（任务编辑页的 GameModeComponent、HiveMindComponent、GameModeMissionComponent），沿用 `gen.py` 的流程。名称优先取 RawData 差异解码给出的字段名（`Data/entity_deltas`），其次取 2024 年结构的名称。GameModeComponent 的增援字段在脚本里按数值手动排定，并写有说明。词表在 `mission_zh.py`。
- `python gen_modifiers.py`：生成 `offline/modifier_data.lua`，内容包括：实体差异表的组件序号与组件类型的对应、差异改动字段的名称，以及差异和实体的显示名。数据都来自 RawData。

## 地狱舱组件

- `python gen_hellpod.py`：生成 `offline/hellpod_components.lua`（实体组件 › 地狱舱：HellpodComponent、HellpodPayloadComponent、HellpodRackComponent、ShipHellpodComponent），流程与 `gen_mission.py` 相同。
- 字段名来源：载荷和挂架取 RawData dump；下落组件的五个参数按额外页已在编辑的偏移写在 `MANUAL` 里，地狱舱变体和未知字段的说明写在 `OVERRIDE` 里，其余按 2024 年结构推断。
- 挂架载荷槽的物品标为实体引用。
- 词表在 `hellpod_zh.py`。

## 人物数据页

- `python check_avatar_doc.py`：核对“人物数据”页每一行的偏移和成员名。方法是用类型库展开绝地潜兵的 AvatarComponentData，与 RawData dump 逐值比对。说明见 `offline/PLAYER_DATA.md`。

## AI 与接触伤害组件

- `python gen_enemy.py`：生成 `offline/enemy_components.lua`，包含 AiEnemy、AiCharacter、SensorEar、SensorDanger 和 OverlapDamage 五个组件。
- `offline/ai_components.lua` 把它们和视觉组件 `sensor_eye_components.lua` 放进标签页：AiEnemy、AiCharacter、SensorEye、SensorEar 放在“生物设置 › AI设置”，SensorDanger 与 Targeting 放在“生物设置 › 生物组件”，OverlapDamage 放在“实体组件 › 接触伤害”。
- 字段名来自 RawData dump，按全部实体的数值对齐。
- 两处数值对齐出错，已按 dump 名字里自带的偏移在 `FIX` 中改正：
  - AiEnemy +0x264～+0x274：同一个名字被分给了两个成员；
  - +0x2B0～+0x2C2：dump 的未命名成员整体错开了一位。
- 改正后，5 个组件共 59744 个值与 RawData 逐项一致。
- 词表在 `enemy_zh.py`。

## 战备与载具相关组件

`python -X utf8 gen_stratagem_entities.py` 使用同一组 `COMPONENT_GEN_WORK`、`RAWDATA`、`SHALZUTH` 环境变量生成 `offline/stratagem_entity_specs.lua`：包含当前 272 类键值实体组件的记录大小和类型名称，以及 10 类载具、背包、制导等组件的命名字段。动态数组、字符串／指针和暂不支持的原始类型由运行时反射作为只读描述符显示；生成器不会把这些指针槽生成为可编辑字段。运行时 `stratagem_entity_editor.lua` 使用当前类型库补齐其他关联组件的内联字段并检查记录布局。

## 生物组件

`python -X utf8 gen_creature.py` 生成 `offline/creature_component_specs.lua`，包含 Unit、HitReact、StatusEffectReceiver、Locomotion、Rotation、MeleeAttack、DamageZoneShield、StatusEffectVolume、UnitCustomization、CharacterVoice 共 10 类、11244 个内联字段。Avatar 已由人物数据完整提供，不重复生成。环境变量和名称对齐来源与上面相同；同名字段以记录偏移补充保存 ID，动态数组和指针槽跳过。Locomotion、Rotation 的键值数组尾部有 4 字节对齐。

`offline/creature_components.lua` 负责导航和严格布局检查。9 类进入生物组件，复用 SensorDanger、Targeting 后共 11 个标签；CharacterVoice 放在人物数据。`tests/test_creature_components.lua` 核对当前类型库的布局、字段存储类型、边界与重叠，并按类型哈希确认生物组件与 AI设置没有重复；`tests/test_creature_browser.lua` 用实际游戏表验证导航归属、人物 Avatar 保留、语音修改与重置、实体归属、延迟建行、压制字段同步和原生界面，并导出已命名组件入口清单。

## 保留保存 ID 的参考名称补充

`python -X utf8 gen_reference_names.py` 用 `COMPONENT_GEN_WORK` 的类型库与 `SHALZUTH` 的组件结构生成 `offline/reference_component_names.lua`。只使用完整结构类型顺序匹配和唯一具名结构／枚举哈希锚点，不使用原始类型的 LCS 推测。运行时 `component_names.lua` 在布局指纹吻合时补充未知标签，保留旧 ID、字段类型与数字范围，供已有视图和通用实体反射共用。参考库缺失时生成器报错，避免静默遗漏。详见 `offline/COMPONENT_FIELD_NAMES.md`；覆盖报告默认写入 `COMPONENT_GEN_WORK/reference-names-audit.json`，运行时已有视图的覆盖与兼容性由 `tests/test_component_names.lua` 核对。
