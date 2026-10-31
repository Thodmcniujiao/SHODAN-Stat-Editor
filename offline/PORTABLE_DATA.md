# 便携数据目录 / Portable data

离线版的所有用户数据均跟随程序文件夹，不再读取、写入或自动导入 AppData 中的修改器数据，也不依赖启动时的工作目录。

| 程序旁的目录 | 内容 |
|---|---|
| `Data` | 设置、待写入数值、日志、游戏路径、预载方案、拆毁覆盖、安装记录、游戏原始备份和存档备份 |
| `Presets` | 个人预设和预设分组 |
| `Names` | 实体与 TypeId 策划名 |

参数可右键“收藏 / 取消收藏”和“自定义名称”。每个组件顶部的“收藏”组与原位置共用参数值；同种组件的同一字段在不同实体和入口中共用收藏、名称。自定义名称可右键恢复默认，提示中保留原名称。这些仅影响修改器显示，不改写游戏文本。

记录即时保存在 `Data/parameter_preferences.json`，与待写入数值缓存分开。关闭后清缓存、重置参数、恢复游戏原版都保留收藏和名称；更新或移动软件时携带 `Data` 即可保留。文件按组件类型与字段相对位置识别参数，不依赖实体列表序号或内存地址。

存档写入前和恢复前的副本保存在 `Data/save-backups`，按 Steam 账号或独立文件分开。实际写入的游戏文件、Steam 存档及用于原子替换的短暂临时文件仍位于目标目录；临时文件在成功或可处理的失败后清理。

`Data` 在使用时创建。将整个程序文件夹解压到有写权限的位置；无法写入时不会回退到 AppData。开发源码直接运行时，数据目录位于 `offline/Data`。

## 更新和移动

在同一程序文件夹内覆盖更新程序文件即可保留数据。若解压到新文件夹，请在关闭编辑器后复制旧版的 `Data`、`Presets` 和自定义的 `Names`，或直接移动整个程序文件夹。两份全新解压的程序不会共享配置或自动导入对方的预设。

## 从旧版 AppData 手动迁移

1. 关闭新旧编辑器，备份旧版 `%LOCALAPPDATA%\SHODAN\StatEditor` 文件夹。
2. 在新程序旁创建 `Data`，把旧目录的**内容**完整复制进去。目标应为 `Data/config.txt`、`Data/originals`、`Data/installed.txt` 等，不能多套一层 `StatEditor`。
3. 将旧程序旁的 `Presets` 完整复制到新程序旁。旧版放在数据目录中的预设库及快捷槽，在复制到 `Data` 后会按原有格式迁移。
4. 如有自定义名称，也复制原来的 `Names`。启动新程序后核对游戏目录与预设。

已经写入过游戏的用户应同时保留 `originals`、`installed.txt`、资源补丁所有权记录及其他安装记录，以便继续识别和恢复之前的修改。不要只复制 `config.txt` 后丢弃原始备份。新程序不会自动修改或删除旧 AppData 目录。

本次旧配置迁移修复支持旧属性 ID 对应多个附件字段。删除旧 ID 使用独立操作，不再访问不存在的 `field`；迁移后保存新 ID，再次启动不会重复迁移。已安装数值的原版重置、浮点存储和共享字段去重逻辑保持有效。

## English

Offline settings, staged edits, logs, original game backups, save backups and installation records live in `Data` beside the program. Presets live in `Presets`; planning names live in `Names`. Paths follow the program folder, independently of the current working directory. No editor data is automatically read from or written to AppData, and there is no AppData fallback.

Right-click a parameter to favorite it or assign a custom display name. Each component has a Favorites group sharing the original values. The same component field shares these preferences across entities and views. Records are saved immediately in `Data/parameter_preferences.json`, survive cache clearing and game restore, and do not change game text. Keep `Data` when updating or moving the program.

Extract into a writable folder. To update in a new folder or move computers, close the editor and carry over `Data`, `Presets` and your customized `Names`, or move the entire program folder. Fresh copies remain independent.

To migrate an older installation, back up `%LOCALAPPDATA%\SHODAN\StatEditor`, then copy its **contents** into the new program's `Data` folder. Copy the old program's `Presets` too. Keep `originals`, `installed.txt`, asset ownership and other installation records together so previously installed changes can still be recognized and restored. The old AppData folder is left untouched.
