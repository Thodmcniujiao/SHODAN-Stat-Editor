## 2026-10-31 — 参数收藏、显示名称与阵营刷新修复

- 参数右键支持收藏、取消收藏、自定义名称和恢复默认名称；每个组件顶部提供收藏组，同种组件的相同字段共用偏好，收藏行和原行共用数值。
- 收藏和名称即时保存到便携目录 `Data/parameter_preferences.json`，清缓存和恢复游戏原版时保留；提示中仍可查看原名称。
- 修复空收藏占位行进入阵营刷新导致退出的问题；计算、目标缓存及批量重置使用原参数行，避免收藏倍率和护甲加值被重复计算。覆盖全局与阵营叠加、单个生物覆盖及重置回归。
- 简体、繁体的“星球效果修饰”分页与内部标题去掉 `Modifier` 后缀。
- 开发包改为从 `dev` 自动构建和预发布；发布前运行源码与便携数据回归，检查压缩包不含个人数据，并附 SHA256 校验文件。

## 2026-10-31 — 旧配置迁移修复与便携数据隔离

- 基于最新本地构建 `20261031-023325`，修复启动应用旧属性 ID 时 `set_override` 访问空 `field` 导致退出的问题。旧 ID 删除与真实字段覆盖分离，保留多附件迁移、已安装值重置和共享字段去重。
- 离线版配置、日志、缓存、原始备份与安装记录统一保存在程序旁的 `Data`；预设与名称使用旁边的 `Presets`、`Names`。停止从 AppData 或之前记录的外部预设目录自动导入数据；存档备份迁入 `Data/save-backups`，取消对用户下载目录中 Filediver 的隐式依赖。
- 更新随包说明，新增便携目录及旧数据手动迁移指南；新增迁移保存重载、已安装重置和多副本隔离回归测试。

<!--
  v0.0.8 · Thodmc Reorganized · build 20261030-031645
  app 4.5.1 dev 4794aee · compared with v4.1.0 build 20261028-232444 (commit 48b98de)
  package: SHODAN-Stat-Editor-Offline-v4.5.1-dev-4794aee.zip
-->

**Release**: 0.0.8, Thodmc Reorganized · build 20261030-031645.

**Names and descriptions**: Name and Description boxes at the bottom of weapon, throwable and
stratagem pages. Type your own and Install puts them in the game, in every language; R puts the
game's own back.

**Helldiver**

- **Melee and bayonet** strikes: the whole damage record — damage, durable damage, armor penetration
  at every angle, demolition, stagger and push, element and status effect.
- **Head hits**: how much a hit to the head costs your health, 1.5 by default.
- **Weapon sway (x)**: the sway of every weapon you aim yourself at once, emplacements and vehicle
  guns too. A weapon whose sway you set on its own page keeps it, and shows blue.
- **Suppression**: how close enemy fire must pass to shake your aim, how far it builds up, and
  whether near misses count.

**Weapons**

- **Infinite ammo** switch on every gun, sentry and vehicle weapon.
- **Spray** section for flamethrowers: warm-up, pilot light, hit radius, ammo per puff and setting off
  mines.
- **Lock-on range** for the Spear, WASP, Warrant and Missile Pistol.
- **Aim zoom** for guns with built-in sights, like the Constitution; its three levels scale together.
- **Holster position** on primaries: on the back, or on the hip where pistols hang. The node, its
  three rotations and three offsets are listed beside it and hold the same value.
- **Bayonet** melee rows on the Constitution, Sweeper and Amendment. They share one record, so one
  edit changes all three.
- The Punisher, Slugger, Cookout and Halt show both of their 8-round tubes, each editable.
- **Railgun**: a switch to stop it blowing up when overcharged.
- **Sparks** section on the Pyrotech for the sparks' damage and status effects.
- Support weapons: **Picked up into** row, puts it in your primary slot when you pick it up.
- **Cone angle** where the game sets one: weapons, backpacks, mines, throwables, stratagems and death
  explosions.
- No spare magazine rows on guns that never get spares.
- One fire rate row for guns with a single rate, showing the game's default.

**Stratagems**

- **Payload edits**: removed payload-driven automatic preload into global, stratagem and environment packages. Explicit preload plans remain independent; the next Install removes obsolete owned payload-preload patches and restores environment data that is no longer requested.
- **Stratagem editing**: a new Armory sub-page, with tabs for stratagems and mechas.
- **Items per drop** in a new Hellpod section, so one pod can drop two weapons or packs; 2 puts a
  second one on the pod's other side.
