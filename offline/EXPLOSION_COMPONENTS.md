# ExplosionType 爆炸组件

“游戏数据 → 爆炸 ID 修改”完整替换为 **爆炸类型（ExplosionType）**，对应 `ExplosionSettings → ExplosionInfo`。本页只展示爆炸自身数据，伤害、破片射弹和电弧通过 ID 引用编辑及双击跳转，不内联展开其他组件。

## 参考来源与当前布局

解析同时参考了旧版解密文件：

- `Data_Helldivers_IO_Backup/HelldiversData/data/components/ExplosionInfo.json`：28 个已命名成员。
- 同目录树的 `settings/generated_explosion_settings.json`：249 条旧版解密记录，包括完整资源哈希、震屏资源数组及标志位。
- `mipm/legacy/dist/profiles/客机端，1v3 v0.3.1a 全预载版 毒辣宝贝 必带毒镖手枪 轨道毒 喷毒器/SavedExplosion.ini`：12 个爆炸参数名。

旧文件仅用于确认字段含义与历史参数覆盖；不导入其值，也不执行其中的自动应用开关。当前类型库确认 **152 字节、40 个原生成员**，所有成员均已显示。界面额外提供 4 个标志字节的整体数值，因此每条记录是 **44 个固定项，加实际震屏资源数组元素**。

当前 424 条记录共含 458 个震屏资源元素，数组长度为 0–2。将旧版记录按半径与特效资源特征关联到新版，有 236 条仍可匹配，其中 52 条的非枚举标量、旧标志位与震屏资源列表也全部一致。旧枚举 ID 会随版本变化，不按旧编号直接替换新记录。

## 已确认的旧版参数

| 字段 | 当前偏移 | 类型 |
|---|---:|---|
| type / ExplosionTypeID | +0 | 只读爆炸记录 ID |
| damage_type / UseDamageID | +4 | damage_id |
| fallback_damage_loc_name | +8 | uint32 |
| inner_radius / InnerRadius | +16 | float32 |
| outer_radius / OuterRadius | +20 | float32 |
| stagger_radius / StaggerRadius | +24 | float32 |
| cone_angle / ConeAngle | +28 | float32 |
| camera_shake_radius / CameraShakeRadius | +32 | float32 |
| shake_assets | +40 | 动态 uint64 数组；数量只读，已有元素可编辑 |
| particle_effect_path | +56 | uint64 精确十进制资源哈希 |
| audio_event | +64 | uint32 |
| crater_type / CraterType | +68 | **int8 枚举** |
| surface_impact_type / SurfaceImpactType | +72 | uint32 枚举 |
| hit_effect_damage_type / HitEffectDamageType | +76 | uint32 枚举 |
| num_shrapnel_projectiles / ShrapnelAmount | +80 | uint32 |
| shrapnel_projectile_type / ShrapnelProjectileID | +84 | projectile_id |
| noise_template | +88 | **uint8 枚举** |
| wind_effect_template | +92 | uint32 枚举 |
| fire_template | +96 | uint32 枚举 |
| persistent_status_volume | +100 | uint32 模板枚举 |
| status_volume_effect_time | +104 | float32 |
| status_volume_effect_audio_play | +108 | uint32 |
| status_volume_effect_audio_stop | +112 | uint32 |
| do_knockback | +116 bit 0 | 启用击退 |
| disable_default_surface_impact | +116 bit 1 | 禁用默认表面命中特效 |
| is_huge_explosion | +116 bit 2 | 巨型爆炸 |
| look_for_audio_source_hijack | +116 bit 3 | 查找音源接管 |
| requires_raycast_confirmation | +116 bit 4 | 需要射线确认 |

`crater_type` 和 `noise_template` 均严格按单字节读取/写入，不将相邻填充或参数一起覆盖。旧标志位位于同一个字节，不作为五个独立字节写入。

## 当前新增成员

- +12 bit 0：未知标志位。
- +116 bit 5：未知标志位。
- +120：`arc_type`，电弧 ID，可编辑并双击跳转。
- +124 bit 0–1、+132 bit 0–1、+140 bit 0–1：未知标志位。
- +128、+136：未知 float32。
- +144：未知 uint32 枚举。

当前成员名称尚未确认的项目明确标注“未知”及偏移；不从相近名字猜测含义。+116、+124、+132、+140 的原始 uint8 值与各个位开关共用同一数据字段；配置/预设只保存原始值，位修改保留其余位，包括未命名位。

`persistent_status_volume` 是区域模板枚举，`hit_effect_damage_type` 是命中特效枚举，均不标成 `status_effect_id` 或 `damage_id`。

## 编辑和兼容

组件按标识、伤害引用、半径/形状、镜头震动、特效/音效、表面效果、破片、模板、持续状态区域、标志、电弧引用和未知字段分组。每项有英文、简体、繁体名称；提示保留原始字段名、偏移、存储类型。

震屏数组只读取当前序列化数量，验证指针及元素范围处于所属表尾部；空数组不虚构槽位。已有资源哈希支持完整 uint64 十进制输入，不经过浮点数近似。数量/指针作为结构信息只读，不进行未分配内存的数组扩展。

保留原 `inner`、`outer`、`shockwave`、`cone`、`shake`、`shrapnel_count`、`shrapnel_projectile` 等配置键；原内联伤害的配置绑定继续保留。重置当前爆炸只处理本页自身字段，不重置所引用的伤害、射弹或电弧。

文件构建时仅允许实际 float32 成员参与浮点校验修正，资源哈希、数组资源元素和整数 ID 保持精确。

## 验证

`tests/test_explosion_components.lua` 检查全部 424 条当前记录及所有 40 个原生成员、旧版 28 个字段和 12 个 INI 参数映射、逐字段写入边界、int8/uint8 单字节行为、原始标志值与位开关、数组边界和精确 uint64、配置/预设、伤害/射弹/电弧实际双击跳转、重置隔离、构建校验及解密回读、中英文渲染和滚动到底。

环境变量 `SHODAN_EXPLOSION_LEGACY_FIELDS` 可指向按行列出旧版解密成员名称的文件，检查旧字段覆盖。所有验证使用隔离配置与内存缓冲区，不安装或写入游戏文件。
