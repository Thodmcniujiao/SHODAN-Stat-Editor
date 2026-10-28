# BeamType 激光组件

“游戏数据 → 激光 ID 修改”完整替换为 **激光类型（BeamType）**。当前 `BeamSettings → BeamInfo` 有 **30 条记录，每条 112 字节、25 个原生成员**，全部按当前类型库验证后显示。

组件仅展示激光自身字段。伤害 ID 和新版爆炸 ID 可编辑并双击跳转；激光自身 ID 为只读记录标识。

## 参考与版本差异

参考本机 `Data_Helldivers_IO_Backup/HelldiversData/data/components/BeamInfo.json`、`settings/generated_beam_settings.json` 和旧配置目录的 `SavedBeam.ini`。上游 [BeamInfo 定义](https://raw.githubusercontent.com/shalzuth/HelldiversData/master/data/components/BeamInfo.json) 也仍是相同的旧版 15 字段结构，不能直接当作当前偏移表。

旧版 15 个字段中有 14 个可对应到当前记录，旧 INI 的 BeamTypeID、Radius、Length、UseDamageID、SurfaceImpactType、EffectDamageType 六项全部覆盖。

**旧 `focal_shoulder_width` 无法唯一对应当前 +16～+36 的六个浮点成员。** 当前类型库中成员名已剥离；该区域按已验证偏移完整展示，明确标为未知字段，不把其中任意一项伪称为旧“聚焦肩宽”，也不添加无实际数据的占位行。其余旧字段的映射通过当前类型、顺序和历史数据交叉检查；旧版 14 条记录中，12 条在已映射的非枚举参数及三个资源哈希上完全匹配，另两条存在射程或停止音效事件的版本差异。旧值不导入当前记录。

## 当前字段

| 字段 | 偏移 | 类型 |
|---|---:|---|
| type：激光 ID | +0 | 只读 beam_id |
| radius：激光半径 | +4 | float32 |
| length：激光长度 | +8 | float32 |
| damage_info_type：伤害 ID | +12 | damage_id |
| 未知浮点数 | +16、20、24、28、32、36 | 六个独立 float32 |
| decal_size：贴花尺寸 | +40 | float32 |
| surface_impact_type：表面命中效果类型 | +44 | uint32 枚举 |
| beam_effect_path：激光特效资源哈希 | +48 | uint64 |
| falloff_effect_path：衰减特效资源哈希 | +56 | uint64 |
| beam_unit_path：激光实体资源哈希 | +64 | uint64 |
| audio_trail：持续音效事件 | +72 | uint32 |
| audio_trail_stop：停止音效事件 | +76 | uint32 |
| raycast_template：射线检测模板 | +80 | uint32 枚举 |
| overlap_beam_query：重叠碰撞查询 | +84 | uint32 |
| effect_damage_type：命中特效伤害类型 | +88 | uint32 枚举 |
| 未知浮点数 | +92 | float32，支持原始 -1 值 |
| 爆炸 ID（界面名 explosion_type） | +96 | 当前类型库明确为 ExplosionType |
| 未知标志位 | +100 bit 0 | 修改时保留同字节其他位 |
| 危险等级（界面名 danger_level） | +104 | 当前类型库明确为 DangerLevel |
| 未知标志位 | +108 bit 0 | 修改时保留同字节其他位 |

+96 和 +104 的界面别名依据实际枚举类型标注，提示说明该来源；不会因为某个数字碰巧等于其他表 ID 就误认引用。`effect_damage_type` 是视觉效果枚举，不标为 `damage_id`。

## 界面与编辑

组件标题使用高一级样式，下方按标识、激光几何、伤害引用、资源/特效、命中/贴花、音效、碰撞查询、爆炸引用、危险等级、未知字段分组。名称支持英文、简体和繁体；提示包含字段名、类型和偏移。

三个资源哈希以完整十进制 uint64 显示、输入，并以两个精确 uint32 分量保存到配置和预设。构建校验修正只允许真实 float32 成员参与，不把资源哈希或整数事件 ID 当作浮点数调整。记录数组解析支持构建时添加的校验修正尾部。

旧内联伤害的配置绑定继续保留，但页面不再展开 DamageType。重置当前激光不会重置所引用的伤害或爆炸记录。

## 验证

`tests/test_beam_components.lua` 检查 30 条记录、每条 25 项、旧版已映射/明确未映射字段及六项 INI 参数、实际枚举类型、逐字段字节边界、uint32 最大值、uint64 精度/溢出、配置和预设、伤害及爆炸实际双击跳转、重置隔离、构建校验与解密回读、尾部修正解析、实际语言切换、中英文渲染和最后一行可达性。

可通过 `SHODAN_BEAM_LEGACY_FIELDS` 提供按行列出的旧字段名称进行覆盖核对。验证使用隔离配置及内存缓冲区，不安装或写入游戏文件。