- **Bomb pattern** on Eagles: how many bombs one run drops, and how many each mode gives.
  **Time between bombs (s)** sets the gap between them.
- **Sentry aiming**: how far a sentry can turn up, down, left and right, and which **Faction** it
  fights for.
- **Time deployed** for the Shield Generator Relay.
- Backpack ammo stops at 1023, the most the game holds, and says why.

**Vehicles and exosuits**

- **Vehicle handling** on the three FRVs and both tanks: weight, center of mass height and its
  front-back and left-right position, engine torque, top engine speed, gears, front and rear brake
  strength, and the wheels' grip, size, spring stiffness, damping and suspension travel.
- **Exosuit movement**: walk speed, turn speed, stomp speed, get in and out speed, drop landing speed
  and stagger recovery speed, plus the speed of everything else the suit plays.
- Every row says what it changes: what heavier means, what a lower gear ratio gives, what a softer
  spring does.

**Records**: every entity and every TypeID index has its own name now, one file per group in
`EntityNames` and per type in `TypeIdNames`, with a box to jump to any id. The old name files import
once.

**Armors**: the O-44 Bonded Pilot and six other armors the game names only by their helmet are named
now.

**Enemy Editor**

- **Animation speed** on every enemy, with its own **Attack animation speed** and **Stagger recovery
  speed**. Faster attack animations make attacks come out sooner. Also on the All-faction pages.
- **Movement speed for each behaviour**: idle, patrol, search, fight, strafe, drift, retreat and
  charge.
- **Suppression**: how close your shots must land, how hard your fire throws off an enemy's aim, and
  how long its aim stays off after you stop, or **Never**.
- **Tracking after losing sight (x)**: how long an enemy keeps hunting you, 1 to 20.
- **Faction** row on enemies, sentries and Guard Dogs: which side a unit fights for.
- Faction-wide **weapon spread (x)** and **flinch from your fire (x)**, to change how accurate bots
  and squids are.
- **Bleed-out**: how fast the bleed-out health runs out, and the drain on each body part.
- Grounded Warp Ship, Warp Ship (invasion), Warp Gateway and Infested Tower pages.
- The Hulk's death explosion is named, and the Automatons' large and huge vehicle deaths have
  sections of their own.

**Presets**

- **Global presets**: one preset holds every change at once — game parameters, enemy parameters,
  demolition, save loadout and preload — and loading it replaces them all.
- Each preset is one file in the `Presets` folder beside the executable, named after it. Copy a file
  into someone else's folder to share it; copy the folder to back up.
- Groups are the folder's subfolders: switch with the arrows, **Group** moves a preset, **New group**
  makes one.
- A description on every preset, shared with its file; `#`, Chinese and line breaks allowed.
- **Saved changes** lists what a preset holds, by page: a `*` and a count on each page that changed,
  original value to preset value on each row. Reading it does not load the preset.
- Built-in example presets: Horde, Glass Cannon and Elite. **Restore built-in presets** in Settings
  puts them back; your own presets stay.
- Old presets import once as partial presets: loading one merges only what it holds.

**Panel**

- **Health and demolition**: health, demolition, drowning, shields, contact damage and faction share
  one page, a tab each.
- **Entity components**: equipment and interactables (58 and 327 fields) join the weapon components,
  targeting joins AI settings, and every serialized record has a page, whether or not a hash names it.
- Search: the **\*** button shows only what you changed, from every tab, names and descriptions
  included.
- "Changes since the last install" counts a change only when the bytes or a saved value really
  differ.
- Tips wrap by the width of their translation.
- **Start the game** and **Close the game** in the footer: Steam starts it; closing ends
  `helldivers2.exe`, and asks for a second click within 4 seconds.
- **Clear all changes** in Settings (the old Reset all values, now one button with the cache
  switch on its row) drops what the editor keeps between runs — values, passive stacks, preloads,
  demolition, loadout edits, names and descriptions — without touching the presets or the game's
  files; **Clear the cache on close** does it at every close (off: kept, as before).
- The window title shows this fork's version **0.0.8 Reorganized by Thodmc** and when it was
  packed; the panel's own number stays 4.5.1, following upstream `dev 4794aee`.

