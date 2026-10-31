# 使用与参考文档

启动与目录说明见程序根目录的 `README.txt`。这里按用途列出详细文档，组件说明和核查记录集中保存在本文件夹。

## 常用功能

- [便携数据目录、参数收藏与名称、更新与旧数据迁移](PORTABLE_DATA.md)
- [预设、分组与描述](PRESETS.md)
- [人物数据与角色语音](PLAYER_DATA.md)
- [生物设置、AI与生物组件](ENEMY_DATA.md)
- [刷怪编辑器](SPAWN_EDITOR.md)
- [存档与配装编辑](PLAYER_SAVE.md)
- [任务与星球设置](PLANET_SETTINGS.md)
- [指定星球添加词条、独立图标与实际效果定义、可选网络接入](PLANET_EFFECT_IDS.md)
- [预载与资源包](PRELOAD_COMPONENTS.md)
- [修饰符与挂载](MODIFIER_ATTACHMENTS.md)

## 组件参数参考

- [实体组件总览](ENTITY_COMPONENTS.md)
- [实体拆毁](ENTITY_DEMOLITION.md)
- [战备与载具](STRATAGEM_COMPONENTS.md)
- [轨道武器](ORBITAL_WEAPON_COMPONENTS.md)
- [轰炸组件](BOMBARDMENT_COMPONENTS.md)
- [伤害](DAMAGE_COMPONENTS.md)
- [射弹](PROJECTILE_COMPONENTS.md)
- [爆炸](EXPLOSION_COMPONENTS.md)
- [电弧](ARC_COMPONENTS.md)
- [激光](BEAM_COMPONENTS.md)
- [已命名参数](NAMED_PARAMETERS.md)

## 策划名与数据格式

实际可编辑的 JSON 在程序根目录 `Names/EntityNames`、`Names/TypeIdNames` 中。

- [实体哈希分组与策划名](ENTITY_CATALOG_API.md)
- [TypeId 名称表](RECORD_NAMES.md)
- [实体目录 JSON Schema](ENTITY_CATALOG_SCHEMA.json)
- [引用与导航](REFERENCE_NAVIGATION.md)

## 字段来源与版本核查

- [启动性能与按需加载](STARTUP_PERFORMANCE.md)
- [未知字段补名、来源与确认方式](COMPONENT_FIELD_NAMES.md)
- [生物组件及其余组件入口核查](CREATURE_COMPONENT_AUDIT.md)
- [上游版本移植说明](UPSTREAM_4.5.1_PORT.md)

许可文件位于程序根目录的 `licenses` 文件夹。程序运行文件保存在 `app` 和根目录 DLL 中；文档目录用于查阅。
