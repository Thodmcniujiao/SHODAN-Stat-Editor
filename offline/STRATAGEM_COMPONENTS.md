# StratagemType / 战备类型参数

三个入口使用同一套当前游戏数据，并共用同一组参数分类（`stratagem_components.lua` 的 `M.GROUPS`）：

- 轨道飞鹰 → 轨道编辑：组件组“轨道组件”默认展开；`StratagemType` 和 `BombardmentType` 组件默认折叠。
- 轨道飞鹰 → 飞鹰编辑：组件组“飞鹰组件”默认展开；`StratagemType`、`EagleComponentData`、`EagleSpawnerComponentData` 组件默认折叠。
- 游戏数据 → 战备id → 战备id：按 StratagemTypeID 浏览当前全部记录；字段使用同一套参数组。

## 共享参数组

| 组 | 包含字段（节选） |
|---|---|
| 标识与名称 `identity` | StratagemTypeID、Name、RecordID、VideoID、NameUpperTextID、NameCasedTextID、DescriptionTextID、FluffTextID、LoadingTextID |
| 呼叫指令 `callin` | button_combination、Button1–Button9 |
| 分类与消耗 `category` | Category、Uses、Cost、MaxInLoadout、IsEnabled、HUDType、BeaconColor |
| 冷却与投放 `timing` | SpawnTime、SpawnRadius、BeaconingTime、ExtraTravelTime、Cooldown、CooldownIfFail、CooldownType、AltCooldown、ExtraHellpods |
| 来源与呼叫方式 `origin` | OriginType、CallInType、ObjectiveRequirement、StratagemFlags、ShipLaserPointer |
| 载荷与资源 `payload` | PayloadSpawnPosition、Payload1–PayloadN、Package、Icon、PayloadUnitCustomization |
| 依赖与关联 `links` | DependsOnStratagemID、AdditionalStratagemID、MatchingSupportWeapon、DamageDealer、DLCPackID、SharedStratagemUpgradesType、SharedStratagemUpgradesCategories |
| 标志与条件 `flags` | MissionSpecific、Selectable、TriggersWar、IsClanStratagem、InfoFlags、AllowForButtonOverlap、DeployOnNavmeshOnly、Field_208、Field_296_Bit1 |
| 语音与音效 `audio` | ReadyVO、DeniedVO、ConfirmationVOOwner、CalloutVO、SpottableVOLine |
| 数组与自定义 `arrays` | HellpodTargetOffset、HellpodAdditionalRotationInTau、EquipmentTags、Customizations、Field_280、Field_376 |
| 未知字段 `unknown` | 未识别的 `Field_*` 等 |

组顺序固定；所有页面都按这个顺序排列同一组件的字段，不再各自定义分类。组件组标题始终可见（默认展开），组件本身默认折叠。

英文、简体中文和繁体中文界面均有参数名；悬停说明同时保留英文原字段名和中文含义。
切换语言即可更新名称。未知语义的新增字段标为“未知字段 +偏移 / Unknown field +offset”，不猜测其作用。

实际结构为 `StratagemInfo`，其中 `type` 是 `StratagemType` 枚举。
当前记录 **400 字节、67 个类型库成员**。读取和编辑前核对当前类型库的成员偏移、长度、存储类型和位布局。
旧 INI 只用作字段名称参考，不套用旧版本编号、偏移或默认值。

下表覆盖当前 400 字节记录的 **67 个字段**（含类型库已知的额外字段）。偏移均相对于当前 StratagemInfo 记录起点。

