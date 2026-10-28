SHODAN Stat Editor Offline v{version} — Thodmcniujiao fork
源码与发布：https://github.com/Thodmcniujiao/SHODAN-Stat-Editor

使用方法
1. 将整个文件夹解压到可写目录，保留 exe、DLL 和 app 文件夹的相对位置。
2. 关闭 Helldivers 2，启动 SHODAN Stat Editor Offline.exe。
3. 编辑参数后点击“写入游戏”。需要恢复时点击“恢复游戏原始文件”。
4. 用户配置、预设、日志和游戏原始备份保存在 %LOCALAPPDATA%\SHODAN\StatEditor。
5. 窗口标题中的 build 标记对应本次打包；本 fork 已关闭自动更新。
6. 底部“预设”进入独立的命名预设编辑模式；旧预设自动导入。原来的 1–5 快捷槽已删除，详情见 PRESETS.md。

这是纯净便携包，不包含个人配置、预设、游戏数据、游戏备份、测试产物或开发缓存。
随包的组件说明文档列出解析范围、字段来源及限制。源码在仓库 dev 分支；发布标签指向对应源码提交。

English
Extract the complete folder, keeping the executable, DLLs and app directory together.
Close Helldivers 2, run the editor, edit values, and click Install into the game.
Restore the game's files reverts installed changes. User data and original backups are
stored in %LOCALAPPDATA%\SHODAN\StatEditor. Automatic updates are disabled in this fork.
This clean portable package contains no personal settings, presets, game files, backups,
test output or development caches. Its release tag identifies the matching source on dev.

Licences
SHODAN Stat Editor: GPL-3.0; see LICENSE and the source repository.
LuaJIT and libsodium notices: THIRD-PARTY-NOTICES.txt.
