# 组件解析生成器

由游戏类型库与 RawData dump 生成 `offline/weapon_components.lua`（武器类组件的完整字段表）。

1. 克隆 https://github.com/Darctor/Helldivers2_RawData 到本目录的 `Helldivers2_RawData`（或用环境变量 `RAWDATA` 指定），
   克隆 https://github.com/shalzuth/HelldiversData 到本目录的 `HelldiversData`（或用环境变量 `SHALZUTH` 指定）。
2. 解密游戏文件到 `work/`（或用环境变量 `COMPONENT_GEN_WORK` 指定）：

   ```
   python unseal.py ../../offline/gamedata.lua "<游戏目录>/data/game/dl_library.dl_typelib" work/typelib.bin
   python unseal.py ../../offline/gamedata.lua "<游戏目录>/data/game/generated_entities.dl_bin" work/entities.bin
   ```
   需要 `numpy` 与 `cryptography`。
3. `python gen.py`：逐层展开类型库中每个组件的记录，与 dump 的字段按全部实体的数值对齐取名（偏移变化后仍能对上），中文标签来自 `zh.py` 的词表，结果写入 `offline/weapon_components.lua`。
   dump 里没有名字的字段，再用 `shal.py` 从 2024 年的组件结构（shalzuth/HelldiversData）补名：结构名的哈希即类型哈希，
   成员按类型顺序（LCS）与当前类型库配对；整结构逐成员一致的标“结构一致”，否则标“按顺序推断”，与已有名字重复的不采用。
   两边名字相同的字段附上 2024 年的英文说明。公开资料都没有名字的字段（制导武器、屏幕、架设武器）在 `gen.py` 的 `OVERRIDE`
   里按各实体所用的数值写标签与说明，并注明是推断。

`walk.py` 展开结构，`align.py` 做数值对齐，`build_names.py` 合并字段名，`shal.py` 读取 2024 年结构，`zh.py` 是词表（新增词在此补充）。

`python -X utf8 gen.py --orbital` 使用相同的类型库、实体和参考数据生成 `offline/orbital_components.lua`。轨道字段分为持续时间与追踪、伤害区域、射弹生成、特效与音效、阵营过滤、移动轨迹、56 个二维控制点七组；四项既有参数保留 `beam_*` 保存 ID。该模式不会改写 `weapon_components.lua`。