| INI 字段 | 中文名 | 当前存储 |
|---|---|---|
| StratagemTypeID | 战备类型 ID | +0，u32 枚举，只读标识 |
| Name | 战备名称（调试名） | +16，字符串指针，显示实际字符串，只读 |
| Button1–Button9 | 指令方向 1–9 | +64 的动态方向数组；真实长度在 +72 |
| Category | 战备类别 | +60，u32 枚举 |
| Uses | 使用次数 | +80，u32；以有符号视图显示 `0xFFFFFFFF = -1`（无限） |
| SpawnTime | 投放前倒计时，秒 | +84，f32 |
| SpawnRadius | 生成半径，米 | +88，f32 |
| BeaconingTime | 信标持续时间，秒 | +96，f32 |
| ExtraTravelTime | 额外运输时间，秒 | +100，f32 |
| Cooldown | 冷却时间，秒 | +104，f32 |
| CooldownIfFail | 呼叫失败冷却，秒 | +108，f32 |
| OriginType | 发射来源类型 | +112，u32 枚举 |
| CallInType | 呼叫方式类型 | +116，u32 枚举 |
| ObjectiveRequirement | 目标投放条件 | +124，u32 枚举 |
| StratagemFlags | 呼叫逻辑标志 | +120，**u16**，不是 +260 的战备信息标志 |
| CooldownType | 冷却共享类型 | +148，u32 枚举 |
| PayloadSpawnPosition | 载荷数量（旧工具的字段名） | +160，载荷动态数组的长度，只读 |
| Payload1、Payload2 | 载荷实体哈希 1、2 | +152 动态数组指向的 u64 元素，按真实长度访问 |
| Package | 资源包哈希 | +168，u64 |
| Icon | 图标资源哈希 | +176，u64 |
| HUDType | HUD 显示类型 | +184，u32 枚举 |
| Cost | 消耗点数 | +188，u32 的有符号视图，支持 -1 哨兵值 |
| IsEnabled | 启用战备 | +192，位 0 |
| DependsOnStratagemID | 依赖战备 ID | +196，StratagemType 引用 |
| AdditionalStratagemID | 附加战备 ID | +200，StratagemType 引用，沿用已有循环依赖检查 |
| MaxInLoadout | 装备栏携带上限 | +204，u32 |
| BeaconColor | 信标颜色 | +212，u32 枚举 |
| ShipLaserPointer | 舰船激光指示 | +216，位 0 |
| AltCooldown | 使用备用冷却 | +296，位 0 |
| ExtraHellpods | 额外地狱潜舱数量 | +300，u32 |

`PayloadSpawnPosition` 的名字容易误导。对提供的旧 SavedStratagem.ini 和本地旧版本数据按名称匹配，
100 条匹配记录的这个值全部等于 `payload` 数组的长度，包括 0、1、2、3、6。
当前类型库也明确把 +152 定义为动态 u64 数组，+160 是它的长度。
因此保留旧字段名供对照，并显示“载荷数量”；不会把它解释为一个空间位置枚举。
长度是结构信息，界面只读，避免仅修改计数而越过已分配数组。

每条记录至少显示 Payload1、Payload2；不存在的槽位显示 `0（无此槽位）`。
实际载荷多于两项时，会继续显示 Payload3 等。
载荷、资源包、图标等完整 u64 可直接输入十进制值，支持到 `18446744073709551615`。
内部用两个精确 u32 字段保存配置和预设，避免浮点精度丢失；生成游戏文件时也不把这些整数误当作浮点校验盐。

Button1–Button9 只按真实数组长度取值，剩余槽位显示 0。
方向值为 1 上、2 右、3 下、4 左；0 结束指令，不能在前面留下空槽后填写后面的方向。
单槽编辑与“录制指令”共用一个保存值，R 恢复整条原始指令。
生成文件时会为增长的方向数组分配空间，也支持原来没有指令的记录。

“其他字段”组另外显示：记录 ID、视频和本地化文本 ID、任务专用/可选/战争状态标志、
语音 ID、伤害归属实体、关联支援武器、DLC、公会、信息标志、共享升级类型、
潜舱目标偏移、额外旋转、装备标签、自定义数组及当前新增但尚无可靠语义名的字段。
结构标识、调试字符串和复杂数组只读；复杂数组按真实计数显示，未知结构保留十六进制内容。
位开关只修改自己的位，保留相邻位和填充字节。

验证见 `tests/test_stratagem_components.lua`：当前 153 条记录的 39 个参考字段、三个入口、
中英繁体切换、逐字段字节范围、位保护、u64 极值/溢出/预设/配置、指令数组重建、
完整封装后的哈希和资源引用回读，以及 GDI 界面绘制。测试只操作隔离内存和测试目录，不写入游戏文件。
