# 本地环境实体列表与八槽效果 ID 的区别

核对对象：已安装的 01.007.201 类型库、55 个 `data/game/*.dl_bin` 文件，以及 [Darctor/Helldivers2_RawData](https://github.com/Darctor/Helldivers2_RawData) 的 01.007.200 实体差异转储（commit `18ea7f865d0f5b25bd988e4552a6335f3bd2d7df`）。不读写游戏进程，不发送网络请求或 RPC。

## 新界面

“星球任务 → 本地环境实体”有两个分类。此前叫“修饰符挂载”，容易与旧内存编辑器的八槽效果 ID 混淆，现已更正：

| 分类 | 记录数 | 来源 | 数组描述符位置 |
| --- | ---: | --- | --- |
| 星球环境实体 | 438 | generated_planet_data.dl_bin / LevelGenerationPlanetData | +0x1A8 |
| 事件实体列表（实验） | 137 | generated_galactic_presence_settings.dl_bin / GalacticPresenceSettings | A：+0x1F8；B：+0x2C0 |

## 用户要求的八个槽位

已静态读取用户本地 `CT tables/Havoc_Experimental_v3.8.1.CT` 的 XML 元数据，未执行其中脚本。`Planet → Galactic Map Editor → Modifiers` 确有 `Effect 1` 至 `Effect 8`，类型都是 **4 Bytes**，地址符号为 `planetAPIData`，另外还有 `Modifiers Active` 字段。

旧表的八个效果位置为 +0xB8、+0xBC、+0xC0、+0xC4、+0xC8、+0xCC、+0xD0、+0xD4，数量字段标在 +0x138。这里只记录旧表声明，**不表示这些偏移对当前游戏有效，也没有验证该地址对象的完整结构或来源**。下拉项使用小整数效果 ID，例如 1209（Eagle Storm）、1208（Planetary Bombardment）、1230（Meridian Blackhole Locked）、1373–1375（三级 Exostorm）；这些也是历史映射，不能保证当前版本编号不变。

这层数据表达的是“当前某颗星球生效哪些编号的效果”，与本页的“某份本地配置引用哪些 64 位实体”不同。当前离线修改器**没有实现**按星球 ID／事件 ID 编辑该八槽结构；新页面不能替代旧内存功能。“文件序号 4”仅表示 DL 中的第 4 条记录，不是星球 ID 或事件 ID。

若要在只改本地文件的前提下复现，需要继续定位这份运行时八槽状态的填充／读取路径，证明存在可改写的本地输入或缓存并找到其编码；另一条技术路线是改变客户端消费该状态的逻辑，这超出现有 DL 配置编辑器的实现。只有旧表的内存字段或一个八槽外观，不能证明离线写入可以生效。本次没有修改客户端程序逻辑，也没有伪造八槽编辑项。

本页的每个实体列表可追加、替换、删除。“添加本地实体引用”的含义是把指定的 64 位实体哈希写进这个本地数组；不修改八槽中的 32 位效果 ID。输入完整实体名称、资源路径、`0x` 开头的 16 位十六进制哈希或十进制 uint64；已有项输入 `-` 删除。支持预设、重置和配置持久化，点击“写入游戏”生成文件。引用必须属于已加载的本地实体表或原列表，不能把 package 哈希、32 位 Modifier 编号或 entity delta 哈希当作环境实体。

列表编辑与预载数组共用 LDLD 内追加序列化器，但使用独立的 `modifier_entity` 引用域，包清单不会因此改变。数据保存在用户配置目录的 `preload_config.json` 的 `arrays` 中。重建数组时同步更新指针和数量，保持该块其余数据及其他块的相对引用；写回前再次核对类型库、记录序号、字段位置和原列表。通用“星球生成／银河表现”页中的这三处数组指向此编辑入口，避免两套编辑值互相覆盖。

## 已确认的星球环境挂载

`LevelGenerationPlanetData.gameplay_modifiers` 是动态 **uint64 实体引用数组**，不是 Modifier ID 或实体差异数组：

| 相对偏移 | 含义 |
| --- | --- |
| +0x1A8 | 序列化后的数组数据指针（相对于该 LDLD payload）；加载后可能被重定位 |
| +0x1B0 | uint32 元素数 |
| +0x1B4 | 数组描述符保留字 |
| 数组数据 +8 × i | 第 i 个 uint64 实体引用 |

字段名来自现有 2025 设置转储的逐记录值匹配；当前偏移和数组类型由 01.007.201 类型库确认。438 条记录合计 216 个引用，指向 8 个实体。这些实体都具有 `SpawnOnPlayersComponentData` 与 `EnvironmentalEffectTagComponentData`，其中 7 个还具有 `LoadoutPackageComponentData`，8 个均不属于实体差异存储。

| 环境效果 | 实体哈希 | 星球记录引用数 |
| --- | --- | ---: |
| 流星风暴 | 37EF28E51C6C1716 | 21 |
| 离子风暴 | BE5C2702BD514A76 | 45 |
| 地震 | 9080B0090BC6F3AB | 39 |
| 暴风雪 | D65B304D05CF9820 | 26 |
| 酸雨风暴 | 60CF8192A5FDA029 | 19 |
| 火山喷发 | 663FD31B0949A8E8 | 25 |
| 火龙卷 | 7BAFBDB8D21D7D2A | 20 |
| 沙尘暴 | 7D9517E3CF9FE980 | 21 |

这里控制生成配置引用哪些环境效果实体。银河地图显示的生效效果、星球事件选择、在线任务最终使用哪些配置，不等同于这个本地列表；本次只验证文件读写，没有验证游戏中的最终效果。跨环境增加实体还可能需要对应 package，使用现有预载功能配置其依赖。

## 银河事件的两组关联

`GalacticPresenceSettings` 的 +0x1F8 和 +0x2C0 均为动态 uint64 数组，描述符布局同上。两者是不同数组，不合并，也不把它们统一称为“添加修饰符”。

- A（+0x1F8）：在 gloom、hiveworld_infested_planet、illuminate_rift 及 ritual_storm 等记录中引用暴风雪、酸雨、沙尘暴、火龙卷、离子风暴、地震等常规环境实体；共找到 40 个与星球列表共用的引用。根据共现关系，**推测**可能用于排除／屏蔽常规效果；尚未确认原始参数名与运行时增减语义。
- B（+0x2C0）：ritual_storm_lvl1/2/3 中分别出现异界风暴 MK1/2/3，以及旋风／龙卷风；也存在其他事件实体引用。**推测**属于事件带来的额外实体列表，但是否直接生成、何时生成、是否只影响任务，需要游戏验证。

例如 `illuminate_ritual_storm_lvl3` 的 A 有 7 项；B 原始有 `D365C43981469A26`（异界风暴 MK3）与 `CBFCCAD8BDCED643`（龙卷风 MK2）。UI 保留 A/B 和偏移标签，避免把推测作为已确认功能。

## Modifier 定义和行动／任务效果定义

这是另外两个命名空间，不能混用：

1. `generated_modifier_settings.dl_bin`：15 条 `Modifier` 定义，根结构 24 字节。+0 是 uint32 编号，+4 是未确认语义的字节，+8 是动态 `ModifierGroup[]`。每组 32 字节，+0 是受影响实体的 uint64 数组，+16 是施加到这些实体上的 entity delta 数组。它定义“选中该编号后修改什么”，不是“某星球启用哪些编号”。原有“星球效果修饰”页仍编辑其差异参数。
2. `generated_entity_deltas.dl_bin`：14 个差异修改 `GameModeComponentData` 或 `HiveMindComponentData`，包括任务时间、增援、撤离、地图大小、巡逻、遭遇等。14 个差异的全部 component index、offset、size、原始数据字节均与 RawData 01.007.200 **完全一致**。原有“行动修饰符”页仍编辑这些效果值，作用于选用该差异的流程，不是某次行动专属的携带列表。

本次对 55 个本地 DL 文件逐字节搜索 15 个 Modifier uint32 编号及 14 个行动差异 uint64 哈希，并把命中位置反查到类型成员：15 个编号仅命中各自定义的 +0；14 个差异哈希仅命中实体差异存储的资源索引键。**在此扫描范围内没有找到每颗星球／每次行动／每次任务的启用编号列表。** 这不等于证明整个客户端所有资源、编码或运行时路径中都不存在该列表。

当前类型库的 `WarPlanetComponent`、`WarOperationItemComponent`、`WarMissionItemComponent` 都只有 4 字节 uint32 成员；旧版说明为忽略的 dummy 字段，不能据此伪造 modifier 1–12 开关。

本地网络配置确有 `rpc_modifier_system_recieve_modifier_from_host`、`rpc_modifier_system_initialise_sync`、`rpc_modifier_system_finalise_sync` 和行动同步等协议名称，说明运行时存在主机／同步路径；仅凭协议名无法证明具体参数含义、执行权限或本地文件可以改写服务器选择。UI 因此没有添加无依据的“行动／任务携带修饰符”控制。

## 验证

`tests/test_modifier_assignments.lua` 使用真实本地表经过原编辑器 GUI 与配置流程验证：438 + 137 个页面、空列表追加、已有项替换／删除、中文名和精确 uint64、持久化、预设、重置、两个事件数组互不影响、非法引用与重定向字段拒绝、两份 DL 序列化后加密并重新解密逐项核对、原文件哈希保持、简体／英文原生界面渲染。测试不写游戏目录。
