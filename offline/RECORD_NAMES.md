# 记录 ID 与外部策划名

轨道编辑、飞鹰编辑以各自组件表的 **ComponentIndexData.index（从 0 开始的记录索引）** 为编号和检索键，按 `#0、#1、#2…` 排列。它们不是 `StratagemTypeID`，也不是实体哈希。

列表直接遍历完整组件记录数组，同一记录对应多个实体哈希时只列一次，没有实体哈希或关联战备的记录也会列出。右侧保留已有组件参数和关联的战备参数，并显示当前组件记录索引。游戏更新可能重排记录，应以当前游戏表为准。

- 轨道编辑：`BombardmentComponentData` 的记录索引。当前版本 24 条（0–23）。
- 飞鹰编辑：`EagleComponentData` 的记录索引。当前版本 12 条（0–11）。
- 轨道武器编辑：按用户要求保持 `OrbitalAbilityComponentData` 实体列表不变，仍使用 EntityHash。
- 游戏数据：战备、伤害、射弹、爆炸、电弧、激光、状态效果各自使用原来的枚举行 ID。

组件记录索引由当前数组布局和 ComponentIndexData 映射确定，不根据名称、战备 ID 或哈希排序临时编号。

| 位置 | 用途 |
| --- | --- |
| 列表上方输入框 | 按组件记录索引直接跳转；支持十进制或 `0x` 十六进制 |
| 列表下方搜索框 | 搜索当前列表中的名称、记录索引和外部“策划名” |
| 上方“重载”按钮 | 修改外部名称文件后重新读取 |

## 外部名称文件

两个文件都可以用，先读 JSON 再读 TXT，TXT 最后覆盖：

- `%LOCALAPPDATA%\SHODAN\StatEditor\record_names.json`
- `%LOCALAPPDATA%\SHODAN\StatEditor\record_names.txt`

### JSON

嵌套格式（推荐）：

```json
{
  "version": 1,
  "types": {
    "projectile": {
      "282": "轨道炮射弹",
      "355": "另一条射弹"
    },
    "damage": {
      "123": "主武器伤害"
    },
    "stratagem": {
      "110": "轨道激光（以当前游戏枚举为准）"
    },
    "bombardment": {
      "19": "轨道120mm高爆弹火力网"
    },
    "eagle": {
      "1": "飞鹰空袭"
    },
    "orbital": {
      "AC129AA2DB5EABC9": "轨道炮攻击"
    }
  }
}
```

也支持平铺键：

```json
{
  "projectile:282": "轨道炮射弹",
  "damage:123": "主武器伤害"
}
```

或记录数组：

```json
{
  "records": [
    { "type": "projectile", "id": 282, "name": "轨道炮射弹" }
  ]
}
```

### TXT

每行 `类型 id 策划名`；类型和 id 之间可用空格或制表符，名称取该行剩余部分。`#` 开头为注释：

```text
# type id name
projectile 282 轨道炮射弹
damage 123 主武器伤害
stratagem 110 轨道激光（以当前游戏枚举为准）
bombardment 19 轨道120mm高爆弹火力网
eagle 1 飞鹰空袭
orbital AC129AA2DB5EABC9 轨道炮攻击
```

## 类型名

| 类型 | 别名 | 页面 |
| --- | --- | --- |
| `damage` | `damage_type`, `dmg` | 游戏数据 → 伤害id修改 |
| `projectile` | `projectile_type`, `proj` | 游戏数据 → 射弹id修改 |
| `explosion` | `explosion_type`, `expl` | 游戏数据 → 爆炸id修改 |
| `arc` | `arc_type` | 游戏数据 → 电弧id修改 |
| `beam` | `beam_type`, `laser` | 游戏数据 → 激光id修改 |
| `status` | `status_effect`, `status_effect_type` | 游戏数据 → 状态效果id |
| `stratagem` | `stratagem_type`, `strat` | 游戏数据 → 战备id |
| `bombardment` | `bombard`, `orbital_bombardment` | 轨道编辑（轰炸组件记录索引） |
| `eagle` | `eagle_type` | 飞鹰编辑（飞鹰组件记录索引） |
| `orbital` | `orbital_ability`, `orbital_weapon` | 轨道飞鹰 → 轨道武器编辑 |

## ID 和旧名称兼容

轨道、飞鹰使用 `bombardment <记录索引> <名称>`、`eagle <记录索引> <名称>`。例如当前版本 `bombardment 19` 是 120mm 轰炸组件；此数字不是它的战备枚举行 ID。记录索引随版本可能变化。

旧 `bombardment` / `eagle` 文件中的组件 EntityHash 名称仍可作为回退名称；同时存在时，记录索引名称优先。哈希仅用于关联实体和兼容名称，不作为这两个页面的主检索键。

伤害、射弹、爆炸、电弧、激光、状态、战备仍使用各自 32 位枚举行 ID。战备名称使用 `stratagem` 条目，和轨道/飞鹰的组件记录索引名称独立。

轨道武器（OrbitalAbility）的 `orbital` 名称条目和哈希跳转保持原样。

名称只影响显示和搜索，不会修改游戏数据。名称文件中额外的 ID 不会虚构出新记录。
