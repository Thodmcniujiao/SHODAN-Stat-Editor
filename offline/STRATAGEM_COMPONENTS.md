# StratagemType / 战备类型参数

以下入口使用同一套当前游戏数据，并共用同一组参数分类（`stratagem_components.lua` 的 `M.GROUPS`）：

- 轨道飞鹰 → 轨道编辑：组件组“轨道组件”默认展开；`StratagemType` 和 `BombardmentType` 组件默认折叠。
- 轨道飞鹰 → 飞鹰编辑：组件组“飞鹰组件”默认展开；`StratagemType`、`EagleComponentData`、`EagleSpawnerComponentData` 组件默认折叠。
- 游戏数据 → 战备id → 战备id：按 StratagemTypeID 浏览当前全部记录；字段使用同一套参数组。
- 军械库 → 战备编辑 → 战略配备／载具：入口位于“武器配件自定义”右侧；原“游戏数据 → 战备id”中的这两个列表迁至此处。战备定义和关联 ECS 组件按类别排列，组件默认折叠。

## 军械库中的战备相关组件

“战备编辑”保留原有战略配备、载具以及载具下的挂载武器列表；“游戏数据 → 战备id”只保留原始 StratagemTypeID 记录目录。原保存 ID、旧参数别名与实体哈希保留，导航、引用跳转和预设详情自动跟随新入口。

- 分类：战备定义、载具组件、武器组件、瞄准与制导、生命与防护、载荷与挂载、其他已命名组件。未命名组件单独组成最底部的“未命名组件”组，已命名组件不会排在其下或混入此组。
- 归档物理参数独立折叠为“载具操控（物理）”“车轮与悬挂（物理）”；悬停参数查看调高、调低对驾驶的影响。按实体各自的物理文件编辑，不合并关联实体。机甲移动使用明确标注的共用状态机组。
- 每个实体有独立条目，右侧说明行明确标出当前实体哈希；该条目只显示索引归属于本实体的组件。主体不会汇总炮塔、武器、背包等其他实体的组件。每个组件默认折叠，展开时才生成字段，改动后收起仍显示星号。
- 关联实体来自战备载荷、本体、双生载具、护卫犬及其武器，并沿类型库确认的 64 位实体引用继续追踪地狱舱挂架、背包物品、炮塔和挂载武器。只有引用值确实对应当前实体目录中的实体才继续追踪，循环引用会去重。
- 关联图用于发现可查看的实体，不用于推断组件归属。多处引用同一实体时，每个分类列表中只列一个该实体条目；双向引用和循环引用也不会复制实体或把它的组件归入主体。
- “实体引用关系”组区分引用、被引用、双向引用及战备载荷引用，可点击“查看实体”跳转。引用关系不宣称父子结构，也不宣称组件继承。
- 纯战备定义没有明确实体身份时，仅显示定义和实体引用；载荷、护卫犬、背包挂架等均在各自实体条目中。载具定义有明确主体实体时，显示该主体自己的组件及独立的战备定义组。
- 旧版跨实体汇总参数仅保留隐藏保存别名，兼容原配置，不在主体组件表重复显示。改动星号和“重置本页”按本实体组件范围计算；重置主体不会清除子实体参数。若两个实体在游戏数据中共用同一组件记录，仍共享其真实字段，并在组件标题显示“共用记录”及实体数量，不复制或伪造私有数据。
- 对当前实体数据中的 **272 类键值组件**逐类核对记录大小、成员位置和存储类型。已有武器、生命、护盾、挂载等组件复用原解析和字段对象；载具、背包补给、追踪导弹、目标瞄准等 10 类补充完整命名字段表。
- 其他组件依照当前类型库逐层解析内联结构、定长数组、枚举和位字段。没有确认名称的成员显示偏移和类型；未命名组件显示类型哈希，不猜测用途。
- 动态数组描述符、字符串指针及编辑器不支持的整数／浮点宽度显示为只读，不把指针作为可编辑资源哈希。数组中的实体引用只在当前表范围内解析，检查数量和边界。
- 新字段与原页共用字段对象和规范保存位置；旧汇总项仍保留为兼容别名。编辑、恢复、页面重置、配置保存和全局预设继续使用现有流程。组件未展开时也能恢复保存的参数。

运行时实体目录、归属过滤与反射实现为 `stratagem_entity_editor.lua`；`stratagem_entity_specs.lua` 由 `tools/component_gen/gen_stratagem_entities.py` 从当前类型库及本地 RawData 生成。隔离测试覆盖实际载具、哨戒炮、护卫犬、挂载武器，配置重启恢复、原始字段共享及中英文原生界面渲染；不写入真实游戏文件。

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
