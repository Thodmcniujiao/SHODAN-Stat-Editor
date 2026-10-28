# 轨道武器编辑：完整组件参数

入口：轨道飞鹰 → 轨道武器编辑。使用 `OrbitalAbilityComponentData`（类型哈希 `0x936A9C08`），当前游戏记录长 568 字节。页面遍历组件表的所有实体，而非只从战备列表的载荷中筛选。

当前数据有两条记录：轨道激光炮（EntityHash `17020640004553544635`）与轨道炮攻击（`12399142748360190921`）。每条记录显示 140 个可编辑字段及只读的完整十进制 EntityHash。轨道轰炸的弹幕、齐射和散布参数位于相邻的“轨道编辑”子页。

| 分组 | 字段与偏移 |
| --- | --- |
| 持续时间与追踪（5） | duration +460、remove_time +464、movement_speed +468、search_radius +472、target_list_update_time +544 |
| 伤害区域（7） | damage_info_type +476、interval +480、shape +484、size X/Y/Z +488/+492/+496、gib_corpses +500 |
| 射弹生成（3） | projectile_type +532、projectile_spawn_height +536、projectile_spawn_delay +540 |
| 特效与音效（6） | surface_impact +504、noise_hit_template +508（单字节）、ship_effect +512（完整 u64）、ship_effect_is_laser_pointer +520、audio_event_start +524、audio_event_stop +528 |
| 目标阵营过滤（4） | factions[0..3].faction +548/+552/+556/+560 |
| 移动轨迹（3） | pattern_segments +0、smooth_segments +4（单字节）、segment_pause +456 |
| 轨迹控制点（112） | pattern_control_points[0..55].x/y；+8 起，每个控制点 8 字节，最后一个 Y 在 +452 |

以上覆盖 SavedOrbitalWeapon.ini 中的全部 19 个数值字段，并补齐该菜单未显示的 112 个坐标、4 个阵营字段、尸体碎解开关、地面噪音模板、舰船特效资源及开始/结束音效。

伤害 ID、射弹 ID 显示引用类型，单击编辑，双击跳转至游戏数据中的对应记录。引用记录的伤害、爆炸等参数在目标页编辑，不会被当前武器的重置操作连带清除。0 保留为无引用；不存在的目标 ID 会被拒绝。

资源哈希拆成两个 u32 存储，界面以精确十进制 u64 输入，避免浮点舍入。布尔、噪音枚举按真实单字节读写，不覆盖相邻字段。持续时间、追踪速度、搜索半径及伤害间隔保留旧页面哈希和 `beam_duration` / `beam_speed` / `beam_radius` / `beam_tick` 保存键，沿用既有配置及预设。

完整字段开放前，检查安装游戏的类型库、568 字节记录布局和嵌套结构。如果布局不一致，则保留原四项参数，页面及日志提示原因。不会在无法核对布局时把扩展字段写入旧记录。

数据布局取自本机游戏的 `dl_library.dl_typelib`、`generated_entities.dl_bin`；字段名称按 [Darctor/Helldivers2_RawData](https://github.com/Darctor/Helldivers2_RawData/blob/main/Data/entities/OrbitalAbilityComponentData.json) 的 1.007.200 / 2026-10-20 导出逐实体数值对齐，并参考本地 [shalzuth/HelldiversData](https://github.com/shalzuth/HelldiversData) 的旧结构说明。字段名和配置值不代表已验证的实战机制。

验证：`tests/test_orbital_components.lua` 使用隔离配置，检查两条记录的全部字段、112 个控制点、相邻字节保护、完整 u64、配置/预设/重置、双击跳转及中英文滚动渲染；在内存中构建、解密并核对实体文件的编辑记录与原校验和。测试不安装修改到游戏。
