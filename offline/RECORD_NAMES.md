# TypeID/index 策划名

TypeID/index 是某种类型表内的局部编号，可随游戏更新改变。不同类型即便编号相同，也分别命名、搜索和跳转。

编辑器数据目录中的 `TypeIdNames` 文件夹使用每种类型一个 JSON。点击列表上方“打开JSON文件夹”可直达实际目录；通常为 `%LOCALAPPDATA%\SHODAN\StatEditor\TypeIdNames`。

## 文件与格式

例如 `projectile.json`：

```json
{
  "version": 1,
  "type": "projectile",
  "names": {
    "282": "轨道炮射弹",
    "288": "另一条射弹"
  }
}
```

类型也可以由文件名确定。编号支持十进制和 `0x` 十六进制。编辑器会将当前实际表的记录列入对应 JSON；空名称使用原来的界面名称。可编辑这些值，然后点击“重载JSON”。错误文件不会替换已加载的有效名称。

JSON 中的编号按数值升序排列（`1、2、…10、11、…100`）。启动或重载时也会整理已有文件的顺序，保留名称内容。

| JSON / type | 列表及编号 |
| --- | --- |
| `damage.json` | 游戏数据：伤害 TypeID |
| `projectile.json` | 游戏数据：射弹 TypeID |
| `explosion.json` | 游戏数据：爆炸 TypeID |
| `arc.json` | 游戏数据：电弧 TypeID |
| `beam.json` | 游戏数据：激光 TypeID |
| `status.json` | 游戏数据：状态效果 TypeID |
| `stratagem.json` | 游戏数据：战备 StratagemTypeID |
| `bombardment.json` | 轨道编辑：Bombardment 组件数组 index，从 0 开始 |
| `eagle.json` | 飞鹰编辑：Eagle 组件数组 index，从 0 开始 |

## 搜索与跳转

上方输入框输入时自动跳转，支持十进制或 `0x` 十六进制；只在当前 TypeID 中精确匹配。下方搜索也仅匹配当前类型的原名、策划名和编号，不会出现其他 TypeID 的记录。

两个类型编号相同不会串名。轨道/飞鹰的上方输入框只接受各自组件数组索引，不会把背后的实体哈希或关联战备编号当作索引。

轨道武器编辑使用 EntityHash，名称归入 `EntityNames` 全局实体分组；其上下框支持精确的十进制、十六进制哈希。参见 `ENTITY_CATALOG_API.md`。

## 旧文件迁移

首次创建文件夹时导入旧 `record_names.json` 与 `record_names.txt`，支持原有类型别名。旧文件保持原样；之后修改新文件夹中的 JSON。旧长实体哈希名称导入 `EntityNames`，不再作为局部 index 的命名或跳转后备键。

名称只影响显示和搜索，不会改变当前游戏表的编号、参数或存档，也不会凭空添加记录。游戏更新后新增的记录会补入对应 JSON，已有策划名保留；局部编号的实际含义以当前游戏表为准。
