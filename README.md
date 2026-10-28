# SHODAN Stat Editor Offline · Thodmcniujiao fork

**《绝地潜兵 2》离线数值编辑器** · Offline stat editor for Helldivers 2

Windows x64 · 无需 mod loader · GPL-3.0 · English / 简体中文 / 繁體中文 / Русский

**简体中文** | [English](#en)

> **快速开始：** 下载便携包 → 解压 → 关闭游戏 → 运行 `SHODAN Stat Editor Offline.exe` → 修改数值 → 点“写入游戏” → 启动游戏。
>
> **Quick start:** Download the portable package → unzip → close the game → run `SHODAN Stat Editor Offline.exe` → edit → **Install into the game** → play.

> 本仓库是 [SHODAN-HORAI/SHODAN-Stat-Editor](https://github.com/SHODAN-HORAI/SHODAN-Stat-Editor) v4.1.0 的 fork。上游的武器、战备、敌人、护甲等编辑能力保留；本 fork 重排了界面，并加入人物、存档、星球、实体组件、AI、刷怪、预载等本地数据工具。
>
> A fork of [SHODAN-HORAI/SHODAN-Stat-Editor](https://github.com/SHODAN-HORAI/SHODAN-Stat-Editor) v4.1.0. The upstream weapon, stratagem, enemy and armor editing is kept; this fork reorganizes the interface and adds local-data tools for the helldiver, saves, planets, entity components, AI, spawning and preloading.

<a id="zh"></a>
## 中文

### 这是什么

**SHODAN Stat Editor Offline**（SSEO）是一个 Windows 便携程序，用来修改《绝地潜兵 2》**本地数据文件**里的数值：武器、投掷物、战备、载具、强化资源、配件、护甲被动、敌人、星球、实体组件和部分存档字段。改完点 **写入游戏**，再启动游戏即可。它不需要 mod loader，编辑时游戏可以关闭。

本仓库是 Thodmcniujiao 的 fork，基于上游 **v4.1.0**。与上游相比，主要变化不是“多改了几个数”，而是导航和数据视图：

- **10 个页面，页面下再分子页。** 原来的单排标签页和独立的敌人编辑器被页面取代；敌人设置是其中一页。
- **从“先选实体，再看组件”改为“先选组件/数据类型，再找实体”。** 实体组件、AI 设置、刷怪编辑器、游戏数据 ID 页都是这个思路。
- **新增本地存档与文件层工具。** 当前装备栏直接读写 `testament_new.sav`；星球任务、实体拆毁、预载设置处理本地配置文件、实体差异和资源包。
- **命名预设库。** 原来的每武器 1–5 快捷槽和 50 个整包预设，统一为按类别管理的命名预设，旧预设首次启动自动导入。
- **上游更新已关闭。** 本 fork 不会被上游二进制包静默替换；窗口标题和 `app\build.txt` 里的 `build <时间>` 标明本地构建。

界面语言：**English、简体中文、繁體中文、Русский**。版本号沿用上游 **4.1.0**，但内容不等同于上游 4.1.0；以打包时间为准。

**分支：** `dev` 只放源码、构建脚本、测试和说明；便携包发布在 Releases，发布标签对应源码提交。

### 与上游 v4.1.0 的差异

| 方面 | 上游 v4.1.0 | 本 fork |
|---|---|---|
| 导航 | 一排 10 个标签页；敌人编辑器是独立模式 | 顶部 **10 个页面**，页面下是子页/分类；敌人是“敌人设置”页 |
| 武器 / 投掷物 / 战备 / 机甲 / 强化 / 配件 / 护甲 | 有 | 保留，入口按页面重排 |
| 绝地潜兵 | 在护甲页 | 独立“人物数据”页：完整 Avatar 组件 + 快速编辑 |
| 玩家存档 | 无 | 军械库 › 当前装备栏编辑：本地 `.sav` 读写、备份与恢复 |
| 星球 / 行动 / 任务 | 无 | 星球设置、本地环境实体、行动修饰符、任务组件 |
| 实体组件 | 从实体找组件 | 25 类武器组件，以及生命、护盾、地雷、投掷、阵营、挂载、背包、炮塔、地狱舱、接触伤害、飞鹰等 |
| 游戏数据 | 射弹 / 爆炸 / 状态记录 | 伤害、射弹、爆炸、电弧、激光、状态效果、战备；ID 双击跳转 |
| 轨道 / 飞鹰 | 部分参数 | 完整 StratagemType + 轰炸组件 + OrbitalAbility（140 字段、56 个二维控制点）+ EagleComponentData（82 字段）+ EagleSpawnerComponentData（6 字段） |
| AI / 刷怪 | 敌人页内的行为、生成行 | AI 设置（5 个组件）+ 刷怪编辑器（HiveMind 277 字段） |
| 预载 / 资源包 | 无 | 预载设置：包清单合并、环境包数组、清单增删改 |
| 预设 | 每武器 5 个 + 最多 50 个整包 | 命名预设库（4 类）；旧预设自动导入；快捷槽移除 |
| 更新 | 启动时检查 GitHub 发布 | 已关闭；设置页保留选项，但不检查、不替换 |
| 打包 | `package.py` + CI | `build_release.bat`：打包、校验哈希、更新快捷方式、检查链路；CI 保留 |
| “额外”页 | 有 | 移除；溺水、地狱舱等字段并入实体组件 |
| 界面语言 | 英 / 简 / 繁 / 俄 | 同；上游后续版本新增的语言未合并 |

**注意：**

- 版本号 **4.1.0** 是沿用上游的基线号，不代表与上游 4.1.0 完全相同。请用窗口标题的 `build <时间>` 区分本地构建。
- 上游 4.1.0 之后的改动**没有系统合并**；合并上游时需要重新应用本地扩展。
- 本 fork 的自动更新被 `offline/host.lua` 里的 `LOCAL_ENTITY_EXTENSION` 关闭。设置页的“更新/更新渠道”仍显示，但不会联网检查或安装上游版本。

### 下载与安装

1. 从 [Releases](../../releases) 下载 `SHODAN-Stat-Editor-Offline-*.zip`，解压到任意可写目录。exe、DLL 和 `app` 文件夹必须放在一起。
2. **关闭《绝地潜兵 2》**，运行 `SHODAN Stat Editor Offline.exe`。
   - 程序通过 Steam 查找游戏。
   - 找不到时，把游戏目录写进 `%LOCALAPPDATA%\SHODAN\StatEditor\game folder.txt`，再启动。
3. 在界面里改数值，点底部的 **写入游戏**，然后启动游戏。
4. 想回到原版，点 **恢复游戏原始文件**。你的修改仍然保存在配置目录，重新点“写入游戏”即可再次应用。

**更新方式：** 本 fork 不自动更新。下载新的便携包，解压覆盖程序文件即可；`%LOCALAPPDATA%\SHODAN\StatEditor` 里的配置、预设、日志和游戏原件不会被覆盖。

**第一次运行**可能出现 Windows SmartScreen 或杀毒软件提示，因为 exe 没有代码签名。请自行确认来源。

**便携包内容：**

```text
SHODAN Stat Editor Offline/
├─ SHODAN Stat Editor Offline.exe   启动器
├─ lua51.dll                        LuaJIT 运行时
├─ libsodium.dll                    libsodium
├─ shodan_hash.dll                  哈希、下载与安装辅助
├─ app/
│  ├─ stat_editor.lua               面板（与 src 逐字节一致）
│  ├─ *.lua                         运行时模块（60 个）
│  ├─ entity_names.tsv              实体名称索引
│  ├─ entity_catalog.default.json   实体分类模板
│  └─ build.txt                     版本、提交、渠道、打包时间
├─ *.md                             随包的字段说明
├─ README.txt                       发布包快速说明
└─ THIRD-PARTY-NOTICES.txt          LuaJIT / libsodium 许可
```

### 界面与功能地图

窗口顶部是 **页面**；页面标题下方是 **子页**。一个子页有多个分类时，分类按钮显示在标题右侧。底部固定四个操作：**写入游戏 / 恢复游戏原始文件 / 预设 / 设置**；在“当前装备栏编辑”页，前两个变为 **写入存档 / 恢复存档备份**。

| # | 页面 | 子页 | 状态 |
|---:|---|---|---|
| 1 | 游戏功能 | 玩家主体 · 玩家移动 · 玩家武器 · 任务设置 · 兴趣点设置 · 终端设置 · 战备设置 | ○ 占位 |
| 2 | 人物数据 | 人物数据 · 快速编辑 | ● 可用 |
| 3 | 材料货币 | 抓包发蓝币 · 古法刷资源 | ○ 占位 |
| 4 | 敌人设置 | 敌人编辑 · AI 设置 · 刷怪编辑器 · 敌人替换器 | ● 3 个可用 / ○ 1 个占位 |
| 5 | 军械库 | 解锁 · 武器编辑 · 武器配件自定义 · 护甲编辑 · 强化资源 · 装备替换 · 当前装备栏编辑 | ● 5 个可用 / ○ 2 个占位 |
| 6 | 星球任务 | 星球设置 · 本地环境实体 · 战役编辑 · 行动编辑 · 任务编辑 | ● 3 个可用 / ◐ 1 个部分 / ○ 1 个占位 |
| 7 | 实体组件 | 武器组件 · 武器类型 · 武器配件 · 炮塔与制导 · 背包 · 挂载 · 阵营 · 地雷与投掷 · 淹没 · 生命与拆毁 · 护盾 · 地狱舱 · 接触伤害 · 飞鹰 | ● 全部可用 |
| 8 | 轨道飞鹰 | 轨道编辑 · 飞鹰编辑 · 轨道武器编辑 | ● 全部可用 |
| 9 | 游戏数据 | 伤害 id · 射弹 id · 爆炸 id · 电弧 id · 激光 id · 状态效果 id · 战备 id | ● 全部可用 |
| 10 | 杂项与设置 | 身份设置 · 已解析参数 · 修改器设置 · 预载设置 · 寻找器 | ● 2 个可用 / ◐ 1 个部分 / ○ 2 个占位 |

图例：● 可用　◐ 部分可用（有占位标签）　○ 占位（只列出计划，不修改游戏）

**想改什么，去哪里：**

| 想改的内容 | 入口 |
|---|---|
| 武器、投掷物的数值 | 军械库 › 武器编辑 |
| 武器配件、护甲被动、强化资源 | 军械库 › 武器配件自定义 / 护甲编辑 / 强化资源 |
| 战备冷却、次数、指令、飞鹰、轨道、哨戒炮 | 游戏数据 › 战备 id › 战略配备 |
| 机甲、FRV、坦克 | 游戏数据 › 战备 id › 载具 |
| 轨道武器、轰炸参数 | 轨道飞鹰 |
| 敌人、AI、刷怪 | 敌人设置 |
| 星球生成、环境、天气、行动、任务 | 星球任务 |
| 某个实体的生命、护盾、武器组件等 | 实体组件 |
| 伤害/射弹/爆炸/电弧/激光/状态/战备记录本身 | 游戏数据 |
| 本地存档里的配装 | 军械库 › 当前装备栏编辑 |
| 预载包、包清单、环境包数组 | 杂项与设置 › 预载设置 |
| 角色字幕名、字体样式 | 杂项与设置 › 已解析参数 |

### 逐页说明

#### 1. 游戏功能（占位）

7 个子页按布局文档保留：玩家主体、玩家移动、玩家武器、任务设置、兴趣点设置、终端设置、战备设置。它们是**占位**，只列出计划中的功能（无敌、无限弹药、任务完成、全图目标等），不会写入游戏。

真正的任务和生成编辑在 **星球任务 › 任务编辑** 和 **敌人设置 › 刷怪编辑器**。

#### 2. 人物数据

- **人物数据：** 直接编辑绝地潜兵实体（`content/fac_helldivers/cha_avatar/avatar_helldiver`）的 `AvatarComponentData`（852 字节）。按布局文档分成：速度、攀爬、耐力、转向速度、侦查/潜行、投掷/沾污、自我治疗、滑铲、布娃娃/杂项、人物切枪状态等。每行显示组件偏移和成员名。
- **快速编辑：** 只放常用项：生命组件（本体生命/再生、各部位生命）和阵营组件（阵营 1–3）。它与 **实体组件 › 生命与拆毁 / 阵营** 是同一组字段，改一处，另一处同步。
- 这些是**本机数据**，不改账号解锁或服务器档案。联机前请恢复游戏原始文件。

详见 [PLAYER_DATA.md](offline/PLAYER_DATA.md)。

#### 3. 材料货币（占位）

“抓包发蓝币”“古法刷资源”两个子页为占位。它们列出计划中的功能（开启、修改空投、替换战备、获取样本、超级结算），目前不会修改游戏。

#### 4. 敌人设置

- **敌人编辑：** 4 个分类：
  - **敌人**：虫族、机器人、光能者合并为一个列表，左侧用阵营选择器筛选（全部 / 虫族 / 机器人 / 光能者）；每个阵营最前面仍有“所有虫族 / 所有机器人 / 所有光能者”的倍率页。
  - **SEAF**：每种 SEAF 士兵，以及它们携带的武器。
  - **敌人生成**：按阵营调整增援、巡逻、前哨、生成点等倍率。
  - **敌人数据：** 一页“所有敌人”的全局倍率：生命、护甲、硬直抗性、眩晕/毒气抗性、火焰伤害、伤害、移动速度、视野范围。它同时作用于三族全部敌人（不含 SEAF），与各阵营倍率**相乘**；手动改过的敌人保持原值。
- **AI 设置：** 5 个标签，编辑敌人 AI、角色 AI、视觉、听觉、危险感知的全部字段。字段与敌人页、倍率页共用。
- **刷怪编辑器：** 敌人调度（HiveMind，1084 字节、277 字段、19 条记录）和 SEAF 目标（96 字节、24 字段、1 条记录）。敌人生成页的倍率行与这里共用字段。
- **敌人替换器：** 占位。

进入“敌人设置”页时界面变红，离开后恢复。原左上角的 **SHODAN Enemy Editor** 切换按钮已被页面取代；一次“写入游戏”同时应用两个编辑器的内容。详见 [ENEMY_DATA.md](offline/ENEMY_DATA.md) 和 [SPAWN_EDITOR.md](offline/SPAWN_EDITOR.md)。

#### 5. 军械库

- **武器编辑：** 主武器、副武器、支援武器、投掷物四个分类。上游的武器参数都在：伤害、耐久伤害、穿甲、拆毁、硬直、击退、射速、弹道、爆炸、电弧、燃烧/毒气、弹匣/备弹/装填、后坐/散布/晃动/人体工学、热量、槽位、射弹替换。
- **武器配件自定义：** 瞄具、下挂、枪口（含武器自带的枪口制退器）、霰弹枪喉缩、弹药类型。
- **护甲编辑：** 全部护甲被动。可给被动叠加其他被动（**同时包含** / **自身效果** 开关），可把任意护甲设为轻/中/重。
- **强化资源：** 实验注射、火焰/眩晕地狱舱、隐蔽插入、死亡冲刺、武装补给、额外 EAT 等。
- **当前装备栏编辑：** 直接读写本地 `testament_new.sav`。四个部分：
  - **存档配装：** 头盔、护甲、披风、主武器、副武器、手雷，以及胜利姿势 ID、玩家卡片背景 ID。
  - **装备 ID 目录：** 从本机 `LoadoutEntryComponentData` 和 `HelldiverCustomizationKit` 读取物品定义；可输入十进制、`0x` 十六进制或唯一匹配的名称。目录是物品定义，不代表账号已解锁。
  - **存档与备份：** 自动发现的 Steam 存档、手动路径、备份恢复。
  - **未命名存档字段：** 外观记录附近的 8 个 u32 原始字段；没有把它们猜测成称号、体型或语音。
  - 写入前自动备份，校验 CRC32/LZ4，检测磁盘存档是否被其他程序更新；只支持已确认的容器版本 `0x107`。写入前必须关闭游戏；Steam Cloud 仍可能覆盖本地文件。详见 [PLAYER_SAVE.md](offline/PLAYER_SAVE.md)。
- **解锁、装备替换：** 占位。

#### 6. 星球任务

- **星球设置：** 8 个分类：星球生成（438 条记录）、星球效果修饰（15 条 Modifier）、环境设置（17 条）、天气设置（184 条）、星球类型、星系表现（137 条）、区域领土、环境组件。字段名按“按数值核对 / 各记录同值 / 按顺序推断 / 旧版推断 / 未知”分级，未知字段显示偏移；页面提示会说明来源。**银河地图上的归属、生命值、恢复、坐标、锁定和生效效果由服务器下发，不在这里改。**
- **本地环境实体：** 两套 64 位实体引用数组：星球环境实体（438 条星球记录的 `gameplay_modifiers`）和事件实体列表（实验，GalacticPresence 的 A/B 两组）。可追加、替换、删除。它们**不是**旧内存编辑器的 8 个 32 位效果 ID；A/B 的运行时语义尚未确认。
- **行动编辑：** 14 条实体差异（修改 GameMode 或 HiveMind），包括增援时间、立即撤离、地图大小、任务时间限制、巡逻间隔、遭遇上限、野外遭遇等。
- **任务编辑：** 任务规则与增援（GameModeComponent，23 字段、19 个实体）、任务模式开关（GameModeMissionComponent，6 字段、17 个实体），以及 **任务目标编辑**（占位）。
- **战役编辑：** 占位。

详见 [PLANET_SETTINGS.md](offline/PLANET_SETTINGS.md) 和 [MODIFIER_ATTACHMENTS.md](offline/MODIFIER_ATTACHMENTS.md)。

#### 7. 实体组件

| 子页 | 内容 |
|---|---|
| 武器组件 / 武器类型 / 武器配件 | 25 个 `Weapon*` 组件全部解析，共 1,631 个叶子成员。WeaponData 329 字段 / 373 实体；装填、弹匣、蓄力、弹药、热量、预热、协助装填；射弹/喷射/电弧/光束/近战/技能/制导/物理/架设武器；武器自定义、配件、手电、激光、屏幕、连接弹药、连接器、持握者 |
| 炮塔与制导 | 视觉传感（11 字段 / 315 实体）+ 炮塔（19 字段 / 74 实体） |
| 背包 | 物品栏（20 字段 / 86 实体）：默认主/副/支援/投掷/背包/近战、治疗针、可丢弃装备 |
| 挂载 | 挂载（30 字段 / 164 实体）：最多 5 个挂载位；换错类型可能在生成时崩溃 |
| 阵营 | 阵营（32 字段 / 533 实体）：阵营位值、瞄准节点、生成影响、忽略单位 |
| 地雷与投掷 | 地雷（11 字段 / 13 实体）、地雷生成器（7 字段 / 8 实体）、投掷物（78 字段 / 46 实体）、投掷器（186 字段 / 5 实体） |
| 淹没 | `DrownableComponentData`（64 字节）的全部字段；绝地潜兵与“额外”页旧字段共用 |
| 生命与拆毁 | 生命（22,096 字节记录、全身与各部位）+ 实体拆毁（0–4,294,967,295 阈值、独立模板、Unit 别名隔离） |
| 护盾 | `ShieldComponentData`（344 字节、83 项）：容量、充能、形状、颜色、充能事件、音效、动画 |
| 地狱舱 | 下落（26 字段 / 8 实体）、载荷（3 / 117）、挂架（124 / 72）、舰上（1 / 2） |
| 接触伤害 | `OverlapDamageComponentData`（385 字段 / 64 实体）：每个实体 8 个伤害区域 |

- **完整实体目录：** 约 3,400 个 ECS 实体和场景 Unit 合并成一份目录，生命、拆毁、淹没、护盾等页面共用。默认显示“没有本组件”的实体（灰色），可关闭。
- **分类与命名：** 通过 `entity_catalog.json` 自定义分类、规则和实体名称；`entity_catalog.index.json` 是供外部工具查询的完整索引。JSON 只影响显示，不改游戏资源或哈希。详见 [ENTITY_CATALOG_API.md](offline/ENTITY_CATALOG_API.md)。
- **字段来源：** 布局在启动时对照已安装游戏的类型库校验；字段名来自游戏类型库、RawData dump 和 2024 年结构，推断或未知的字段会在提示里注明。
- 原武器页、敌人页、炮台页与组件页共用同一份字段；改一处，两边同步。详见 [ENTITY_COMPONENTS.md](offline/ENTITY_COMPONENTS.md) 和 [ENTITY_DEMOLITION.md](offline/ENTITY_DEMOLITION.md)。

#### 8. 轨道飞鹰

- **轨道编辑：** StratagemType 类型（400 字节、67 个类型库成员；全表当前 153 条记录）+ 轰炸组件（192 字节、28 个字段）：每轮炮弹数、间隔、齐射轮数、散布、行进轰炸速度、8 个射弹槽等。
- **飞鹰编辑：** EagleComponentData（重新武装、投放、运行长度等）+ StratagemType 参数组。
- **轨道武器编辑：** OrbitalAbilityComponentData（568 字节、140 个字段、2 条记录：轨道激光炮和轨道炮攻击），包括持续时间、追踪、伤害区域、射弹生成、特效、阵营过滤、移动轨迹和 56 个二维控制点（112 个坐标）。

三个入口共用同一套 StratagemType 字段；伤害、射弹、爆炸等引用可以双击跳转。详见 [STRATAGEM_COMPONENTS.md](offline/STRATAGEM_COMPONENTS.md)、[BOMBARDMENT_COMPONENTS.md](offline/BOMBARDMENT_COMPONENTS.md) 和 [ORBITAL_WEAPON_COMPONENTS.md](offline/ORBITAL_WEAPON_COMPONENTS.md)。

#### 9. 游戏数据

| 子页 | 记录 | 规模 |
|---|---|---|
| 伤害 id | `DamageInfo` | 76 字节 / 19 个参数 |
| 射弹 id | `ProjectileInfo` | 272 字节 / 73 项（355 条记录） |
| 爆炸 id | `ExplosionInfo` | 152 字节 / 40 个成员（424 条记录，44 个固定项 + 震屏数组） |
| 电弧 id | `ArcInfo` | 104 字节 / 21 个参数（16 条记录） |
| 激光 id | `BeamInfo` | 112 字节 / 25 个成员（30 条记录） |
| 状态效果 id | `StatusEffectInfo` | 160 字节，按标识、强度/持续时间、伤害引用、特效、音效、标志、倍率等分组 |
| 战备 id | `StratagemInfo` | 400 字节 / 67 个成员（153 条记录）；同一子页还有 **战略配备** 和 **载具** 两个分类 |

- 引用其他记录的数值旁会标 `projectile_id`、`explosion_id`、`damage_id`、`status_effect_id`、`arc_id`、`beam_id`、`stratagem_id` 等类型。单击可编辑，**双击跳转**到对应记录；0 表示无引用，不存在的 ID 会被拒绝。
- 跳转可以连续进行：**射弹 → 命中爆炸 → 伤害 → 状态效果**。
- 战备 id 的“战略配备”分类就是原来的 Stratagems 页（冷却、次数、指令、飞鹰、轨道、哨戒炮、背包等），“载具”分类就是原来的 Mechas 页（机甲、FRV、坦克及其武器）。

详见 [REFERENCE_NAVIGATION.md](offline/REFERENCE_NAVIGATION.md)、[DAMAGE_COMPONENTS.md](offline/DAMAGE_COMPONENTS.md)、[PROJECTILE_COMPONENTS.md](offline/PROJECTILE_COMPONENTS.md)、[EXPLOSION_COMPONENTS.md](offline/EXPLOSION_COMPONENTS.md)、[ARC_COMPONENTS.md](offline/ARC_COMPONENTS.md)、[BEAM_COMPONENTS.md](offline/BEAM_COMPONENTS.md)。

#### 10. 杂项与设置

- **已解析参数：** 3 个分类：
  - **角色名称：** `CharacterNameComponentData`（91 条实体、4 个字段）：种族、随机名字模板、角色字幕名称 ID、是否使用持久种子。
  - **字体样式：** `FontSettings`（6 组语言字体、180 个样式、720 个可编辑字段）：字号、阴影范围等；这是本机共用样式。
  - **网络接口参考：** 只读列出 `rpc_ingame_chat_message`、`rpc_set_player_info`、`rpc_sync_player_info` 等操作名、哈希和参数数量，不提供写入。
  - 详见 [NAMED_PARAMETERS.md](offline/NAMED_PARAMETERS.md)。
- **预载设置：** 7 个分类：额外预载、全局/任务、装备包、敌人包、环境/星球、包目录、热加入参考。支持按名称/哈希选包、合并包清单、向环境包数组追加、增删改包内资源。
  - 需要 **Filediver CLI** 读取/导出包；程序会自动查找，也可用 `SHODAN_FILEDIVER`、`tools\filediver.exe` 或配置目录的 `filediver path.txt`。
  - 写游戏时生成独立的 `.patch_N`，原 NXA 容器保持原样；恢复时只移除本编辑器拥有的补丁。
  - 文件层已验证；**尚未在游戏内确认**新增数组是否被运行时消费、全局/任务包合并的实际驻留效果。详见 [PRELOAD_COMPONENTS.md](offline/PRELOAD_COMPONENTS.md)。
- **修改器设置：** 字号、渲染分辨率等显示选项，实时保存；其余旧设置项以占位说明呈现。
- **身份设置、寻找器：** 占位。

### 上游原有编辑范围（保留）

| 类别 | 可以改什么（摘要） |
|---|---|
| 武器 | 伤害、耐久伤害、穿甲、拆毁、硬直、击退、射速、弹道、爆炸/电弧、燃烧/毒气、弹匣/备弹/装填、后坐/散布/晃动/人体工学、热量、槽位、射弹替换 |
| 投掷物 | 初始/最大/补给数量、投掷距离、引信、爆炸、破片、电弧、燃烧/毒气 |
| 战备 | 冷却、使用次数、呼叫指令、飞鹰、轨道轰炸/激光、护卫犬、哨戒炮/固定武器、雷区、跳包/悬浮包/传送包、背包充能 |
| 机甲/载具 | 冷却、生命/护甲、各部位、武器；武器按武器页逐项编辑 |
| 强化资源 | 实验注射、火焰/眩晕地狱舱、隐蔽插入、死亡冲刺、武装补给、额外 EAT |
| 配件 | 瞄具、下挂、枪口、喉缩、弹药类型的倍率与参数 |
| 护甲/绝地潜兵 | 全部护甲被动、被动叠加、护甲重量；绝地潜兵现在在人物数据页 |
| 敌人 | 生命/护甲/部位、行为/感知、攻击、敌人武器、护盾/干扰、SEAF、阵营倍率、生成 |

上游 README 的逐项表格可作为这些字段的参考；本 fork 只改变了入口和分组，没有删掉这些字段。

### 写入、恢复与兼容

- **写入游戏**只在游戏关闭时执行。程序会找出有改动的文件，保留文件原有的校验和，必要时生成 `.patch_N` 资源包；写入前把原件保存到 `%LOCALAPPDATA%\SHODAN\StatEditor\originals`，失败时回滚。
- **恢复游戏原始文件**把编辑器改过的文件恢复为安装前的状态，并移除本编辑器拥有的资源补丁；其他 mod 的文件会保留。
- **与其他 mod 共存：** 先装其他 mod，再点本编辑器的“写入游戏”，本编辑器会保留它们的改动并在上面叠加；同一数值冲突时以本编辑器为准。这个流程没有经过穷尽测试。
- **游戏更新 / Steam 校验文件：** 游戏原文件会回来。先点“恢复游戏原始文件”，再点“写入游戏”，否则可能无法连接 EAC。
- **当前装备栏**的“写入存档”是独立操作，只改所选 `.sav`，不涉及游戏数据文件。
- **预载设置、实体拆毁**用到资源包/Unit 克隆时依赖 Filediver；没有 Filediver 时相应安装会失败并提示，其他页面不受影响。
- **联机：** 改动只在本机生效；联机前建议恢复原文件。使用修改后的游戏文件带来的风险由使用者承担。

### 预设

底部 **预设** 按钮进入独立工作区：顶部导航、分类、实体列表和参数表都会隐藏，左侧选预设，右侧载入/覆盖/重命名/删除。**Esc** 或“返回编辑”退出，并恢复之前的页面、选中项、滚动和搜索。

预设分为 4 类：

| 类别 | 内容 |
|---|---|
| 游戏参数 | 一般资源参数、护甲被动叠加/开关；载入只替换这一类，保留敌人参数 |
| 敌人参数 | 敌人和生成参数；载入不清除其他游戏参数 |
| 存档配装 | 当前存档中的可编辑配装字段；载入只暂存，回配装页点“写入存档”才写文件 |
| 预载方案 | 包清单、额外包选择、加载目标、数组修改及预载页的资源参数 |

- 所有命名预设保存在 `%LOCALAPPDATA%\SHODAN\StatEditor\preset_library.json`，使用稳定 ID，不再限制“每把武器 5 个”。
- 首次使用会自动导入 `preset_01.txt`–`preset_50.txt`、`enemy_preset_01.txt`–`enemy_preset_50.txt`、`weapon_presets.txt`、`player_save_presets.json` 和 `preload_config.json` 里的旧预设；原文件保留，导入来源有标记，重启不会重复导入。
- 新库使用结构校验的 JSON：先写临时文件、读回验证，再原子替换；如果另一个编辑器改过库文件，会拒绝覆盖。
- 键盘：**Enter** 载入、**Insert** 新建、**Shift+Insert** 覆盖、**F2** 重命名、**Del** 删除、**Esc** 返回。
- 页面内原来的 1–5 快捷槽、保存/读取/清除按钮和 `Ctrl+1–5` 快捷键**已移除**。

详见 [PRESETS.md](offline/PRESETS.md)。

### 设置、搜索与快捷键

**设置**（底部右侧）也是一个独立工作区：

| 设置 | 作用 |
|---|---|
| 语言 | English / 简体中文 / 繁體中文 / Русский |
| 应用我的修改 | 关闭后，写入游戏的是游戏原值；你的改动仍保存，重新开启后再应用 |
| 字号 / 渲染分辨率 | 面板文字大小与绘制分辨率，可拖窗口边缘或最大化 |
| 同类载具数量 | 默认关；开启后一套配装可带多台机甲、FRV 或坦克 |
| 改进战略配备弹跳 | 默认关；战备球更容易粘在表面上 |
| 穿透植被 | 默认关；火箭、发射器弹药和战备弹药穿过树冠/灌木 |
| 第三人称狙击步枪准星 | 默认关；狙击枪第三人称瞄准时显示准星 |
| 显示的标签页 | 隐藏不用的内容；搜索也会跳过 |
| 重置全部数值 | 把当前全部改动恢复为游戏原值（二次确认） |
| 更新 / 更新渠道 | 本 fork 不检查更新；选项保留但不会替换本地版本 |
| GitHub / 日志与预设 | 打开项目链接或 `%LOCALAPPDATA%\SHODAN\StatEditor` |

设置会立即保存到 `config.txt`。

**搜索：** 点列表下方的搜索框（或 `Ctrl+F`）输入关键词。列表会显示所有页面中名称包含全部关键词的武器/战备；在实体组件页搜索实体名称或哈希；在游戏数据页搜索记录。**Enter** 保留结果，**Esc** 或 **X** 清除。

**快捷键：**

| 键 | 作用 |
|---|---|
| ↑ / ↓ | 选择上一项 / 下一项 |
| ← / → | 调整数值（按住 Shift 步进更大） |
| Enter，或点击数值 | 输入数值（Enter 确认，Esc 取消） |
| PgUp / PgDn | 上一个 / 下一个武器或记录 |
| Ctrl+F | 搜索 |
| Del | 把当前项恢复为游戏原值 |
| Esc | 取消输入 / 关闭工作区 / 返回编辑 |

### 文件与数据位置

所有用户数据在 `%LOCALAPPDATA%\SHODAN\StatEditor`：

| 路径 | 内容 |
|---|---|
| `config.txt` | 设置、普通修改、隐藏标签页等 |
| `preset_library.json` | 命名预设库 |
| `entity_demolition.txt` | 实体拆毁覆盖 |
| `entity_assets_installed.txt` | 资源补丁所有权记录 |
| `preload_config.json` | 预载包清单、数组和方案 |
| `entity_catalog.json` / `entity_catalog.index.json` | 实体分类/命名配置与完整索引 |
| `originals\` | 游戏原始文件备份 |
| `Logs\SHODANStatEditor.log` / `SHODANStatEditorHost.log` | 面板日志 / 宿主日志 |
| `game folder.txt` | 手动指定的游戏目录 |
| `filediver path.txt` | Filediver CLI 路径 |
| `demolition-migration-backups\` | 旧拆毁配置迁移备份 |

这些文件按需创建；删除配置目录会丢失预设和修改记录（游戏原件仍可由“恢复游戏原始文件”放回）。

### 构建、打包与测试

**依赖：**

- Windows 10/11 x64，Visual Studio 2022 Build Tools（C++）。
- [LuaJIT](https://luajit.org) 2.1 源码。
- [libsodium](https://libsodium.org) 1.0.22 x64 DLL。
- Python 3（打包与测试脚本）。

**步骤：**

1. 用 LuaJIT 的 `msvcbuild.bat` 构建 `lua51.dll`。
2. 设置 `LJ` 为 LuaJIT 的 `src` 目录，运行 `offline\launcher\build.bat`，生成 `SHODAN Stat Editor Offline.exe` 和 `shodan_hash.dll`。
3. 把 `lua51.dll` 和 `libsodium.dll` 放进 `offline\runtime\`。
4. 运行项目根目录的 `build_release.bat`：
   - 打包到 `offline\release\<yyyyMMdd-HHmmss>\SHODAN Stat Editor Offline\`；
   - 校验 `app\stat_editor.lua` 与 `src\stat_editor_offline.lua` 逐字节一致；
   - 写入 `app\build.txt`（版本、提交、渠道、打包时间）；
   - 更新项目根目录的 `SHODAN Stat Editor Offline.lnk`；
   - 检查正在运行的实例和桌面/开始菜单快捷方式是否指向旧代码。
   - 加 `-NoShortcut` 只打包，不改快捷方式。
5. 需要 zip 时运行 `python offline\package.py`；CI 也用它（`SSEO_CHANNEL=dev`、`SSEO_COMMIT=<sha>`）。

**测试：**

```bat
python tests\run_lua.py tests\check_syntax.lua
python tests\run_lua.py tests\test_preset_library.lua --isolated-profile --work .test-work\check
```

部分测试需要本机游戏数据或测试夹具，按脚本参数传入 `--fixtures`、`--game` 或 `--work`。测试使用隔离配置目录，不会写入真实游戏或存档。

**CI：** `.github/workflows/dev-build.yml` 会在推送到 `main` 时构建 Development build 预发布；本 fork 关闭了客户端自动更新，CI 产物不会自动替换本地版本。

**Filediver：** 预载设置和实体拆毁的 Unit 克隆需要 [Filediver](https://github.com/xypwn/filediver) CLI。程序会自动查找 `Downloads\Compressed\filediver-cli\filediver.exe`，也支持 `SHODAN_FILEDIVER`、`tools\filediver.exe` 或 `%LOCALAPPDATA%\SHODAN\StatEditor\filediver path.txt`。

### 目录结构

```text
.
├─ src/
│  ├─ stat_editor_offline.lua     离线面板（打包为 app/stat_editor.lua）
│  └─ stat_editor.lua             上游 v2.5.0 游戏内面板源码，不参与离线版
├─ offline/
│  ├─ host.lua                    桌面宿主：窗口、页面栏、写入/恢复
│  ├─ engine_shim.lua             Win32/GDI 窗口与输入
│  ├─ gamedata.lua                游戏数据解密/加密与校验
│  ├─ install.lua                 安装、恢复、原件与回滚
│  ├─ update.lua                  上游更新器（本 fork 由 host 关闭）
│  ├─ launcher/                   启动器 exe 与 shodan_hash.dll 的 C 源码
│  ├─ runtime/                    lua51.dll、libsodium.dll
│  ├─ *.lua                       人物、敌人、星球、组件、预载、预设等模块
│  └─ *.md                        字段级说明（见下方文档索引）
├─ tools/
│  ├─ build_release.ps1           本地打包与链路检查
│  ├─ component_gen/              组件字段名生成器
│  └─ planet_gen/                 星球设置字段名生成器
├─ tests/                         LuaJIT 测试
├─ images/                        旧版截图（上游界面，尚未更新）
├─ .github/workflows/             CI
├─ build_release.bat              打包入口
└─ LICENSE                        GPL-3.0
```

`src\stat_editor.lua` 是上游 v2.5.0 的**游戏内**面板源码，需要 Bingus Shared Loader，已不能在当前游戏版本使用；离线版只使用 `src\stat_editor_offline.lua`。

### 已知限制

- **占位页不会改游戏。** “游戏功能”“材料货币”“身份设置”“寻找器”等子页只列出计划；以页面上的灰字和说明为准。
- **银河地图的服务端数据不可改。** 星球归属、生命值、恢复、坐标、锁定和当前生效效果不在本地文件里。
- **部分新功能只做到文件层验证。** 星球环境实体数组、预载包合并/数组、存档配装、实体拆毁的私有模板和 Unit 别名，尚未全部在游戏内确认运行时效果；详见各说明文档的“验证范围”。
- **需要 Filediver 的功能。** 预载和实体拆毁在需要读取/克隆资源包时依赖 Filediver CLI；缺少时会失败并提示。
- **共享记录。** 多个实体/武器引用同一条生命、伤害、爆炸或组件记录时，改一处会一起生效；页面通常会提示共用数量。
- **游戏更新可能改变布局。** 字段偏移和类型在启动时对照类型库校验；布局不符时页面会提示并保留原解析，未知字段会标注“未知”。不要在未核对时批量写入。
- **实体替换有风险。** 把挂载/背包/生成点换成不兼容的实体，可能在生成时崩溃；地雷面板数、每面板地雷数只能调低。
- **存档编辑有限定。** 仅支持已确认的 `testament_new.sav` 容器版本 `0x107`；Steam Cloud 可能覆盖；游戏内是否接受仍需实测。
- **联机与 EAC。** 改动只在本机；联机前建议恢复原文件。游戏更新后先恢复再写入，否则可能无法连接 EAC。
- **没有自动更新。** 需要手动替换便携包；设置页的更新选项不会生效。
- **未签名。** exe 没有代码签名，SmartScreen/杀毒软件可能提示。
- **首次启动较慢。** 需要查找游戏、解密数据、校验类型库；大表按需生成行。

### 文档索引

| 文档 | 内容 |
|---|---|
| [PLAYER_DATA.md](offline/PLAYER_DATA.md) | 人物数据页的 Avatar 分组、偏移与核对结果 |
| [PLAYER_SAVE.md](offline/PLAYER_SAVE.md) | 当前装备栏、`testament_new.sav` 结构、备份/校验 |
| [ENEMY_DATA.md](offline/ENEMY_DATA.md) | 敌人编辑、敌人数据全局倍率、AI 设置 |
| [SPAWN_EDITOR.md](offline/SPAWN_EDITOR.md) | 刷怪编辑器：HiveMind、SEAF 目标 |
| [ENTITY_COMPONENTS.md](offline/ENTITY_COMPONENTS.md) | 实体组件总览：武器、生命、护盾、地雷、投掷、阵营、挂载、背包、炮塔、地狱舱 |
| [ENTITY_DEMOLITION.md](offline/ENTITY_DEMOLITION.md) | 实体拆毁：阈值覆盖、私有模板、Unit 别名、迁移 |
| [ENTITY_CATALOG_API.md](offline/ENTITY_CATALOG_API.md) | 实体分类/命名 JSON 与索引格式 |
| [PLANET_SETTINGS.md](offline/PLANET_SETTINGS.md) | 星球设置、行动修饰符、任务组件 |
| [MODIFIER_ATTACHMENTS.md](offline/MODIFIER_ATTACHMENTS.md) | 本地环境实体列表与旧八槽效果 ID 的区别 |
| [PRELOAD_COMPONENTS.md](offline/PRELOAD_COMPONENTS.md) | 预载设置：包合并、数组、清单、限制 |
| [PRESETS.md](offline/PRESETS.md) | 命名预设库、四类方案、迁移与存储 |
| [NAMED_PARAMETERS.md](offline/NAMED_PARAMETERS.md) | 角色名称、字体样式、网络接口参考 |
| [STRATAGEM_COMPONENTS.md](offline/STRATAGEM_COMPONENTS.md) | StratagemType / 战备参数 |
| [BOMBARDMENT_COMPONENTS.md](offline/BOMBARDMENT_COMPONENTS.md) | 轰炸组件 28 个字段 |
| [ORBITAL_WEAPON_COMPONENTS.md](offline/ORBITAL_WEAPON_COMPONENTS.md) | 轨道武器 140 字段与 56 个控制点 |
| [DAMAGE_COMPONENTS.md](offline/DAMAGE_COMPONENTS.md) | DamageType / 伤害记录 |
| [PROJECTILE_COMPONENTS.md](offline/PROJECTILE_COMPONENTS.md) | ProjectileType / 射弹记录 |
| [EXPLOSION_COMPONENTS.md](offline/EXPLOSION_COMPONENTS.md) | ExplosionType / 爆炸记录 |
| [ARC_COMPONENTS.md](offline/ARC_COMPONENTS.md) | ArcType / 电弧记录 |
| [BEAM_COMPONENTS.md](offline/BEAM_COMPONENTS.md) | BeamType / 激光记录 |
| [REFERENCE_NAVIGATION.md](offline/REFERENCE_NAVIGATION.md) | ID 类型标注与双击跳转 |

### 致谢

- **SHODAN**：上游 SHODAN Stat Editor / SSEO。
- **CowboyBingus**：Bingus Shared Loader，游戏内版本由它运行。
- **[LuaJIT](https://luajit.org)**（MIT）和 **[libsodium](https://libsodium.org)**（ISC）：随包运行时，许可见 `THIRD-PARTY-NOTICES.txt`。
- **Skyeshade（HD2Runtime）**：武器、战备、敌人目录和实体/Unit 布局研究。
- **SweetSwallow（Gameplay Reforged: Recovery Edition）**、**Nappleon（Little Enemy Kontrol）**：敌人和生成数值的定位参考。
- **[Filediver](https://github.com/xypwn/filediver)**、**[shalzuth/HelldiversData](https://github.com/shalzuth/HelldiversData)**、**[Darctor/Helldivers2_RawData](https://github.com/Darctor/Helldivers2_RawData)**：游戏数据布局、字段名和数值核对。
- **[helldivers-2/json](https://github.com/helldivers-2/json)**、**[BYVoid/OpenCC](https://github.com/BYVoid/OpenCC)**：星球名称与简繁转换。
- **[helldivers.io](https://helldivers.io/)**、**[Helldivers 2 wiki](https://helldivers.wiki.gg/)**：数据与护甲被动说明。
- **DiverKit**、**HD2 HUD Plus**：界面字体位置参考。

### 许可

[GNU General Public License v3.0](LICENSE)。你可以使用、修改和分发，但基于它的分发必须同样以 GPL v3 开放源码。

SHODAN Stat Editor 与 Arrowhead Game Studios、Sony Interactive Entertainment 没有隶属或背书关系。《绝地潜兵 2》及相关名称归其各自权利人所有。使用修改后的游戏文件风险自负。

<a id="en"></a>
## English

[简体中文](#zh) | **English**

### What this is

**SHODAN Stat Editor Offline** (SSEO) is a portable Windows program that changes values in **Helldivers 2's own data files**: weapons, throwables, stratagems, vehicles, boosters, attachments, armor passives, enemies, planets, entity components and some save fields. Edit, press **Install into the game**, then start the game. No mod loader is needed, and the game can stay closed while you edit.

This repository is Thodmcniujiao's fork, based on upstream **v4.1.0**. The main change is not "more numbers" but navigation and data views:

- **10 pages, each with sub-pages.** The single tab row and the separate Enemy Editor are replaced by pages; the enemy editor is one page among them.
- **From "pick an entity, then see its components" to "pick a component/data type, then find the entities".** Components, AI settings, the spawn editor and the game-data id pages all work this way.
- **New local save and file-level tools.** Current loadout reads and writes `testament_new.sav`; Planets, entity demolition and Preload work on local config files, entity deltas and packages.
- **A named preset library.** The old 1–5 quick slots per weapon and 50 full presets are replaced by named presets grouped by category; old presets are imported automatically on first start.
- **Upstream updates are off.** This fork cannot be silently replaced by an upstream binary; the window title and `app\build.txt` show `build <time>` for the local build.

UI languages: **English, Simplified Chinese, Traditional Chinese, Russian**. The version number stays at upstream **4.1.0**, but the content is not the same as upstream 4.1.0; use the build time.

**Branch:** `dev` holds source, build scripts, tests and documentation only; the portable package is published under Releases, whose tag names the matching source commit.

### Differences from upstream v4.1.0

| Area | Upstream v4.1.0 | This fork |
|---|---|---|
| Navigation | One row of 10 tabs; the Enemy Editor is a separate mode | **10 pages** at the top, with sub-pages/categories; enemies are an "Enemies" page |
| Weapons / throwables / stratagems / mechas / boosters / attachments / armor | Yes | Kept; entries regrouped by page |
| Helldiver | On the Armors tab | Its own "Character" page: full Avatar component + quick edit |
| Player save | No | Armory › Current loadout: local `.sav` read/write, backup, restore |
| Planets / operations / missions | No | Planet settings, local environment entities, operation modifiers, mission components |
| Entity components | Entity first, components second | 25 weapon component types, plus health, shield, mines, throwing, faction, mounts, backpack, turrets, hellpods, contact damage |
| Game data | Projectile / explosion / status records | Damage, projectile, explosion, arc, laser, status effect, stratagem; double-click to jump between ids |
| Orbital / Eagle | Some values | Full StratagemType + bombardment component + OrbitalAbility (140 fields, 56 2-D control points) |
| AI / spawning | Behavior and spawn rows inside the enemy pages | AI settings (5 components) + Spawn editor (HiveMind, 277 fields) |
| Preload / packages | No | Preload: manifest merge, environment package arrays, manifest editing |
| Presets | 5 per weapon + up to 50 full presets | Named preset library (4 scopes); old presets imported; quick slots removed |
| Updates | Checks GitHub releases at start | Disabled; the Settings options remain but nothing is checked or replaced |
| Packaging | `package.py` + CI | `build_release.bat`: pack, hash check, shortcut update, link check; CI kept |
| "Extra" page | Yes | Removed; drowning and hellpod values moved to Components |
| UI languages | EN / ZH-Hans / ZH-Hant / RU | Same; languages added by later upstream versions are not merged |

**Notes:**

- **4.1.0** is the upstream base version, not a claim that this fork equals upstream 4.1.0. Use the `build <time>` in the window title to tell local builds apart.
- Upstream changes after 4.1.0 have **not been systematically merged**; merging them means re-applying the local extensions.
- The updater is disabled by `LOCAL_ENTITY_EXTENSION` in `offline/host.lua`. Settings still shows "Updates" and "Update channel", but this build never checks for or installs an upstream version.

### Download and install

1. Download `SHODAN-Stat-Editor-Offline-*.zip` from [Releases](../../releases) and unzip it to any writable folder. The exe, the DLLs and the `app` folder must stay together.
2. **Close Helldivers 2**, then run `SHODAN Stat Editor Offline.exe`.
   - The program finds the game through Steam.
   - If it cannot, write the game folder's path into `%LOCALAPPDATA%\SHODAN\StatEditor\game folder.txt` and start it again.
3. Edit values, press **Install into the game** at the bottom, then start the game.
4. To go back to the game's own values, press **Restore the game's files**. Your edits stay saved; press Install again to re-apply them.

**Updates:** this fork does not update itself. Download a new portable package and unzip it over the program files; config, presets, logs and the game's originals in `%LOCALAPPDATA%\SHODAN\StatEditor` are not overwritten.

**The first run** may show a Windows SmartScreen or antivirus warning because the exe is not code-signed. Check where it came from.

**Package layout:**

```text
SHODAN Stat Editor Offline/
├─ SHODAN Stat Editor Offline.exe   launcher
├─ lua51.dll                        LuaJIT runtime
├─ libsodium.dll                    libsodium
├─ shodan_hash.dll                  hashing, download and install helper
├─ app/
│  ├─ stat_editor.lua               panel (byte-identical to src)
│  ├─ *.lua                         runtime modules (60)
│  ├─ entity_names.tsv              entity name index
│  ├─ entity_catalog.default.json   default entity categories
│  └─ build.txt                      version, commit, channel, build time
├─ *.md                             per-feature field documentation
├─ README.txt                       quick package readme
└─ THIRD-PARTY-NOTICES.txt          LuaJIT / libsodium notices
```

### The interface and feature map

The window's top bar holds **pages**; under a page title are its **sub-pages**. When a sub-page has several categories, their buttons sit beside the title. Four actions are always at the bottom: **Install into the game / Restore the game's files / Presets / Settings**. On the Current loadout page, the first two become **Write save / Restore save backup**.

| # | Page | Sub-pages | Status |
|---:|---|---|---|
| 1 | Features | Player · Movement · Weapons · Missions · Points of interest · Terminals · Stratagem settings | ○ placeholders |
| 2 | Character | Character data · Quick edit | ● working |
| 3 | Currency | Capture and send currency · Classic resource farming | ○ placeholders |
| 4 | Enemies | Enemy editor · AI settings · Spawn editor · Enemy swapper | ● 3 working / ○ 1 placeholder |
| 5 | Armory | Unlock · Weapon editing · Weapon attachments · Armor editing · Boosters · Loadout swap · Current loadout | ● 5 working / ○ 2 placeholders |
| 6 | Planets | Planet settings · Local environment entities · Campaign editing · Operation editing · Mission editing | ● 3 working / ◐ 1 partial / ○ 1 placeholder |
| 7 | Components | Weapon components · Weapon kinds · Weapon attachments · Turrets and guidance · Backpack · Mounts · Faction · Mines and throwing · Drowning · Health and demolition · Shield · Hellpods · Contact damage | ● all working |
| 8 | Orbital & Eagle | Orbital editing · Eagle editing · Orbital weapon editing | ● all working |
| 9 | Game data | Damage ids · Projectile ids · Explosion ids · Arc ids · Laser ids · Status effect ids · Stratagem ids | ● all working |
| 10 | Misc & settings | Identity · Named parameters · Editor settings · Preload · Finder | ● 2 working / ◐ 1 partial / ○ 2 placeholders |

Legend: ● working　◐ partial (some placeholder tabs)　○ placeholder (lists plans only; changes nothing)

**Where to change what:**

| What you want to change | Where |
|---|---|
| Weapon and throwable values | Armory › Weapon editing |
| Attachments, armor passives, boosters | Armory › Weapon attachments / Armor editing / Boosters |
| Stratagem cooldowns, uses, call-in codes, Eagles, orbitals, sentries | Game data › Stratagem ids › Stratagems |
| Exosuits, FRVs, tanks | Game data › Stratagem ids › Vehicles |
| Orbital weapons and barrage values | Orbital & Eagle |
| Enemies, AI, spawning | Enemies |
| Planet generation, environment, weather, operations, missions | Planets |
| One entity's health, shield, weapon components, ... | Components |
| The damage/projectile/explosion/arc/laser/status/stratagem records themselves | Game data |
| The loadout in your local save | Armory › Current loadout |
| Preload packages, manifests, environment package arrays | Misc & settings › Preload |
| Character subtitles, font styles | Misc & settings › Named parameters |

### Page by page

#### 1. Features (placeholders)

Seven sub-pages are kept from the layout document: Player, Movement, Weapons, Missions, Points of interest, Terminals, Stratagem settings. They are **placeholders**: they list planned features (god mode, infinite ammo, completing objectives, showing every objective, ...) and write nothing to the game.

Real mission and spawn editing lives in **Planets › Mission editing** and **Enemies › Spawn editor**.

#### 2. Character

- **Character data:** edits the helldiver entity's (`content/fac_helldivers/cha_avatar/avatar_helldiver`) `AvatarComponentData` (852 bytes). The fields follow the layout document's boxes: speed, climbing, stamina, turn speed, detection/stealth, throwing/weathering, self-healing, sliding, ragdoll/misc, weapon-switching states. Every row shows the component offset and member name.
- **Quick edit:** only the common values: the health component (health, regeneration, body parts) and the faction component (factions 1–3). It shares fields with **Components › Health and demolition / Faction**, so a change on one page shows on the other.
- These are **local values**; they do not unlock account items or change a server profile. Restore the game's files before joining other players.

See [PLAYER_DATA.md](offline/PLAYER_DATA.md).

#### 3. Currency (placeholders)

"Capture and send currency" and "Classic resource farming" are placeholders. They list planned features (enable, edit supply drops, replace a stratagem, collect samples, super mission rewards) and change nothing.

#### 4. Enemies

- **Enemy editor:** 4 categories:
  - **Enemies:** Terminids, Automatons and Illuminate in one list, filtered by a faction selector on the left (all / Terminids / Automatons / Illuminate). Each faction still starts with its "All Terminids / All Automatons / All Illuminate" multiplier page.
  - **SEAF:** every SEAF soldier kind and the weapons it carries.
  - **Spawning:** per-faction multipliers for reinforcements, patrols, outposts and spawners.
  - **Enemy data:** one "All enemies" global multiplier page: health, armor, stagger resistance, stun/gas resistance, fire damage taken, damage, movement speed, sight range. It applies to all three factions (not SEAF) and **multiplies** each faction's rows; enemies edited on their own page keep their values.
- **AI settings:** 5 tabs for the enemies' AI, AI character, sight, hearing and danger sense, with every field. They share fields with the enemy pages and multiplier rows.
- **Spawn editor:** the enemy director (HiveMind, 1084 bytes, 277 fields, 19 records) and SEAF objectives (96 bytes, 24 fields, 1 record). The Spawning page's multiplier rows share these fields.
- **Enemy swapper:** placeholder.

Opening the Enemies page turns the interface red; leaving it restores the normal colour. The old **SHODAN Enemy Editor** toggle at the top left is gone: the page replaces it, and one Install applies both editors' changes. See [ENEMY_DATA.md](offline/ENEMY_DATA.md) and [SPAWN_EDITOR.md](offline/SPAWN_EDITOR.md).

#### 5. Armory

- **Weapon editing:** Primary, Secondary, Support and Throwables. All the upstream weapon values are here: damage, durable damage, armor penetration, demolition, stagger, push, fire rate, ballistics, explosion, arc, burning/gas, magazine/spare/reload, recoil/spread/sway/ergonomics, heat, slot, projectile swap.
- **Weapon attachments:** optics, underbarrels, muzzles (including weapons' own muzzle brakes), shotgun chokes and ammunition types.
- **Armor editing:** every armor passive. A passive can include other passives (**Also includes** / **Own effects**), and any armor can be made light, medium or heavy.
- **Boosters:** Experimental Infusion, Firebomb Hellpods / Stun Pods, Concealed Insertion, Dead Sprint, Armed Resupply Pods, surplus EAT and the rest.
- **Current loadout:** reads and writes the local `testament_new.sav`. Four parts:
  - **Saved equipment:** helmet, armor, cape, primary, secondary, grenade, victory pose ID, player card background ID.
  - **Equipment catalog:** item definitions from the local `LoadoutEntryComponentData` and `HelldiverCustomizationKit`; type a decimal id, a `0x` id or a unique item name. This catalog is item definitions, not the account's unlocks.
  - **Save files and backups:** detected Steam saves, a manual path, backup restore.
  - **Unidentified save fields:** the 8 raw u32 values near the appearance records; they are not guessed to be titles, body types or voices.
  - Writing back backs up the save first, checks CRC32/LZ4 and detects a save changed by another program; only the confirmed container version `0x107` is supported. Close the game before writing. Steam Cloud may still overwrite the file. See [PLAYER_SAVE.md](offline/PLAYER_SAVE.md).
- **Unlock and Loadout swap:** placeholders.

#### 6. Planets

- **Planet settings:** 8 categories: planet generation (438 records), modifiers (15 Modifier records), environment (17), weather (184), planet types, solar/galactic (137), regions/territory, environment ECS. Field names are labelled by source — value-checked, same-value, order-inferred, legacy-inferred or unknown; unknown fields show their offset. **Galactic-map ownership, health, regeneration, coordinates, locks and active effects come from the server and are not here.**
- **Local environment entities:** two 64-bit entity reference arrays: planet environment entities (the `gameplay_modifiers` of 438 planet records) and event entity lists (experimental; GalacticPresence arrays A and B). Entries can be added, replaced and deleted. These are **not** the old memory editor's eight 32-bit effect ids; what A and B do at runtime is not confirmed.
- **Operation editing:** 14 entity deltas that change GameMode or HiveMind: reinforcement time, immediate extraction, map size, mission time limit, patrol interval, encounter cap, wild encounters and so on.
- **Mission editing:** mission rules and reinforcements (GameModeComponent, 23 fields / 19 entities), mission mode switches (GameModeMissionComponent, 6 fields / 17 entities), and **mission objective editing** (placeholder).
- **Campaign editing:** placeholder.

See [PLANET_SETTINGS.md](offline/PLANET_SETTINGS.md) and [MODIFIER_ATTACHMENTS.md](offline/MODIFIER_ATTACHMENTS.md).

#### 7. Components

| Sub-page | Contents |
|---|---|
| Weapon components / Weapon kinds / Weapon attachments | All 25 `Weapon*` components, 1,631 leaf members. WeaponData: 329 fields / 373 entities; reload, magazine, charge, rounds, heat, wind-up, assisted reload; projectile, spray, arc, beam, melee, ability, guided, physics and mounted weapons; weapon customization, attachment, flashlight, laser, screen, linked ammo, linker, wielder |
| Turrets and guidance | Sight (SensorEye: 11 fields / 315 entities) + turret (19 fields / 74 entities) |
| Backpack | Inventory (20 fields / 86 entities): default primary/secondary/support/throwable/backpack/melee, stims, droppable gear |
| Mounts | Mount (30 fields / 164 entities): up to 5 mount points; an incompatible entity can crash the game when it spawns |
| Faction | Faction (32 fields / 533 entities): faction bit values, targeting nodes, spawn influence, ignored units |
| Mines and throwing | Minefield (11 fields / 13 entities), mine spawner (7 / 8), throwable (78 / 46), thrower (186 / 5) |
| Drowning | Every field of `DrownableComponentData` (64 bytes); the helldiver shares the old "Extra" page fields |
| Health and demolition | Health (22,096-byte records; whole body and parts) + entity demolition (thresholds 0–4,294,967,295, private templates, Unit alias isolation) |
| Shield | `ShieldComponentData` (344 bytes, 83 items): capacity, recharge, shape, colour, charge events, audio, animation |
| Hellpods | Descent (26 fields / 8 entities), payload (3 / 117), rack (124 / 72), ship hellpod (1 / 2) |
| Contact damage | `OverlapDamageComponentData` (385 fields / 64 entities): 8 damage zones per entity |

- **Full entity catalog:** about 3,400 ECS entities and scene Units in one catalog, shared by the health, demolition, drowning and shield pages. Entities without the current component are shown greyed out by default and can be hidden.
- **Categories and names:** `entity_catalog.json` customizes categories, rules and entity names; `entity_catalog.index.json` is a full index for external tools. The JSON changes display only, never game resources or hashes. See [ENTITY_CATALOG_API.md](offline/ENTITY_CATALOG_API.md).
- **Field sources:** layouts are checked against the installed game's type library at start; names come from the type library, RawData dumps and the 2024 structures, and inferred or unknown fields are labelled in the tooltips.
- The original weapon, enemy and turret pages share the same fields as the component pages; a change on one shows on the other. See [ENTITY_COMPONENTS.md](offline/ENTITY_COMPONENTS.md) and [ENTITY_DEMOLITION.md](offline/ENTITY_DEMOLITION.md).

#### 8. Orbital & Eagle

- **Orbital editing:** StratagemType values (400 bytes, 67 type-library members; the table currently has 153 records) + the bombardment component (192 bytes, 28 fields): bombs per salvo, intervals, salvos, spread, walking-barrage speed, 8 projectile slots and so on.
- **Eagle editing:** EagleComponentData (rearm, payload, run length, ...) + the StratagemType parameters.
- **Orbital weapon editing:** OrbitalAbilityComponentData (568 bytes, 140 fields, 2 records: the orbital laser and the orbital railcannon strike), including duration, tracking, damage area, projectile spawn, effects, faction filters, movement path and 56 2-D control points (112 coordinates).

All three use the same StratagemType fields; damage, projectile and explosion references can be double-clicked to jump. See [STRATAGEM_COMPONENTS.md](offline/STRATAGEM_COMPONENTS.md), [BOMBARDMENT_COMPONENTS.md](offline/BOMBARDMENT_COMPONENTS.md) and [ORBITAL_WEAPON_COMPONENTS.md](offline/ORBITAL_WEAPON_COMPONENTS.md).

#### 9. Game data

| Sub-page | Records | Size |
|---|---|---|
| Damage ids | `DamageInfo` | 76 bytes / 19 parameters |
| Projectile ids | `ProjectileInfo` | 272 bytes / 73 items (355 records) |
| Explosion ids | `ExplosionInfo` | 152 bytes / 40 members (424 records; 44 fixed items + camera-shake array) |
| Arc ids | `ArcInfo` | 104 bytes / 21 parameters (16 records) |
| Laser ids | `BeamInfo` | 112 bytes / 25 members (30 records) |
| Status effect ids | `StatusEffectInfo` | 160 bytes, grouped into identity, strength/duration, damage reference, effects, audio, flags, multipliers and unknown fields |
| Stratagem ids | `StratagemInfo` | 400 bytes / 67 members (153 records); the same sub-page also has **Stratagems** and **Vehicles** categories |

- Values that reference other records are labelled `projectile_id`, `explosion_id`, `damage_id`, `status_effect_id`, `arc_id`, `beam_id`, `stratagem_id` and so on. Click to edit, **double-click to jump** to the record; 0 means no reference, and an id that does not exist is rejected.
- Jumps can chain: **projectile → impact explosion → damage → status effect**.
- The **Stratagems** category is the old Stratagems tab (cooldowns, uses, call-in codes, Eagles, orbitals, sentries, backpacks, ...); **Vehicles** is the old Mechas tab (exosuits, FRVs, tanks and their weapons).

See [REFERENCE_NAVIGATION.md](offline/REFERENCE_NAVIGATION.md), [DAMAGE_COMPONENTS.md](offline/DAMAGE_COMPONENTS.md), [PROJECTILE_COMPONENTS.md](offline/PROJECTILE_COMPONENTS.md), [EXPLOSION_COMPONENTS.md](offline/EXPLOSION_COMPONENTS.md), [ARC_COMPONENTS.md](offline/ARC_COMPONENTS.md) and [BEAM_COMPONENTS.md](offline/BEAM_COMPONENTS.md).

#### 10. Misc & settings

- **Named parameters:** 3 categories:
  - **Character names:** `CharacterNameComponentData` (91 entities, 4 fields): race, random-name template, character subtitle name id, use persistent seed.
  - **Font styles:** `FontSettings` (6 language font sets, 180 styles, 720 editable fields): font size, shadow range and so on; these are shared local styles.
  - **Network reference:** read-only names, hashes and parameter counts for `rpc_ingame_chat_message`, `rpc_set_player_info`, `rpc_sync_player_info` and similar; nothing is written.
  - See [NAMED_PARAMETERS.md](offline/NAMED_PARAMETERS.md).
- **Preload:** 7 categories: Extra preload, Global / mission, Loadout, Enemies, World, Catalog, Hot join. Pick packages by name/hash, merge manifests, append to environment package arrays and add/replace/delete package contents.
  - **Filediver CLI** is needed to read/export packages; the program finds it automatically, or use `SHODAN_FILEDIVER`, `tools\filediver.exe` or `filediver path.txt` in the config folder.
  - Install writes a separate `.patch_N`; the original NXA container is left as it is. Restore removes only the patches this editor owns.
  - This is verified at the file level; **it is not confirmed in game** that the new arrays are consumed at runtime or that global/mission manifest merging keeps everything resident. See [PRELOAD_COMPONENTS.md](offline/PRELOAD_COMPONENTS.md).
- **Editor settings:** font size, render resolution and other display options, saved immediately; the remaining old items are shown as placeholders.
- **Identity and Finder:** placeholders.

### What the upstream editor already did

| Category | What you can change (summary) |
|---|---|
| Weapons | Damage, durable damage, armor penetration, demolition, stagger, push, fire rate, ballistics, explosion/arc, burning/gas, magazine/spare/reload, recoil/spread/sway/ergonomics, heat, slot, projectile swap |
| Throwables | Starting/max/supply count, throw distance, fuse, explosion, shrapnel, arc, burning/gas |
| Stratagems | Cooldown, uses, call-in code, Eagles, orbital barrages/laser, guard dogs, sentries/emplacements, minefields, jump/hover/warp packs, backpack charges |
| Mechas / vehicles | Cooldown, health/armor, body parts, weapons; each weapon edits like a weapon page |
| Boosters | Experimental Infusion, Firebomb/Stun Pods, Concealed Insertion, Dead Sprint, Armed Resupply Pods, surplus EAT |
| Attachments | Optics, underbarrels, muzzles, chokes, ammunition types and their multipliers |
| Armor / helldiver | Every armor passive, passive stacking, armor weight; the helldiver now lives on the Character page |
| Enemies | Health/armor/body parts, behavior/senses, attacks, enemy weapons, shields/jamming, SEAF, faction multipliers, spawning |

The upstream README's per-field tables remain a reference for these values; this fork changed the entry points and grouping, not the fields.

### Install, restore and compatibility

- **Install into the game** runs only while the game is closed. The editor finds the changed files, keeps the checksum the game expects and writes a `.patch_N` package when needed; before writing it keeps the originals in `%LOCALAPPDATA%\SHODAN\StatEditor\originals` and rolls back on failure.
- **Restore the game's files** puts the files the editor changed back to their state before installation and removes the asset patches this editor owns; other mods' files are kept.
- **Other mods:** install the other mod first, then press Install here. This editor keeps their changes and adds yours on top; where both change the same value, this editor wins. This has not been exhaustively tested.
- **Game updates / Steam's file verification:** the game's own files come back. Restore first, then Install again, or the game may fail to connect to EAC.
- **Current loadout's "Write save"** is a separate action: it only writes the selected `.sav`, not the game's data files.
- **Preload and entity demolition** need Filediver when packages or Unit clones are involved; without it the affected install fails with a message, and the other pages are unaffected.
- **Multiplayer:** changes only exist in your game; restore the game's files before joining other players. Modified game files are used at your own risk.

### Presets

The **Presets** button at the bottom opens a separate workspace: the top navigation, categories, entity list and value table are hidden; pick a preset on the left, then load, overwrite, rename or delete it on the right. **Esc** or "Back to editor" returns and restores the page, selection, scroll position and search you had.

There are 4 preset scopes:

| Scope | Contents |
|---|---|
| Game values | General resource values and armor passive stacking/switches; loading replaces only this scope and keeps enemy values |
| Enemy values | Enemy and spawning values; loading does not clear other game values |
| Save loadout | The editable loadout fields of the current save; loading only stages them, and "Write save" on the loadout page writes the file |
| Preload plans | Package manifests, extra package choices, load targets, array edits and the preload pages' resource values |

- All named presets live in `%LOCALAPPDATA%\SHODAN\StatEditor\preset_library.json` with stable ids; there is no longer a "5 per weapon" limit.
- On first use, old presets in `preset_01.txt`–`preset_50.txt`, `enemy_preset_01.txt`–`enemy_preset_50.txt`, `weapon_presets.txt`, `player_save_presets.json` and `preload_config.json` are imported; the original files stay, the import source is recorded, and a restart does not import them again.
- The library uses schema-checked JSON: write a temporary file, read it back, then replace atomically. If another editor changed the library, the write is refused.
- Keyboard: **Enter** load, **Insert** new, **Shift+Insert** overwrite, **F2** rename, **Del** delete, **Esc** back.
- The old 1–5 quick slots, Save/Load/Clear buttons and `Ctrl+1–5` shortcuts **have been removed**.

See [PRESETS.md](offline/PRESETS.md).

### Settings, search and keyboard

**Settings** (bottom right) is also a separate workspace:

| Setting | Effect |
|---|---|
| Language | English / Simplified Chinese / Traditional Chinese / Russian |
| Apply my changes | Off: Install writes the game's own values; your changes stay saved and come back when it is on again |
| Font size / render resolution | Panel text size and drawing resolution. Drag the window edges or maximize it to resize the panel. |
| Several vehicles of a kind | Off by default; on, a loadout can take more than one exosuit, FRV or tank |
| Better stratagem bounce | Off by default; stratagem balls stick on more surfaces |
| Foliage pass-through | Off by default; rockets, launcher rounds and stratagem ordnance fly through canopies and bushes |
| Sniper crosshair in third person | Off by default; sniper rifles show a crosshair when aiming in third person |
| Tabs shown | Hide what you do not use; search skips it too |
| Reset all values | Every current change back to the game's values (asks twice) |
| Updates / Update channel | This fork does not check for updates; the options remain and never replace the local build |
| GitHub / Logs and Presets | Open the project link or `%LOCALAPPDATA%\SHODAN\StatEditor` |

Settings are saved to `config.txt` immediately.

**Search:** click the box under the list (or press `Ctrl+F`) and type. The list shows the weapons/stratagems of every page whose name contains every word; on Components it searches entity names or hashes; on Game data it searches records. **Enter** keeps the results, **Esc** or **X** clears them.

**Keyboard:**

| Key | Action |
|---|---|
| Up / Down | Previous / next item |
| Left / Right | Change a value (hold Shift for bigger steps) |
| Enter, or click a value | Type a value (Enter sets it, Esc cancels) |
| PgUp / PgDn | Previous / next weapon or record |
| Ctrl+F | Search |
| Del | Reset the current value to the game's |
| Esc | Cancel typing / close a workspace / back to the editor |

### Files and data locations

All user data is in `%LOCALAPPDATA%\SHODAN\StatEditor`:

| Path | Contents |
|---|---|
| `config.txt` | Settings, ordinary overrides, hidden tabs |
| `preset_library.json` | Named preset library |
| `entity_demolition.txt` | Entity demolition overrides |
| `entity_assets_installed.txt` | Asset patch ownership |
| `preload_config.json` | Preload manifests, arrays and plans |
| `entity_catalog.json` / `entity_catalog.index.json` | Entity category/name config and full index |
| `originals\` | Backups of the game's original files |
| `Logs\SHODANStatEditor.log` / `SHODANStatEditorHost.log` | Panel log / host log |
| `game folder.txt` | Manually set game folder |
| `filediver path.txt` | Filediver CLI path |
| `demolition-migration-backups\` | Backups from the old demolition config migration |

These are created as needed; deleting the config folder loses presets and edits (the game's originals can still be put back with Restore).

### Building, packaging and tests

**Requirements:**

- Windows 10/11 x64 and Visual Studio 2022 Build Tools (C++).
- [LuaJIT](https://luajit.org) 2.1 source.
- [libsodium](https://libsodium.org) 1.0.22 x64 DLL.
- Python 3 for the packaging and test scripts.

**Steps:**

1. Build `lua51.dll` with LuaJIT's `msvcbuild.bat`.
2. Set `LJ` to LuaJIT's `src` folder and run `offline\launcher\build.bat` to build `SHODAN Stat Editor Offline.exe` and `shodan_hash.dll`.
3. Put `lua51.dll` and `libsodium.dll` in `offline\runtime\`.
4. Run `build_release.bat` in the project root:
   - pack into `offline\release\<yyyyMMdd-HHmmss>\SHODAN Stat Editor Offline\`;
   - check `app\stat_editor.lua` is byte-identical to `src\stat_editor_offline.lua`;
   - write `app\build.txt` (version, commit, channel, build time);
   - point `SHODAN Stat Editor Offline.lnk` in the project root at the new exe;
   - check running copies and desktop/Start-menu shortcuts for old code.
   - `-NoShortcut` packs only and leaves the shortcut alone.
5. For a zip, run `python offline\package.py`; CI uses it too (`SSEO_CHANNEL=dev`, `SSEO_COMMIT=<sha>`).

**Tests:**

```bat
python tests\run_lua.py tests\check_syntax.lua
python tests\run_lua.py tests\test_preset_library.lua --isolated-profile --work .test-work\check
```

Some tests need the local game data or test fixtures; pass `--fixtures`, `--game` or `--work`. Tests use isolated config folders and do not write the real game or saves.

**CI:** `.github/workflows/dev-build.yml` builds a Development build pre-release on pushes to `main`; this fork disables the client's auto-update, so a CI build never replaces the local version by itself.

**Filediver:** Preload and entity demolition's Unit cloning need the [Filediver](https://github.com/xypwn/filediver) CLI. The program looks in `Downloads\Compressed\filediver-cli\filediver.exe`, and also accepts `SHODAN_FILEDIVER`, `tools\filediver.exe` or `%LOCALAPPDATA%\SHODAN\StatEditor\filediver path.txt`.

### Repository layout

```text
.
├─ src/
│  ├─ stat_editor_offline.lua     offline panel (packed as app/stat_editor.lua)
│  └─ stat_editor.lua             upstream v2.5.0 in-game panel source, not used offline
├─ offline/
│  ├─ host.lua                    desktop host: window, page bar, install/restore
│  ├─ engine_shim.lua             Win32/GDI window and input
│  ├─ gamedata.lua                game data decrypt/encrypt and checksums
│  ├─ install.lua                 install, restore, originals, rollback
│  ├─ update.lua                  upstream updater (disabled by the host in this fork)
│  ├─ launcher/                   launcher exe and shodan_hash.dll C sources
│  ├─ runtime/                    lua51.dll, libsodium.dll
│  ├─ *.lua                       character, enemy, planet, component, preload, preset modules
│  └─ *.md                        field-level documentation (see the index below)
├─ tools/
│  ├─ build_release.ps1           local packaging and link check
│  ├─ component_gen/              component field-name generators
│  └─ planet_gen/                 planet settings field-name generators
├─ tests/                         LuaJIT tests
├─ images/                        old screenshot (upstream UI, not yet updated)
├─ .github/workflows/             CI
├─ build_release.bat              packaging entry point
└─ LICENSE                        GPL-3.0
```

`src\stat_editor.lua` is the upstream v2.5.0 **in-game** panel source. It needs Bingus Shared Loader and no longer works on current game builds; the offline editor uses only `src\stat_editor_offline.lua`.

### Known limitations

- **Placeholders change nothing.** Features, Currency, Identity and Finder list plans only; the grey text and the page notes are authoritative.
- **Galactic-map server data cannot be changed.** Planet ownership, health, regeneration, coordinates, locks and active effects are not in local files.
- **Some new features are verified at the file level only.** The planet environment arrays, preload manifest merging/arrays, save loadout and entity demolition's private templates/Unit aliases have not all been confirmed in game; see each document's "verification" section.
- **Filediver-dependent features.** Preload and entity demolition need the Filediver CLI when packages or Unit clones are read or cloned; without it they fail with a message.
- **Shared records.** When several entities/weapons reference one health, damage, explosion or component record, editing one changes them all; the page usually says how many share it.
- **Game updates can change layouts.** Offsets and types are checked against the type library at start; on a mismatch the page says so and keeps the old parsing, and unknown fields are labelled "unknown". Do not bulk-write without checking.
- **Entity swaps can break things.** An incompatible mount, backpack item or spawner entity can crash the game when it spawns; minefield panel counts and mines per panel can only be lowered.
- **Save editing is limited.** Only the confirmed `testament_new.sav` container version `0x107` is supported; Steam Cloud may overwrite it; in-game acceptance still needs testing.
- **Multiplayer and EAC.** Changes only exist in your game; restore before joining others. After a game update, restore first and then install again, or the game may fail to connect to EAC.
- **No auto-update.** Replace the portable package by hand; the Settings update options do nothing.
- **Unsigned.** The exe is not code-signed, so SmartScreen or antivirus software may warn.
- **Slow first start.** It finds the game, decrypts data and checks the type library; large tables build their rows on demand.

### Documentation

| Document | Contents |
|---|---|
| [PLAYER_DATA.md](offline/PLAYER_DATA.md) | Character page Avatar groups, offsets and verification |
| [PLAYER_SAVE.md](offline/PLAYER_SAVE.md) | Current loadout, `testament_new.sav`, backups and checksums |
| [ENEMY_DATA.md](offline/ENEMY_DATA.md) | Enemy editor, global enemy-data multipliers, AI settings |
| [SPAWN_EDITOR.md](offline/SPAWN_EDITOR.md) | Spawn editor: HiveMind and SEAF objectives |
| [ENTITY_COMPONENTS.md](offline/ENTITY_COMPONENTS.md) | Components overview: weapons, health, shield, mines, throwing, faction, mounts, backpack, turrets, hellpods |
| [ENTITY_DEMOLITION.md](offline/ENTITY_DEMOLITION.md) | Entity demolition: threshold overrides, private templates, Unit aliases, migration |
| [ENTITY_CATALOG_API.md](offline/ENTITY_CATALOG_API.md) | Entity category/name JSON and index format |
| [PLANET_SETTINGS.md](offline/PLANET_SETTINGS.md) | Planet settings, operation modifiers, mission components |
| [MODIFIER_ATTACHMENTS.md](offline/MODIFIER_ATTACHMENTS.md) | Local environment entity lists versus the old eight-slot effect ids |
| [PRELOAD_COMPONENTS.md](offline/PRELOAD_COMPONENTS.md) | Preload: package merge, arrays, manifests, limits |
| [PRESETS.md](offline/PRESETS.md) | Named preset library, four scopes, migration and storage |
| [NAMED_PARAMETERS.md](offline/NAMED_PARAMETERS.md) | Character names, font styles, network reference |
| [STRATAGEM_COMPONENTS.md](offline/STRATAGEM_COMPONENTS.md) | StratagemType / stratagem values |
| [BOMBARDMENT_COMPONENTS.md](offline/BOMBARDMENT_COMPONENTS.md) | Bombardment component's 28 fields |
| [ORBITAL_WEAPON_COMPONENTS.md](offline/ORBITAL_WEAPON_COMPONENTS.md) | Orbital weapon's 140 fields and 56 control points |
| [DAMAGE_COMPONENTS.md](offline/DAMAGE_COMPONENTS.md) | DamageType / damage records |
| [PROJECTILE_COMPONENTS.md](offline/PROJECTILE_COMPONENTS.md) | ProjectileType / projectile records |
| [EXPLOSION_COMPONENTS.md](offline/EXPLOSION_COMPONENTS.md) | ExplosionType / explosion records |
| [ARC_COMPONENTS.md](offline/ARC_COMPONENTS.md) | ArcType / arc records |
| [BEAM_COMPONENTS.md](offline/BEAM_COMPONENTS.md) | BeamType / laser records |
| [REFERENCE_NAVIGATION.md](offline/REFERENCE_NAVIGATION.md) | Id type labels and double-click jumps |

### Credits

- **SHODAN**: the upstream SHODAN Stat Editor / SSEO.
- **CowboyBingus**: Bingus Shared Loader, which runs the in-game version.
- **[LuaJIT](https://luajit.org)** (MIT) and **[libsodium](https://libsodium.org)** (ISC): the bundled runtimes; their licences are in `THIRD-PARTY-NOTICES.txt`.
- **Skyeshade (HD2Runtime)**: weapon, stratagem and enemy catalogs and entity/Unit layout research.
- **SweetSwallow (Gameplay Reforged: Recovery Edition)** and **Nappleon (Little Enemy Kontrol)**: references for locating enemy and spawn values.
- **[Filediver](https://github.com/xypwn/filediver)**, **[shalzuth/HelldiversData](https://github.com/shalzuth/HelldiversData)** and **[Darctor/Helldivers2_RawData](https://github.com/Darctor/Helldivers2_RawData)**: game data layouts, field names and value comparison.
- **[helldivers-2/json](https://github.com/helldivers-2/json)** and **[BYVoid/OpenCC](https://github.com/BYVoid/OpenCC)**: planet names and simplified/traditional conversion.
- **[helldivers.io](https://helldivers.io/)** and the **[Helldivers 2 wiki](https://helldivers.wiki.gg/)**: data dumps and armor passive descriptions.
- **DiverKit** and **HD2 HUD Plus**: references for the game's UI font.

### Licence

[GNU General Public License v3.0](LICENSE). You can use, change and share it, but anything you distribute that is based on it must also be released under GPL v3 with its source.

SHODAN Stat Editor is not affiliated with or endorsed by Arrowhead Game Studios or Sony Interactive Entertainment. Helldivers 2 and related names belong to their respective owners. Modified game files are used at your own risk.
