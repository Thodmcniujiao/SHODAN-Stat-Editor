SHODAN Stat Editor Offline v{version} — Thodmcniujiao fork
源码与发布：https://github.com/Thodmcniujiao/SHODAN-Stat-Editor

使用方法
1. 将整个文件夹解压到可写目录，保留 exe、DLL 和 app 文件夹的相对位置。
2. 关闭 Helldivers 2，启动 SHODAN Stat Editor Offline.exe。
3. 编辑参数后点击“写入游戏”。点击“恢复游戏原始文件”成功后，会清除待写入改动并自动重载页面数值，无需重启修改器。
4. 预设保存在 exe 旁边的 Presets 文件夹（备份或分享时复制它）；策划名配置在 exe 旁边的 Names 文件夹（EntityNames / TypeIdNames，随包分发，改完点“重载JSON”）；用户配置、日志和游戏原始备份保存在 %LOCALAPPDATA%\SHODAN\StatEditor。
5. 窗口标题中的 build 标记对应本次打包；本 fork 已关闭自动更新。
6. 底部“预设”进入全局预设：每个预设一次保存所有修改（游戏参数、敌人参数、拆毁、存档配装、预载方案），可从那里打开预设文件夹；旧预设自动导入。详情见 docs\PRESETS.md。
7. 字体大小和界面分辨率在右下角“设置”的语言选项下方调整，支持直接输入、增减、字体重置和自动分辨率，并保存到用户配置。
8. “每次关闭后清除修改器缓存”丢弃未写入的数值改动；重启后从当前已写入的游戏文件恢复数值读数。原始备份仍用于重置与恢复，不会因清缓存而写回游戏。

目录说明
- SHODAN Stat Editor Offline.exe：启动程序。
- app 与 DLL：程序运行文件，保持原位置。
- Presets：个人预设。
- Names：实体与 TypeId 策划名 JSON。
- docs：所有详细文档与格式参考，从 docs\README.md 的中文目录查阅。
- licenses：本程序及第三方许可。

这是纯净便携包，不包含个人配置、预设、游戏数据、游戏备份、测试产物或开发缓存。
随包的组件说明文档列出解析范围、字段来源及限制。源码在仓库 dev 分支；发布标签指向对应源码提交。

English
Extract the complete folder, keeping the executable, DLLs and app directory together.
Close Helldivers 2, run the editor, edit values, and click Install into the game.
Restore the game's files reverts installed changes. Presets live in the Presets folder beside
the executable (one global preset holds every change). Planning names live in the Names folder
beside the executable (EntityNames / TypeIdNames, shipped with the package). Settings, logs and
original backups are stored in %LOCALAPPDATA%\SHODAN\StatEditor. Automatic updates are disabled in this fork.
This clean portable package contains no personal settings, saved presets, game files, backups,
test output or development caches. Its release tag identifies the matching source on dev.
Detailed guides and component references are in docs; start with docs/README.md.
Licences and third-party notices are in licenses.

数据来源 / Data sources
组件字段名、类型与偏移来自 Darctor/Helldivers2_RawData（https://github.com/Darctor/Helldivers2_RawData），
缺失字段名与英文说明来自 shalzuth/HelldiversData。生成文件头部与随包文档标注来源。
Component names, types and offsets come from Darctor/Helldivers2_RawData
(https://github.com/Darctor/Helldivers2_RawData); missing field names and English descriptions
come from shalzuth/HelldiversData. Generated files and the bundled docs carry this credit.

Licences
SHODAN Stat Editor: GPL-3.0; see licenses/LICENSE and the source repository.
LuaJIT and libsodium notices: licenses/THIRD-PARTY-NOTICES.txt.
Reference-name data: licenses/REFERENCE_NAMES_LICENSE.txt.