**Fixes**

- A value of `FFFFFFFF` (none/-1) no longer stops the diff with `bad argument #1 to 'abs'`.
- Read-only game files can be replaced again; a failure says whether the file was denied or in use,
  and the previous files come back.
- After swapping a projectile, an attachment's **Reset** used the wrong baseline.
- Holding Backspace in a name, description or preset description deletes faster.

Vehicle, exosuit, animation, name and description changes go into one extra file in the game's data
folder. Restore removes it.

The game's archives are read directly, as preload and Unit cloning already were: Filediver is
optional now, and the names, the physics files and the state machines are found by the archive index
instead of a fixed list.

---

**发布**：0.0.8「Thodmc Reorganized」· build 20261030-031645。

**名称与描述**：武器、投掷物与战备页底部的名称与描述框。输入自己的文本，点“写入游戏”后以所有语言进入游戏；按 R 恢复游戏原文。

**绝地潜兵**

- **近战与刺刀**打击：整条伤害记录——伤害、耐久伤害、各角度穿甲、拆毁、硬直与击退、元素与状态效果。
- **头部命中**：头部中弹对生命值的伤害，默认 1.5。
- **武器晃动 (x)**：一次调整你亲手瞄准的所有武器的晃动，含固定炮台与载具武器；在武器自己的页面单独改过晃动的保留原值，并显示为蓝色。
- **压制**：敌方火力需掠过多近才会干扰你的瞄准、可累积的上限，以及擦身而过是否计入。

**武器**

- **无限弹药**：每把枪、哨戒炮与载具武器的开关。
- **喷射**：火焰喷射器的预热、引火熄灭、命中半径、每喷弹药与引爆地雷。
- **锁定距离**：Spear、WASP、Warrant 与导弹手枪。
- **瞄准放大**：带固定瞄具的枪，如 Constitution；三级一起缩放。
- **收枪位置**：主武器收于背部，或手枪所在的胯部。节点哈希、3 个旋转与 3 个偏移列在旁边，共用同一个值。
- **刺刀**：Constitution、Sweeper、Amendment 的刺刀近战行。它们共用同一份记录，改一次同时生效。
- Punisher、Slugger、Cookout、Halt 显示两根 8 发弹管，可分别编辑。
- **磁轨炮**：过载不爆炸的开关。
- **火花**：Pyrotech 火花的伤害与状态效果。
- 支援武器：**拾取到**行，拾取时放入主武器栏。
- **锥角**：游戏设有锥角的爆炸均可设置——武器、背包、地雷、投掷物、战备与死亡爆炸。
- 不产生备弹的枪不再显示备弹行。
- 只有单一射速的枪只显示一行射速，并标出游戏默认值。

**战备**

- **战备编辑**：军械库新增的子页，含战备与机甲两个分页。
- **每次投放**：新增地狱舱段，一个舱可投下两件武器或背包；设为 2 即在舱的另一侧再放一件。
- **投弹模式**：飞鹰一次投下的炸弹数，以及每种模式给出的数量。**投弹间隔（秒）**设定彼此的间隔。
- **哨戒炮瞄准**：上、下、左、右可转角度，以及它所属的**阵营**。
- **部署时长**：护盾发生器中继。
- **背包弹药**：上限 1023（游戏上限），并说明原因。

**载具与机甲**

- **载具操控**：三台 FRV 与两台坦克的重量、重心高度与前后/左右位置、引擎扭矩、最高引擎转速、挡位、前后刹车强度，以及车轮的抓地、半径、弹簧刚度、阻尼与悬挂行程。
- **机甲移动**：行走、转身、跺脚、上下机、落地与硬直恢复速度，以及机甲播放的其他动作速度。
- 每行都说明改动的影响：更重意味着什么、传动比更低会怎样、弹簧更软会怎样。

**记录**：每个实体与每个 TypeID 序号现在各自命名，`EntityNames` 按分组、`TypeIdNames` 按类型各存一个文件，并可用 ID 输入框直接跳转。旧命名文件会导入一次。

**护甲**：只以头盔命名的 O-44 Bonded Pilot 等 7 件护甲补上了名称。

**敌人编辑器**

