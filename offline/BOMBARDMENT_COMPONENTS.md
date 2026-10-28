# 轰炸 ID 的组件参数

位置：**轨道飞鹰 → 轨道编辑 → 轰炸类型（BombardmentType）**。组件标题使用高一级样式，与 StratagemType 一致；参数组样式保持原样。

轰炸组件属于战备投放的载荷实体，`EntityHash` 是这个实体的 64 位标识，
不是左侧战备名称后的战备编号，也不是射弹编号。界面按无符号十进制完整显示它，作为只读标识。
多个战备使用同一轰炸记录时，修改会共同生效。

以下偏移相对于当前游戏的 **192 字节 BombardmentComponent 记录起点**。
编辑器核对游戏类型库的字段位置、长度和存储类型后，才启用全部 28 个数值；
类型库不可用或布局不符时，保留原先已接入的 6 个参数，其余保持占位。

| 字段 | 偏移 | 类型 | 含义 |
|---|---:|---|---|
| EntityHash | 记录外的索引键 | u64 | 载荷实体标识，完整显示，不作浮点数转换 |
| InitialDelay | 0 | f32 | 首枚炮弹发射前的延迟，秒；支持负数，保留 `-5` 这类配置值 |
| NumberOfBombs | 4 | u32 | 每轮齐射的炮弹数 |
| BombInterval | 8 | f32 | 同一轮内相邻炮弹的发射间隔，秒 |
| BombIntervalRandomOffset | 12 | f32 | 炮弹发射间隔的随机偏移，秒 |
| WanderOffsetRadiusMin | 16 | f32 | 同一轮中，相对上一枚炮弹落点的最小游走距离，米 |
| WanderOffsetRadiusMax | 20 | f32 | 相对上一枚炮弹落点的最大游走距离，米 |
| NumberOfSalvos | 24 | u32 | 齐射轮数 |
| SalvoInterval | 28 | f32 | 两轮齐射之间的间隔，秒 |
| SalvoIntervalRandomOffset | 32 | f32 | 齐射间隔的随机偏移，秒 |
| AreaSize | 36 | f32 | 每枚炮弹落点额外施加的随机散布范围，米；不改变游走路径 |
| WanderStartAreaRadius | 40 | f32 | 开始轰炸时的初始游走偏移范围，米 |
| FireFromHeight | 44 | f32 | 炮弹的固定发射高度，米 |
| FireFromShip | 60 | byte / bool | 1：从舰船位置发射；0：从目标上方发射；仅写入一个字节 |
| FiringAngleOffsetX | 48 | f32 | 发射方向偏移向量的 X 分量 |
| FiringAngleOffsetY | 52 | f32 | 发射方向偏移向量的 Y 分量 |
| FiringAngleOffsetZ | 56 | f32 | 发射方向偏移向量的 Z 分量 |
| ProjectileID1 | 64 | u32 / enum | 射弹序列第 1 槽 |
| ProjectileID2 | 68 | u32 / enum | 射弹序列第 2 槽 |
| ProjectileID3 | 72 | u32 / enum | 射弹序列第 3 槽 |
| ProjectileID4 | 76 | u32 / enum | 射弹序列第 4 槽 |
| ProjectileID5 | 80 | u32 / enum | 射弹序列第 5 槽 |
| ProjectileID6 | 84 | u32 / enum | 射弹序列第 6 槽 |
| ProjectileID7 | 88 | u32 / enum | 射弹序列第 7 槽 |
| ProjectileID8 | 92 | u32 / enum | 射弹序列第 8 槽 |
| WalkSpeed | 96 | f32 | 行进轰炸的推进速度，米/秒 |
| StartDelay | 128 | f32 | 轰炸启动延迟，秒；与 InitialDelay 分开存储 |
| WalkAngleDegree | 132 | f32 | 相对前进方向的行进角度，顺时针，度 |
| WalkOffsetFraction | 136 | f32 | 行进路径在目标后方的比例；0.5 表示以生成位置为中心 |

8 个射弹槽是发射序列：指定多个射弹类型时，按模式重复，直到这一轮齐射结束。
它们不是独立的炮弹数量；0 表示无射弹类型。编辑时可以填当前版本存在的射弹 ID，
不存在的 ID 会被拒绝。方向偏移是向量分量，不把它们当作角度单位解释。

当前记录在 WalkSpeed 后还有截图未列出的其他字段，不能按截图的顺序连续推算偏移：
StartDelay 在 +128，WalkAngleDegree 在 +132，WalkOffsetFraction 在 +136。
本次不开放截图之外的其他字段。

图 2 的例子表示：每轮 23 发、发射间隔 0.1 秒、共 1 轮、散布范围 30 米；
前 7 个射弹槽是 149，第 8 槽是 223。`InitialDelay=-5` 会按负数保存；
负延迟在游戏运行时如何处理，需要实测，不能仅从配置推断成“提前 5 秒命中”。
这个例子只用于说明字段，不会自动覆盖其他战备的数值。

原有的 `barrage_shells`、`barrage_shell_gap`、`barrage_salvos`、`barrage_salvo_gap`、
`barrage_area`、`barrage_speed` 保存键保持兼容。新增字段沿用编辑器的输入、预设、重置和写入流程。

验证：`tests/test_orbital_bombardment.lua` 使用真实数据的解密副本和隔离配置目录，
检查 28 个字段的读取、逐字段字节范围、负数、单字节开关、8 个射弹槽、非法射弹拒绝、
配置/预设、重置后原始字节恢复，以及原生 GDI 界面绘制。测试不写入游戏文件。
