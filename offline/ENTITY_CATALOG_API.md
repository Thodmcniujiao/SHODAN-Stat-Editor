# 实体分类与命名 JSON 接口

生命、实体拆毁使用同一套原生界面和同一份完整实体目录。切换子页保留实体选择、分类和搜索。目录从所有已解析的 ECS 组件映射合并，并保留原拆毁功能的独立场景 Unit；当前数据共 3465 项。

默认勾选“显示无本组件的实体”。没有本页组件或拆毁映射的实体名称为灰色，选中后显示原因，不会伪造或创建组件。取消勾选后仅显示具有对应组件/配置的实体。配置存在但没有安全可编辑字段的实体会说明原因。

## 文件与操作

- 配置：`%LOCALAPPDATA%\SHODAN\StatEditor\entity_catalog.json`。
- 全量实体索引：同目录 `entity_catalog.index.json`，由编辑器生成，供外部工具查询哈希、名称、资源路径、分类及组件是否存在。
- 格式定义：发布目录的 `ENTITY_CATALOG_SCHEMA.json`。
- 原始模板：程序 `app/entity_catalog.default.json`。仅在配置不存在时复制，不覆盖已有自定义。

左侧分类框可以下拉选择，也能用左右按钮切换。“打开分类JSON”打开实际使用的文件。外部程序修改该文件后，点击“重载JSON”立即应用；不用重启。无效 JSON 或未定义分类会显示错误，保留最后一次有效的分类和名称，不改动组件数值。

## 格式 version 1

```json
{
  "version": 1,
  "default_category": "other",
  "categories": [
    {"id":"terminids", "name":{"en":"Terminids","zh-Hans":"虫族"}, "order":10},
    {"id":"other", "name":{"en":"Other","zh-Hans":"其他"}, "order":100}
  ],
  "rules": [
    {"category":"terminids", "path_prefix":"content/fac_bugs/"}
  ],
  "entities": {
    "F79CD8BB654397DF": {
      "name":{"en":"My Alpha Commander","zh-Hans":"我的阿尔法指挥官"},
      "category":"terminids"
    }
  }
}
```

名称可以是普通字符串，也可以是语言映射；编辑器优先取当前语言，随后取 `en`、`zh-Hans` 或提供的其他语言。分类按 `order`、再按 `id` 排序，分类内部按名称排序。`all` 为界面的保留分类，不可作为自定义分类 ID。

`entities` 使用 16 位十六进制哈希，支持 `0x` 前缀；也可以使用索引中的完整 ID：`E` + 哈希表示 ECS 实体，`U` + 哈希表示独立场景 Unit。存在同哈希的不同资源范围时，用完整 ID 精确指定。该配置只改变组件目录中的显示名称与分类，不修改游戏资源名、哈希、原敌人页面名称或数值存储 ID。

## 分类优先级与规则

分类优先级：实体条目的 `category` → 第一条匹配的 `rules` → 原目录已知阵营 → `default_category`。实体条目可以只提供名称，分类继续由规则决定。实体条目的名称优先于编辑器默认名称。

每条规则必须有 `category`；可选条件全部满足才匹配：

| 条件 | 含义 |
| --- | --- |
| `path_prefix` | 资源路径前缀，使用 `/` |
| `path_contains` | 资源路径包含文字 |
| `name_contains` | 默认名称包含文字 |
| `hash_prefix` | 十六进制哈希前缀 |
| `kind` | `entity` 或 `unit` |
| `component` | ECS 类型名，例如 `HealthComponentData`，大小写须准确 |

路径、名称和哈希文字匹配不区分大小写；这些是普通文本匹配，不执行正则或 Lua。可以通过外部脚本生成大量 `entities` 条目进行批量重命名、重新分类。JSON 只作为数据读取，不执行代码。

## 全量索引

`entity_catalog.index.json` 的根对象包含 `version` 和 `entities` 数组。每项包括 `id`、`hash`、`kind`、`name`、`path`、`category`、`components`（ECS 组件类型哈希数组）、`health`、`demolition`、`drown`、`shield`、`throwable`、`thrower`、`minefield`、`mine_spawner`、`faction`、`mount`、`inventory`、`sensor_eye`、`turret` 以及每个武器类组件（键名同 `weapon_components.lua` 中的 KEY，如 `weapon_data`、`projectile_weapon`）的布尔值（`drown`：拥有 DrownableComponentData；`shield`：ShieldComponentData；`throwable`：ThrowableComponentData；`thrower`：ThrowerComponentData；`minefield`：MinefieldComponentData；`mine_spawner`：MineSpawnerComponentData；`faction`：FactionComponentData；`mount`：MountComponentData；`inventory`：InventoryComponentData；`sensor_eye`：SensorEyeComponentData；`turret`：TurretComponentData）。`demolition` 表示存在相应破坏配置，并不保证每个记录都有可编辑阈值。

索引由编辑器生成，请修改配置文件而不是索引。界面分类、名称和“显示无本组件实体”均不会改变实体实际拥有的组件。生命和拆毁仍分别复用原来的字段及统一覆盖设置；原敌人、炮台页面继续同步。