- **动画速度**：每个敌人单独设置**攻击动画速度**与**硬直恢复速度**；攻击动画越快，攻击出手越早；全阵营页同样可设置。
- **各行为移动速度**：待机、巡逻、搜索、战斗、横移、漂移、撤退与冲锋。
- **压制**：你的射击需落多近才算数、火力对其瞄准的干扰强度、停火后瞄准保持混乱多久（或“从不”）。
- **丢失视野后的追踪 (x)**：敌人继续追你的时长，1 至 20。
- **阵营**：敌人、哨戒炮与护卫犬的所属阵营。
- 阵营全局**武器散布 (x)** 与**受你火力惊扰 (x)**，改变机器人/光能者的命中率。
- **失血**：失血生命值耗尽的速度，以及各部位的流失速度。
- 着陆穿梭舰、穿梭舰（入侵）、传送门、侵染塔巢页。
- 浩克的死亡爆炸已命名，机器人大型与巨型载具的死亡爆炸另有分页。

**预设**

- **全局预设**：一个预设一次保存全部修改——游戏参数、敌人参数、拆毁、存档配装与预载方案，载入时整体替换。
- 每个预设是 exe 旁 `Presets` 文件夹里的一个文件，以预设名命名。把文件复制进别人的文件夹即可分享；复制整个文件夹即备份。
- 分组就是文件夹的子目录：用箭头切换，**分组**移动选中的预设，**新建分组**创建。
- 每个预设可写描述，随文件一起分享；支持 `#`、中文与换行。
- **已保存内容**按页面列出预设包含的改动：有改动的页面显示 `*` 与数量，参数逐项显示“原始值 → 预设值”。查看不会载入预设。
- 内置示例预设：Horde、Glass Cannon、Elite。设置里的**恢复内置预设**可找回，你自己的预设不受影响。
- 旧预设导入一次，作为“部分方案”：载入时只合并它记录的内容。

**面板**

- 删除杂项与预载里的“修改器设置”分页；字体大小和界面分辨率移到右下角“设置”，保留直接输入、增减、重置与自动分辨率。
- **生命与拆毁**：生命、拆毁、溺水、护盾、接触伤害与阵营合并为一页，各占一个分页。
- **实体组件**：新增装备与交互组件（58 与 327 个字段），瞄准组件进入 AI 设置；每条序列化记录都有自己的页面，无论是否有哈希指向它。
- 搜索：**\*** 按钮只显示改动项，覆盖所有页面，含名称与描述。
- “自上次写入以来的改动”仅在字节或保存值真的变化时计数。
- 悬停提示按译文宽度换行。
- 底部的**启动游戏**与**关闭游戏进程**：Steam 启动；关闭会结束 `helldivers2.exe`，需在 4 秒内再点一次确认。
- 设置里的**清除所有修改**（原“重置全部数值”，现在与“关闭时清除”开关同一行）：丢掉编辑器跨启动保存的改动（数值、被动堆叠、预载、拆毁、装备栏、名称与描述），不动预设、不动游戏文件；**每次关闭后清除修改器缓存**开关开启后，每次关闭都自动清除（默认关：和以前一样保留）。
- 窗口标题显示本 fork 的版本 **0.0.8 Reorganized by Thodmc** 与打包时间；面板内部版本仍是 4.5.1，跟随上游 `dev 4794aee`。

**修复**

- 恢复游戏原始文件成功后立即重读游戏数据并重建页面，清除旧的待写入改动；例如生命读数由 99999 更新为 125，无需重启修改器。恢复失败时保留当前编辑状态。
- 开启关闭时清缓存后，重启会从已写入的游戏文件读回数值（例如生命 99999），不会只显示原始备份的 125；未写入改动仍会丢弃，原始重置值保留。
- 值为 `FFFFFFFF`（none/-1）时不再以 `bad argument #1 to 'abs'` 中断比较。
- 只读游戏文件可以替换；失败时会说明是被拒绝还是被占用，并恢复原文件。
- 换过射弹后，附件“重置”使用了错误的基准值。
- 名称、描述或预设描述框里按住退格删除得更快。

载具、机甲、动画、名称与描述的改动写入游戏数据目录中的一个额外文件；“恢复游戏原始文件”删除它。

游戏数据包由编辑器直接读取，预载与 Unit 克隆原本就是这样：Filediver 现在是可选项，名称、物理文件与状态机改为按归档索引查找，不再依赖固定列表。
