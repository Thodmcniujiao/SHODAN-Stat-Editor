#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Build offline/Names from 交互式ID表.xlsx.

Policy (2026-10-30, full replacement from the new workbook):
  EntityNames   one entry per entity known to the editor; the 404 table names replace
                the current names, the other entities keep their current/base names.
  TypeIdNames   every ID in the workbook's per-type sheets is emitted; the name is the
                first named 主宽表 row that references it, otherwise "" (the editor then
                shows the game's own name).
  status        every status ID with the workbook's Name column.
  bombardment / eagle / stratagem
                no sheet in this workbook: the current JSON is carried over unchanged
                (those are component indexes, not tables of the workbook).

Outputs:
  offline/Names/EntityNames/*.json
  offline/Names/TypeIdNames/*.json
  offline/Names/MANIFEST.json
  offline/Names/README.txt
  exports/交互式ID表/REPORT.md
"""
import datetime as dt
import hashlib
import json
import os
import re
import shutil
from collections import OrderedDict, defaultdict, deque
from pathlib import Path

import openpyxl

ROOT = Path(__file__).resolve().parents[2]
XLSX = Path.home() / "Downloads" / "交互式ID表.xlsx"
APP = Path(os.environ.get("LOCALAPPDATA", str(Path.home() / "AppData" / "Local"))) / "SHODAN" / "StatEditor"
OUT = ROOT / "offline" / "Names"
REPORT = ROOT / "exports" / "交互式ID表" / "REPORT.md"
UNKNOWN = "未知哈希"

ENTITY_COLUMNS = ["实体哈希", "名称", "射弹ID", "射弹ID2", "射弹ID3", "电弧ID", "激光ID", "伤害ID", "爆炸ID", "生命", "拆毁等级", "搜索标签"]
# type -> 主宽表 columns (0-based over the 12 values)
REF_COLUMNS = {
    "projectile": [2, 3, 4],
    "arc": [5],
    "beam": [6],
    "damage": [7],
    "explosion": [8],
}
SHEET_IDS = {
    "damage": ("伤害ID", "DamageTypeID"),
    "projectile": ("射弹ID", "ProjectileTypeID"),
    "explosion": ("爆炸ID", "ExplosionTypeID"),
    "beam": ("激光ID", "BeamTypeID"),
    "arc": ("电弧ID", "ArcTypeID"),
    "status": ("状态效果ID", "StatusEffectTypeID"),
}
TYPES = ["projectile", "arc", "beam", "damage", "explosion", "status", "bombardment", "eagle", "stratagem"]


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def hex_from_decimal(text):
    value = int(str(text).strip())
    if value < 0 or value > 0xFFFFFFFFFFFFFFFF:
        raise ValueError("entity hash out of u64 range: %r" % text)
    return "%016X" % value


def config_hash_hex(raw):
    text = str(raw).strip().upper()
    if re.fullmatch(r"\d+", text):
        return hex_from_decimal(text)
    if text.startswith("0X"):
        text = text[2:]
    if not re.fullmatch(r"[0-9A-F]{1,16}", text):
        raise ValueError("invalid entity hash %r" % raw)
    return text.zfill(16)


def clean_name(name):
    if not isinstance(name, str):
        raise ValueError("name must be a string")
    name = re.sub(r"[\x00-\x1f]", "", name)
    if len(name) > 1024:
        raise ValueError("name longer than 1024 characters")
    return name


def dump_entity(data):
    return json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n"


def dump_type(type_name, names):
    ordered = OrderedDict()
    ordered["names"] = OrderedDict(sorted(((str(k), v) for k, v in names.items()), key=lambda kv: int(kv[0])))
    ordered["type"] = type_name
    ordered["version"] = 1
    return json.dumps(ordered, ensure_ascii=False, indent=2) + "\n"


def main():
    if not XLSX.is_file():
        raise SystemExit("missing workbook: %s" % XLSX)
    if not (APP / "EntityNames").is_dir() or not (APP / "TypeIdNames").is_dir():
        raise SystemExit("missing editor configs under %s" % APP)

    wb = openpyxl.load_workbook(XLSX, data_only=True)
    main = wb["主宽表"]
    headers = [main.cell(1, c).value for c in range(1, 13)]
    if headers != ENTITY_COLUMNS:
        raise SystemExit("unexpected 主宽表 header: %r" % (headers,))

    rows = []
    for r in range(2, main.max_row + 1):
        values = [main.cell(r, c).value for c in range(1, 13)]
        if all(v is None or (isinstance(v, str) and v.strip() == "") for v in values):
            continue
        name = str(values[1]).strip()
        if not name:
            raise SystemExit("row %d has no name" % r)
        rows.append(
            {
                "row": r,
                "hash": hex_from_decimal(values[0]),
                "name": name,
                "known": name != UNKNOWN,
                "ids": {t: [int(values[c]) for c in cols if values[c] is not None] for t, cols in REF_COLUMNS.items()},
            }
        )

    # ------------------------------------------------------------ EntityNames
    groups = []
    for path in sorted((APP / "EntityNames").glob("*.json")):
        data = json.loads(path.read_text(encoding="utf-8-sig"))
        if not isinstance(data.get("entities"), list):
            raise SystemExit("%s: entities must be an array" % path)
        groups.append({"name": path.name, "data": data})
    by_hash = {}
    for group in groups:
        for entry in group["data"]["entities"]:
            by_hash.setdefault(config_hash_hex(entry["hash"]), []).append(entry)

    entity_changes = []
    missing = []
    for row in rows:
        if not row["known"]:
            continue
        entries = by_hash.get(row["hash"], [])
        if not entries:
            missing.append(row)
            continue
        for entry in entries:
            old = entry["name"]
            if old != row["name"]:
                entity_changes.append({"row": row["row"], "hash": "0x" + row["hash"], "old": old, "new": row["name"]})
            entry["name"] = row["name"]
    if missing:
        raise SystemExit("table hashes missing from EntityNames: %r" % [r["hash"] for r in missing[:5]])

    control_fixed = 0
    for group in groups:
        for entry in group["data"]["entities"]:
            old = entry["name"]
            new = clean_name(old)
            if new != old:
                control_fixed += 1
                entry["name"] = new
    total_entities = sum(len(group["data"]["entities"]) for group in groups)

    # ------------------------------------------------------------ TypeIdNames
    current = {}
    for path in sorted((APP / "TypeIdNames").glob("*.json")):
        data = json.loads(path.read_text(encoding="utf-8-sig"))
        type_name = data.get("type") or path.stem
        if data.get("names") is not None:
            current[type_name] = data

    # IDs present in every per-type sheet.
    def sheet_table(sheet, id_header):
        ws = wb[sheet]
        if ws.cell(1, 1).value != id_header:
            raise SystemExit("%s: expected %s in A1, got %r" % (sheet, id_header, ws.cell(1, 1).value))
        header = [ws.cell(1, c).value for c in range(1, ws.max_column + 1)]
        rows_by_id = {}
        for r in range(2, ws.max_row + 1):
            values = [ws.cell(r, c).value for c in range(1, ws.max_column + 1)]
            if values[0] is None:
                continue
            rows_by_id[int(values[0])] = dict(zip(header, values))
        return header, rows_by_id

    tables = {}
    sheet_ids = {}
    for type_name, (sheet, id_header) in SHEET_IDS.items():
        header, rows_by_id = sheet_table(sheet, id_header)
        tables[type_name] = rows_by_id
        sheet_ids[type_name] = list(rows_by_id)

    # Reference graph: (type, id) -> [(type, id, role label)].
    # Follow the editor's own field meanings (see the 交互式ID表 reference diagram).
    edges = defaultdict(list)

    def ref(row, column):
        value = row.get(column)
        if value in (None, "", 0, "0"):
            return None
        try:
            return int(value)
        except (TypeError, ValueError):
            return None

    def link(source, target_type, target_id, role, reverse_role=None):
        # Forward ownership only. Reverse edges (target -> every consumer) are
        # deliberately not added: a shared damage/status would give all its
        # consumers the same name, e.g. every Fire beam becoming "Fire · ...".
        if target_id is not None and target_type in tables and target_id in tables[target_type]:
            edges[source].append(((target_type, target_id), role))

    for value, row in tables["projectile"].items():
        link(("projectile", value), "damage", ref(row, "UseDamageID"), "伤害", "使用此伤害的射弹")
        link(("projectile", value), "explosion", ref(row, "ExplosionIDOnImpact"), "撞击爆炸", "撞击此爆炸的射弹")
        link(("projectile", value), "explosion", ref(row, "ExplosionIDOnExpire"), "延迟爆炸", "延迟于此爆炸的射弹")
    for value, row in tables["explosion"].items():
        link(("explosion", value), "damage", ref(row, "UseDamageID"), "爆炸伤害", "产生此伤害的爆炸")
        link(("explosion", value), "projectile", ref(row, "ShrapnelProjectileID"), "弹片", "弹片所属爆炸")
    for value, row in tables["beam"].items():
        link(("beam", value), "damage", ref(row, "UseDamageID"), "伤害", "使用此伤害的激光")
        link(("beam", value), "explosion", ref(row, "ExplosionType"), "爆炸", "使用此爆炸的激光")
    for value, row in tables["arc"].items():
        link(("arc", value), "damage", ref(row, "UseDamageID"), "伤害", "使用此伤害的电弧")
    for value, row in tables["status"].items():
        link(("status", value), "damage", ref(row, "UseDamageID"), "状态伤害", "附加此状态")
    for value, row in tables["damage"].items():
        for slot in range(1, 5):
            link(("damage", value), "status", ref(row, "StatusEffectType%d" % slot), "状态%d" % slot, "附加状态%d" % slot)

    # Direct names from 主宽表: the first named row wins.
    direct = {}
    for row in rows:
        if not row["known"]:
            continue
        for type_name, ids in row["ids"].items():
            if type_name not in tables:
                continue
            for value in ids:
                if value in tables[type_name]:
                    direct.setdefault((type_name, value), row["name"])

    # Status names are their own table's Name column; every status id can be named.
    status_direct = {}
    for value, row in tables["status"].items():
        name = row.get("Name")
        if name not in (None, ""):
            status_direct[value] = clean_name(str(name).strip())
    for value, name in status_direct.items():
        direct.setdefault(("status", value), name)

    # Existing JSON names are the other source of information we have. They seed
    # ids the new table does not mention, and then the graph fills their relatives.
    existing = {}
    for source in (APP / "TypeIdNames",):
        if not source.is_dir():
            continue
        for path in sorted(source.glob("*.json")):
            data = json.loads(path.read_text(encoding="utf-8-sig"))
            type_name = data.get("type") or path.stem
            if type_name not in tables:
                continue
            for key, name in (data.get("names") or {}).items():
                if name:
                    value = int(key)
                    if value in tables[type_name]:
                        existing.setdefault((type_name, value), clean_name(str(name)))

    seeds = dict(direct)
    for key, name in existing.items():
        seeds.setdefault(key, name)

    # Breadth-first propagation. A propagated name is "<source> · <role>", so the
    # TypeID list still shows where the name came from.
    names = dict(seeds)
    queue = deque(seeds)
    propagated = {}
    while queue:
        source = queue.popleft()
        base = names[source]
        for target, role in edges.get(source, ()):
            if target in names:
                continue
            name = base + " · " + role
            if len(name) > 1024:
                continue
            names[target] = name
            propagated[target] = source
            queue.append(target)

    # Emit every ID of every per-type sheet, named or not.
    typeid_names = {}
    typeid_counts = {}
    for type_name in SHEET_IDS:
        typeid_names[type_name] = {
            str(value): (names.get((type_name, value)) or "")
            for value in sorted(sheet_ids[type_name])
        }
        typeid_counts[type_name] = {
            "entries": len(sheet_ids[type_name]),
            "named": sum(1 for v in typeid_names[type_name].values() if v),
            "direct": sum(1 for (t, i) in direct if t == type_name),
            "existing": sum(1 for (t, i) in existing if t == type_name and (t, i) not in direct),
            "propagated": sum(1 for (t, i) in propagated if t == type_name),
        }

    # The three component-index files have no sheet in this workbook: carry the current
    # JSON over, so the package remains complete.
    carried = {}
    for type_name in ("bombardment", "eagle", "stratagem"):
        if type_name not in current:
            raise SystemExit("missing current %s.json" % type_name)
        carried[type_name] = current[type_name]["names"]

    # --------------------------------------------------------------- write out
    if OUT.exists():
        shutil.rmtree(OUT)
    (OUT / "EntityNames").mkdir(parents=True)
    (OUT / "TypeIdNames").mkdir(parents=True)

    for group in groups:
        (OUT / "EntityNames" / group["name"]).write_text(dump_entity(group["data"]), encoding="utf-8", newline="")

    type_counts = {}
    for type_name in TYPES:
        if type_name in carried:
            data = carried[type_name]
            type_counts[type_name] = {"entries": len(data), "named": sum(1 for v in data.values() if v)}
        else:
            data = typeid_names[type_name]
            type_counts[type_name] = dict(typeid_counts[type_name])
        text = dump_type(type_name, data)
        (OUT / "TypeIdNames" / (type_name + ".json")).write_text(text, encoding="utf-8", newline="")

    manifest = {
        "version": 1,
        "source": {"file": XLSX.name, "sha256": sha256_file(XLSX)},
        "generated": dt.datetime.now().astimezone().isoformat(timespec="seconds"),
        "policy": "full replacement from 交互式ID表.xlsx; direct table names + forward reference propagation + existing names; unreferenced TypeIDs keep an empty planning name; no reverse fan-out",
        "entities": {
            "groups": len(groups),
            "entries": total_entities,
            "table_rows": len(rows),
            "named_rows": sum(1 for r in rows if r["known"]),
            "unknown_rows": sum(1 for r in rows if not r["known"]),
            "names_changed": len(entity_changes),
            "control_chars_cleaned": control_fixed,
        },
        "typeids": type_counts,
    }
    (OUT / "MANIFEST.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="")

    readme = [
        "SHODAN Stat Editor Offline — portable planning names",
        "",
        "EntityNames/  one JSON per entity group (hash + name).",
        "TypeIdNames/  one JSON per TypeID (local index + planning name).",
        "",
        "The editor reads this folder before %LOCALAPPDATA%\\SHODAN\\StatEditor.",
        "Edit a JSON, then click 重载JSON in the entity / TypeID list.",
        "An empty name (\"\") means no planning name: the game's own name is shown.",
        "Names like \"source · relation\" were traced forward through the ID reference graph.",
        "Coverage: %d / %d table TypeIDs named." % (
            sum(type_counts[t]["named"] for t in SHEET_IDS),
            sum(type_counts[t]["entries"] for t in SHEET_IDS),
        ),
        "",
        "Generated from: %s" % XLSX.name,
        "Source SHA-256: %s" % manifest["source"]["sha256"],
        "Rows: %d (named %d, unknown %d)" % (len(rows), manifest["entities"]["named_rows"], manifest["entities"]["unknown_rows"]),
        "",
    ]
    (OUT / "README.txt").write_text("\n".join(readme), encoding="utf-8", newline="")

    # ----------------------------------------------------------------- report
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "# 交互式ID表 → 便携包策划名",
        "",
        "- 源文件：`%s`" % XLSX,
        "- SHA-256：`%s`" % manifest["source"]["sha256"],
        "- 生成：`offline/Names`（随 build 分发，编辑器优先读取）",
        "",
        "## 规则",
        "",
        "- 主宽表 438 行：404 行有名称，34 行仍为“未知哈希”。",
        "- EntityNames：保留编辑器已有的全部 %d 个实体，表内 404 个名称覆盖，其他保持现有/基础名。" % total_entities,
        "- TypeIdNames：按各 ID 表的完整 ID 集合生成。先取主宽表直接引用，再只沿**正向**引用追溯：",
        "  射弹→伤害/撞击爆炸/延迟爆炸，爆炸→伤害/弹片，激光/电弧→伤害，伤害→状态，状态→伤害。",
        "- 不做反向扇出：伤害/状态是共享行，若反向给所有使用它的激光/射弹命名，会让多个不同记录得到同一个名字。",
        "- 现有 JSON 里有名字、但新表没有直接引用的 ID，作为第二层种子继续追溯；追溯名格式为“来源 · 关系”。",
        "- 仍然没有名字的 ID 写入空字符串，编辑器回退显示游戏原名。",
        "- `status` 使用表中的 `Name`；`bombardment` / `eagle` / `stratagem` 本表没有，沿用当前 JSON。",
        "",
        "## 数量",
        "",
        "| 类型 | 条目 | 直接命名 | 现有 JSON | 追溯命名 | 有策划名 |",
        "| --- | ---: | ---: | ---: | ---: | ---: |",
    ]
    for type_name in TYPES:
        c = type_counts[type_name]
        lines.append(
            "| `%s.json` | %d | %s | %s | %s | %d |"
            % (
                type_name,
                c["entries"],
                c.get("direct", "-"),
                c.get("existing", "-"),
                c.get("propagated", "-"),
                c["named"],
            )
        )
    lines += [
        "",
        "- 实体名称改动：%d" % len(entity_changes),
        "- 清理控制符：%d" % control_fixed,
        "- 表内类型总命名：%d / %d（%.1f%%）"
        % (
            sum(c["named"] for t, c in type_counts.items() if t in SHEET_IDS),
            sum(c["entries"] for t, c in type_counts.items() if t in SHEET_IDS),
            100.0
            * sum(c["named"] for t, c in type_counts.items() if t in SHEET_IDS)
            / sum(c["entries"] for t, c in type_counts.items() if t in SHEET_IDS),
        ),
        "",
        "未命名的 ID 仍保留在 JSON 中（空字符串）。它们要么没有正向命名来源，",
        "要么只被共享行反向引用；反向会制造同名，所以不强行命名，界面回退游戏原名。",
        "",
        "## 校验",
        "",
        "生成后会使用 `offline/entity_names.lua` 与 `offline/record_names.lua` 实际加载，再执行 build。",
        "",
    ]
    REPORT.write_text("\n".join(lines), encoding="utf-8", newline="")

    print(json.dumps(manifest, ensure_ascii=False, indent=2))
    print("written", OUT)


if __name__ == "__main__":
    main()
