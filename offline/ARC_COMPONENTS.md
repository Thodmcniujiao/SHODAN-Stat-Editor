# ArcType 电弧组件

“游戏数据 → 电弧 ID 修改”完整替换为 **电弧类型（ArcType）**，对应 `ArcSettings → ArcInfo`。当前 **16 条记录、每条 104 字节、21 个参数**全部显示。仅展示电弧自身数据，伤害使用可编辑的 `damage_id` 引用，双击跳转到对应伤害记录。

## 旧版参考

解析参考 `Data_Helldivers_IO_Backup/HelldiversData/data/components/ArcInfo.json` 的 18 个字段和 `settings/generated_arc_settings.json` 的 11 条旧版解密记录，以及旧配置目录下的 `SavedArc.ini`。

旧 INI 的 12 个参数均已映射：ArcTypeID、Speed、Distance、MaxAngleSpreadDistance、FirstShotMaxAngleSpreadDistance、MaxAngleSpread、FirstShotMaxAngleSpread、MaxChainLength、MaxChainSplit、UseDamageID、HitEffectType、DemolitionStrength。

11 条旧版记录的四个资源哈希、残留时间及全部非枚举标量均能在当前数据中找到一致记录。旧版枚举 ID 可能变化，旧数据仅作为字段含义参考，不导入参数值或执行自动应用开关。偏移、类型、位宽及新增成员以当前类型库验证结果为准。

## 当前字段

| 参数 | 偏移 | 类型 |
|---|---:|---|
| type：电弧 ID | +0 | 只读记录 ID |
| speed：传播速度 | +4 | float32 |
| distance：射程 | +8 | float32 |
| distance_at_max_angle_spread：最大扩散角对应距离 | +12 | float32 |
| distance_at_max_angle_spread_first_shot：首发最大扩散角对应距离 | +16 | float32 |
| max_angle_spread：最大扩散角 | +20 | float32 |
| max_angle_spread_first_shot：首发最大扩散角 | +24 | float32 |
| max_chain_length：最大连锁长度 | +28 | uint32 |
| max_chain_split：最大连锁分叉数 | +32 | uint32 |
| damage_info_type：伤害 ID | +36 | damage_id |
| camera_shake_path：镜头震动资源哈希 | +40 | uint64 |
| particle_effect_path：粒子特效资源哈希 | +48 | uint64 |
| particle_linger_time：粒子特效残留时间 | +56 | float32 |
| explosion_effect_path：爆炸特效资源哈希 | +64 | uint64 |
| hit_effect_damage_type：命中特效伤害类型 | +72 | uint32 枚举 |
| hit_audio_event：命中音效事件 ID | +76 | uint32 |
| bolt_path：电弧实体资源哈希 | +80 | uint64 |
| demolition_strength：电弧破坏力 | +88 | uint32 |
| unk_bool_0x005C：未知标志位 | +92 bit 0 | 保留同字节其他位 |
| unk_uint32_0x0060：未知整数 | +96 | uint32 |
| unk_bool_0x0064：未知标志位 | +100 bit 0 | 保留同字节其他位 |

最后三个为当前版本新增、含义尚未确认的成员，按偏移命名。`explosion_effect_path` 是粒子特效资源哈希，不是 `explosion_id`；`hit_effect_damage_type` 是视觉效果枚举，不是 `damage_id`。

## 界面与兼容

组件标题使用高一级样式，下面按标识、传播/射程、扩散、连锁、伤害引用、资源/特效、命中效果/破坏、未知字段分组。每项都有英文、简体、繁体名称，提示保留原始名称、偏移和类型。

四个 uint64 资源哈希完整显示和输入十进制，配置与预设用两个精确 uint32 分量存储，避免浮点数精度损失。文件校验修正仅使用真实 float32 成员，不调整资源哈希或整数 ID。电弧数组允许记录后的校验修正尾部，以便资源哈希修改后的文件仍可读取。

保留 `arc_range`、`arc_chain`、`arc_split` 配置键；旧内联伤害绑定也继续保留。页面不展开关联 DamageType，重置当前电弧不会重置关联伤害记录。

## 验证

`tests/test_arc_components.lua` 检查当前全部 16 条记录及每条 21 项、旧版 18 个解密字段和 12 个 INI 参数映射、逐字段写入边界、uint32 最大值、完整 uint64 及溢出、实际伤害 ID 双击跳转、重置隔离、配置/预设、构建校验与解密回读、尾部修正字节解析、实际语言切换、中英文绘制及最后一行可达性。

可用环境变量 `SHODAN_ARC_LEGACY_FIELDS` 提供按行列出的旧版字段名称，检查参考字段覆盖。验证全部使用隔离配置及内存缓冲区，不安装或写入游戏文件。
