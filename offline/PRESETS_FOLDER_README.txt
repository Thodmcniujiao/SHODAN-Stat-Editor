SHODAN Stat Editor — 全局预设文件夹 / Global presets folder

每个预设是这里的一个文件，以预设名命名（例如 Horde.json、精英.json），文件内保存文字描述。
子文件夹就是预设分组，支持中文和多级目录；在编辑器中也可以新建分组、移动预设、编辑描述。
手工整理文件夹后重新打开编辑器；backup 保留为旧格式备份，不列为分组。
左侧数字统计实际改动数，右下角另列快照记录数；未改动的配装字段和默认预载目标不计为修改。
“返回编辑”位于金色工作区框外。右侧默认收起全部主页，展开后只显示有改动的子页与参数，金色 * 表示改动；双击描述框编辑说明。
preset_index.json 记录预设编号和已导入的旧预设，请勿删除；backup 文件夹里是转换前的旧格式文件。
每个预设一次保存全部修改：游戏参数、敌人参数（含敌人生成与全局倍率）、拆毁修改、存档配装和预载方案。
载入预设只暂存修改；写入游戏文件或存档仍需点击对应的写入按钮。
分享：把某个预设文件复制到别人的 Presets 文件夹，重新打开编辑器即可看到（编号冲突会自动换新编号）。
备份：复制整个 Presets 文件夹。新版本会自动带上上一次使用的预设。
编辑器中：底部“预设” → “打开预设文件夹”。

Each preset is one file here, named after it (Horde.json, ...). preset_index.json keeps the ids and the import
markers: keep it. A preset holds every change at once: game and enemy parameters (spawning and global multipliers
included), demolition, equipment and the preload plan. Loading stages the changes; use the Write buttons to change
the game files or the save. Share a preset by copying its file into another Presets folder; back up by copying
the whole folder. A new build brings the presets of the one used last.

Subfolders are preset groups. Descriptions travel with each preset file. Create groups, move presets and edit descriptions in the editor. Restart after organizing folders externally. Saved parameter previews follow the editor pages; * marks changed values.
