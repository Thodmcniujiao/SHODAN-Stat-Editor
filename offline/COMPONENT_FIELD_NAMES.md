# 组件未知字段补名

核查日期：2026-10-30。

## 为什么会有未知字段

1. 当前类型库能提供类型哈希、字段位置、宽度、数组及嵌套关系，但本机文件中没有 Unit、scale_min 等原始名称明文。
2. RawData 本身也有 `unk_*` 字段；按类型库读出数值不等于知道其含义。
3. 旧参考结构和当前游戏并非完全一致。新字段、已移除字段、相同原始类型的重复成员不能仅靠顺序猜名字。
4. 原生成器的 shalzuth 参考目录曾缺失，并且读取不到 JSON 时静默跳过，近期生成的部分视图因此漏掉了可补的名称。现在已补齐参考数据，并改为缺失时明确报错。

## 来源和匹配边界

参考用户指定的 [Helldivers 2 Data Debug](https://helldivers-data-44t6hul39-shalzuths-projects.vercel.app/) 及其 [shalzuth/HelldiversData 原始数据](https://github.com/shalzuth/HelldiversData/tree/0d18368a707a048d153aec7918f6c12127652283)。固定参考提交为 `0d18368a707a048d153aec7918f6c12127652283`；UnitComponent、CharacterVoiceComponent、StatusEffectReceiverComponent 三份 JSON 已与该部署逐字节核对一致。原始参考数据的许可证随包放在 `REFERENCE_NAMES_LICENSE.txt`。

只采用两种有明确结构依据的映射：

- 同一结构类型哈希，整个结构的成员数、成员类型、结构／枚举类型哈希、数组属性和顺序一致时，采用其字段名。
- 结构发生变化时，只采用两边各出现一次、类型哈希完全相同的具名嵌套结构或枚举作为锚点；不会把重复 float、uint 或相似枚举按最长公共子序列猜配。

运行时还核对当前记录及所有嵌套结构的布局指纹，包括成员偏移、大小、存储类型、数组／位域属性、数量与类型哈希。更新后指纹不符就不补名。动态数组／指针描述符和无法对应的位域不作为数字字段补名；旧枚举值不直接覆盖当前动态编号。

补名只改显示标签、参数组标题和悬停说明，保留原字段路径、保存 ID、偏移、存储类型、上下界、实体归属和预设格式。按部位／状态展开的数组保留编号，避免不同项显示为相同短标签。已存在的有效标签保留。

## 本次结果

已在 208 类组件表中建立 23867 个可核对的内联字段位置映射。其中，当前现有视图可补充名称或说明的唯一字段位置为 **6233 项**，包含按部位、状态展开后的数组项，不代表 6233 种不同语义。

| 组件 | 补充字段位置 |
| --- | ---: |
| 状态接收 StatusEffectReceiver | 4472 |
| 部位护盾 DamageZoneShield | 740 |
| 武器自定义 WeaponCustomization | 500 |
| 移动运动 Locomotion | 230 |
| 单位自定义 UnitCustomization | 135 |
| 载具 Vehicle | 64 |
| 单位 Unit | 33 |
| 飞鹰 Eagle | 32 |
| 生命 Health | 7 |
| 制导导弹 SeekingMissile | 6 |
| 转向旋转 Rotation | 5 |
| 生成器 AiSpawner | 3 |
| 敌人调度 HiveMind | 3 |
| 角色语音 CharacterVoice | 1 |
| 装备 Equipment | 1 |
| 接触伤害 OverlapDamage | 1 |

例如 Unit 的资源路径、最小／最大缩放、半径、隐藏与随机显示可见组、热加入时尸体修复能力，以及 CharacterVoice 的语音前缀类型已补名。MeleeAttack 的新旧成员数不同、AbilityId 又重复出现，不采用旧顺序给当前未知项命名。剩余未知项继续显示原类型和偏移。

## 维护与验证

- `tools/component_gen/gen_reference_names.py`：从本机类型库和固定参考数据生成显示名称补充表，不重生成已有保存 ID。
- `offline/reference_component_names.lua`：生成结果。
- `offline/component_names.lua`：运行时布局核对及显示元数据应用；通用组件浏览器、生命组件、战备关联实体视图复用，护盾的专用视图也已接入。
- `tests/test_component_names.lua`：逐一确认 23867 个位置是实际内联字段，验证保存 ID／类型／偏移／范围不变、变化布局拒绝、歧义原始类型拒绝，并生成 `TEST_WORK/name-coverage.json`。

实际游戏数据的生物／人物语音界面、战备实体归属、配置与预设往返、数字类型边界及原生宿主启动已通过回归。测试使用隔离配置，不写入实际游戏文件。
