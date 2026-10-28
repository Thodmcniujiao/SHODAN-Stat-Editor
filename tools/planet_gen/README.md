# 星球设置字段名生成器

重新生成 `offline/planet_data.lua` 中星球设置各类型成员的名称、名称来源、中文标签和星球显示名。

## 输入

- `planet_data.base.lua`：各星球设置类型的完整布局（来自游戏类型库）以及旧版按成员顺序推断的名称，是本工具的输入。
- 解密后的游戏设置文件（`generated_planet_data.dl_bin` 等），放在 `../component_gen/work/`，或用环境变量 `COMPONENT_GEN_WORK` 指定。解密方法见 `../component_gen/README.md`。
- https://github.com/shalzuth/HelldiversData（2025-09 的 `data/settings/*.json`）：克隆到 `../component_gen/HelldiversData`，或用 `SHALZUTH` 指定。
- https://github.com/helldivers-2/json（星球英文名与繁体中文名）：克隆到本目录的 `json`，或用 `HD2JSON` 指定。
- https://github.com/BYVoid/OpenCC（只用 `data/dictionary` 里的繁简对照表）：克隆到本目录的 `OpenCC`，或用 `OPENCC` 指定。
- `warinfo_index.csv`：银河战争接口 `WarSeason/801/warinfo` 中每颗星球的编号和 settingsHash。settingsHash 等于星球 debug_name 的 64 位 murmur 哈希的高 32 位，据此把游戏里的星球记录对应到编号和名称。

## 运行

```
python gen.py
```

## 命名方法

1. 按 debug_name、id 等键（没有键时按数值相似度）把当前记录与 2025 年记录配对。
2. 对每个结构类型，比较当前每个成员与 2025 年每个字段在全部配对记录上的取值。
   - 不常见的取值也一致时，判为“按数值核对”（value）。
   - 各记录的值都相同、只能靠前后顺序定位时，判为 value-constant。
   - 再按声明顺序做最长公共子序列，保证字段顺序不交叉。
3. 两个已核对字段之间剩下的成员，按顺序和值的类型配对，判为“按顺序推断”（order）。
4. 2025 年数据里没有对应实例的类型，沿用旧版成员顺序推断的名称（legacy）。
5. 其余成员保持未知（none）。

每个成员的来源写在 `source` 字段，页面提示中会说明。枚举值的名字只在 2025 年数据中和数值一起出现过时才算确认，其余标“(?)”。
