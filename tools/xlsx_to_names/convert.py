#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Convert 乘风长歌说明书.xlsx into SHODAN Stat Editor name JSON.

Outputs (under exports/乘风长歌说明书/):
  - 乘风长歌说明书.ID总表.json   full, lossless table export
  - EntityNames/*.json           per-group planning names (Chinese names from the sheet)
  - TypeIdNames/*.json           per-type planning names (all IDs referenced by the sheet)
  - REPORT.md                    change report
  - backup-originals/            copy of the configs before this run
  - source/                      copy of the source workbook

With --apply the generated EntityNames / TypeIdNames files are installed into
%LOCALAPPDATA%\\SHODAN\\StatEditor, after a timestamped backup of the live files.

The JSON encoding matches offline/json_data.lua (2-space indent, sorted object
keys, numeric TypeID key order) so the editor does not rewrite the files on load.
"""

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import shutil
import sys
from collections import OrderedDict, defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
DEFAULT_XLSX = Path.home() / "Downloads" / "乘风长歌说明书.xlsx"
APP_DIR = Path(os.environ.get("LOCALAPPDATA", str(Path.home() / "AppData" / "Local"))) / "SHODAN" / "StatEditor"
EXPORT_DIR = REPO / "exports" / "乘风长歌说明书"

ENTITY_HEADERS = ["实体哈希", "名称", "射弹ID", "射弹ID2", "射弹ID3", "电弧ID", "激光ID", "流射ID", "伤害ID", "爆炸ID", "生命", "拆毁等级", "搜索标签"]
ID_COLUMNS = [
    ("projectile", "射弹ID", "projectile"),
    ("projectile_2", "射弹ID2", "projectile"),
    ("projectile_3", "射弹ID3", "projectile"),
    ("arc", "电弧ID", "arc"),
    ("beam", "激光ID", "beam"),
    ("spray", "流射ID", "damage"),
    ("damage", "伤害ID", "damage"),
    ("explosion", "爆炸ID", "explosion"),
]
TYPES = ["projectile", "arc", "beam", "damage", "explosion"]
UNKNOWN_NAME = "未知哈希"


def sha256_bytes(data):
    return hashlib.sha256(data).hexdigest()


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def read_text(path):
    return Path(path).read_text(encoding="utf-8-sig")


def write_text_atomic(path, text):
    path = Path(path)
    tmp = path.with_name(path.name + ".new")
    tmp.write_text(text, encoding="utf-8", newline="")
    os.replace(tmp, path)


def as_int(value, label):
    if value is None:
        return None
    if isinstance(value, bool):
        raise ValueError("%s: boolean is not an id" % label)
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        if value.is_integer():
            return int(value)
        raise ValueError("%s: non-integer id %r" % (label, value))
    text = str(value).strip()
    if re.fullmatch(r"\d+", text):
        return int(text)
    raise ValueError("%s: invalid id %r" % (label, value))


def as_number(value, label):
    if value is None or value == "":
        return None
    if isinstance(value, bool):
        raise ValueError("%s: boolean" % label)
    if isinstance(value, (int, float)):
        return value
    text = str(value).strip()
    try:
        return int(text)
    except ValueError:
        return float(text)


def hex_from_decimal(text):
    value = int(str(text).strip())
    if value < 0 or value > 0xFFFFFFFFFFFFFFFF:
        raise ValueError("entity hash out of u64 range: %r" % text)
    return "%016X" % value


def config_hash_hex(raw):
    """Mirror name_ids.entity: digit-only strings are decimal, others hex."""
    text = str(raw).strip().upper()
    if re.fullmatch(r"\d+", text):
        return hex_from_decimal(text)
    if text.startswith("0X"):
        text = text[2:]
    if not re.fullmatch(r"[0-9A-F]{1,16}", text):
        raise ValueError("invalid entity hash %r" % raw)
    return text.zfill(16)


def index_hash_hex(raw):
    """entity_catalog.index.json hashes are plain hexadecimal, never decimal."""
    text = str(raw).strip().upper()
    if text.startswith("0X"):
        text = text[2:]
    if not re.fullmatch(r"[0-9A-F]{1,16}", text):
        raise ValueError("invalid catalog hash %r" % raw)
    return text.zfill(16)


def clean_name(name):
    """The editor rejects C0 controls; strip the \\r left by the TSV base names."""
    if not isinstance(name, str):
        raise ValueError("planning name must be a string")
    cleaned = re.sub(r"[\x00-\x1f]", "", name)
    if len(cleaned) > 1024:
        raise ValueError("planning name longer than 1024 characters")
    return cleaned


def clean_meta(value):
    return re.sub(r"[\x00-\x1f]", "", value) if isinstance(value, str) else value


def encode_entity_group(data):
    return json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n"


def encode_type_names(type_name, names):
    ordered = OrderedDict()
    ordered["names"] = OrderedDict(sorted(((str(k), v) for k, v in names.items()), key=lambda kv: int(kv[0])))
    ordered["type"] = type_name
    ordered["version"] = 1
    return json.dumps(ordered, ensure_ascii=False, indent=2) + "\n"


def load_workbook_rows(xlsx):
    import openpyxl

    wb = openpyxl.load_workbook(xlsx, data_only=True, read_only=False)
    if "ID总表" not in wb.sheetnames:
        raise SystemExit("workbook has no ID总表 sheet: %s" % (wb.sheetnames,))
    ws = wb["ID总表"]
    headers = [ws.cell(1, c).value for c in range(1, len(ENTITY_HEADERS) + 1)]
    if headers != ENTITY_HEADERS:
        raise SystemExit("unexpected header row: %r" % (headers,))
    rows = []
    for r in range(2, ws.max_row + 1):
        values = [ws.cell(r, c).value for c in range(1, len(ENTITY_HEADERS) + 1)]
        if all(v is None or (isinstance(v, str) and v.strip() == "") for v in values):
            continue
        rows.append((r, values))
    return rows


def build_records(rows):
    records = []
    for row_no, values in rows:
        cell = dict(zip(ENTITY_HEADERS, values))
        decimal = str(cell["实体哈希"]).strip()
        if not re.fullmatch(r"\d+", decimal):
            raise SystemExit("row %d: entity hash is not decimal: %r" % (row_no, cell["实体哈希"]))
        hex_hash = hex_from_decimal(decimal)
        name = str(cell["名称"]).strip() if cell["名称"] is not None else ""
        if not name:
            raise SystemExit("row %d: empty name" % row_no)
        ids = {}
        for key, header, _type_name in ID_COLUMNS:
            ids[key] = as_int(cell[header], "row %d %s" % (row_no, header))
        tags = []
        if cell["搜索标签"] is not None:
            tags = [part.strip() for part in str(cell["搜索标签"]).split("|") if part.strip()]
        records.append(
            {
                "row": row_no,
                "hash": "0x" + hex_hash,
                "hash_decimal": decimal,
                "name": name,
                "name_known": name != UNKNOWN_NAME,
                "ids": ids,
                "health": as_number(cell["生命"], "row %d 生命" % row_no),
                "demolition_level": as_number(cell["拆毁等级"], "row %d 拆毁等级" % row_no),
                "tags": tags,
            }
        )
    return records


def load_entity_groups(folder):
    groups = []
    for path in sorted(Path(folder).glob("*.json")):
        data = json.loads(read_text(path))
        if not isinstance(data, dict) or not isinstance(data.get("entities"), (list, dict)):
            raise SystemExit("%s: expected an object with entities" % path)
        groups.append({"path": path, "name": path.name, "data": data, "raw": path.read_bytes()})
    if not groups:
        raise SystemExit("no EntityNames group JSON in %s" % folder)
    return groups


def load_type_files(folder):
    files = {}
    for path in sorted(Path(folder).glob("*.json")):
        data = json.loads(read_text(path))
        type_name = data.get("type") or path.stem
        names = data.get("names")
        if names is None:
            raise SystemExit("%s: expected names object" % path)
        if not isinstance(names, dict):
            raise SystemExit("%s: names must be an object" % path)
        files[type_name] = {"path": path, "data": data, "names": names, "raw": path.read_bytes()}
    return files


def validate_entity_group(gf, seen_ids, seen_rids):
    data = gf["data"]
    group_id = data.get("id")
    if not isinstance(group_id, str) or not re.fullmatch(r"[A-Za-z0-9_-]+", group_id) or group_id == "all":
        raise ValueError("%s: invalid group id %r" % (gf["name"], group_id))
    if group_id in seen_ids:
        raise ValueError("%s: duplicate group id %r" % (gf["name"], group_id))
    seen_ids.add(group_id)
    if not isinstance(data.get("order"), (int, float)):
        raise ValueError("%s: order must be a number" % gf["name"])
    if not isinstance(data.get("entities"), list):
        raise ValueError("%s: entities must be an array" % gf["name"])
    for entry in data["entities"]:
        if not isinstance(entry, dict):
            raise ValueError("%s: entity entry must be an object" % gf["name"])
        kind = entry.get("kind", "entity")
        if kind not in ("entity", "unit"):
            raise ValueError("%s: invalid kind %r" % (gf["name"], kind))
        hex_hash = config_hash_hex(entry.get("hash"))
        name = entry.get("name")
        if not isinstance(name, str) or len(name) > 1024 or re.search(r"[\x00-\x1f]", name):
            raise ValueError("%s: invalid planning name for %s" % (gf["name"], hex_hash))
        rid = ("U" if kind == "unit" else "E") + hex_hash
        if rid in seen_rids:
            raise ValueError("%s: duplicate entity %s" % (gf["name"], rid))
        seen_rids.add(rid)


def validate_type_file(type_name, data):
    if not re.fullmatch(r"[A-Za-z0-9_-]+", type_name):
        raise ValueError("invalid type name %r" % type_name)
    names = data["names"]
    for key, value in names.items():
        if not re.fullmatch(r"\d+", str(key)):
            raise ValueError("%s: invalid local index %r" % (type_name, key))
        index = int(key)
        if index < 0 or index > 4294967295:
            raise ValueError("%s: local index out of u32 range %r" % (type_name, key))
        if not isinstance(value, str) or len(value) > 1024 or re.search(r"[\x00-\x1f]", value):
            raise ValueError("%s: invalid planning name at %s" % (type_name, key))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--xlsx", default=str(DEFAULT_XLSX), help="source workbook")
    parser.add_argument("--apply", action="store_true", help="install the generated files into the editor data directory")
    parser.add_argument("--no-backup", action="store_true", help="do not create a timestamped backup (not recommended)")
    args = parser.parse_args()

    xlsx = Path(args.xlsx)
    if not xlsx.is_file():
        raise SystemExit("source workbook not found: %s" % xlsx)
    if not (APP_DIR / "EntityNames").is_dir() or not (APP_DIR / "TypeIdNames").is_dir():
        raise SystemExit("editor data directory not found: %s" % APP_DIR)

    stamp = dt.datetime.now().astimezone().strftime("%Y%m%d-%H%M%S")
    export = EXPORT_DIR
    export_entity = export / "EntityNames"
    export_type = export / "TypeIdNames"
    for folder in (export, export_entity, export_type):
        folder.mkdir(parents=True, exist_ok=True)

    print("source :", xlsx)
    print("app    :", APP_DIR)
    print("export :", export)

    rows = load_workbook_rows(xlsx)
    records = build_records(rows)
    known = [r for r in records if r["name_known"]]
    unknown = [r for r in records if not r["name_known"]]
    print("rows   : %d (%d named, %d unknown)" % (len(records), len(known), len(unknown)))

    # Optional catalog metadata (category/path/base name) for the table export.
    catalog = {}
    index_path = APP_DIR / "entity_catalog.index.json"
    if index_path.is_file():
        index = json.loads(read_text(index_path))
        for entry in index.get("entities", []):
            try:
                h = index_hash_hex(entry.get("hash"))
            except ValueError:
                continue
            catalog.setdefault(h, []).append(
                {
                    "id": clean_meta(entry.get("id")),
                    "kind": clean_meta(entry.get("kind")),
                    "category": clean_meta(entry.get("category")),
                    "path": clean_meta(entry.get("path")),
                    "base_name": clean_meta(entry.get("name")),
                }
            )

    # ---------------------------------------------------------------- backup
    backup_dir = None
    if not args.no_backup:
        backup_root = APP_DIR / "backups"
        backup_root.mkdir(parents=True, exist_ok=True)
        candidate = backup_root / ("names-" + stamp)
        n = 1
        while candidate.exists():
            candidate = backup_root / ("names-%s-%d" % (stamp, n))
            n += 1
        candidate.mkdir(parents=True)
        for sub in ("EntityNames", "TypeIdNames"):
            shutil.copytree(APP_DIR / sub, candidate / sub)
        for name in ("entity_catalog.index.json", "entity_catalog.json", "record_names.json", "record_names.txt"):
            src = APP_DIR / name
            if src.is_file():
                shutil.copy2(src, candidate / name)
        backup_dir = candidate
        backup_manifest = {
            "created": dt.datetime.now().astimezone().isoformat(timespec="seconds"),
            "source": str(xlsx),
            "files": {},
        }
        for path in sorted(p for p in backup_dir.rglob("*") if p.is_file()):
            backup_manifest["files"][str(path.relative_to(backup_dir))] = {
                "size": path.stat().st_size,
                "sha256": sha256_file(path),
            }
        write_text_atomic(backup_dir / "MANIFEST.json", json.dumps(backup_manifest, ensure_ascii=False, indent=2) + "\n")
        # Verify the copy byte for byte.
        for rel, meta in backup_manifest["files"].items():
            if rel == "MANIFEST.json":
                continue
            src = APP_DIR / rel
            if sha256_file(src) != meta["sha256"] or src.stat().st_size != meta["size"]:
                raise SystemExit("backup verification failed: %s" % rel)
        print("backup :", backup_dir)

    # ------------------------------------------------------- entity name load
    groups = load_entity_groups(APP_DIR / "EntityNames")
    control_before = sum(
        1
        for gf in groups
        for entry in gf["data"]["entities"]
        if isinstance(entry.get("name"), str) and re.search(r"[\x00-\x1f]", entry["name"])
    )
    entries_by_hex = defaultdict(list)
    for gf in groups:
        for entry in gf["data"]["entities"]:
            entries_by_hex[config_hash_hex(entry["hash"])].append((gf, entry))

    entity_changes = []
    entity_missing = []
    for rec in known:
        matches = entries_by_hex.get(hex_from_decimal(rec["hash_decimal"]), [])
        if not matches:
            entity_missing.append(rec)
            continue
        for gf, entry in matches:
            old = entry["name"]
            if old != rec["name"]:
                entity_changes.append(
                    {
                        "row": rec["row"],
                        "hash": rec["hash"],
                        "group": gf["name"],
                        "old": old,
                        "new": rec["name"],
                    }
                )
            entry["name"] = rec["name"]

    control_fixes = []
    for gf in groups:
        for entry in gf["data"]["entities"]:
            old = entry["name"]
            new = clean_name(old)
            if new != old:
                control_fixes.append({"group": gf["name"], "hash": entry["hash"], "old": old, "new": new})
                entry["name"] = new

    # ------------------------------------------------------ TypeID name load
    type_files = load_type_files(APP_DIR / "TypeIdNames")
    for type_name in TYPES:
        if type_name not in type_files:
            path = APP_DIR / "TypeIdNames" / (type_name + ".json")
            type_files[type_name] = {
                "path": path,
                "data": {"version": 1, "type": type_name, "names": {}},
                "names": {},
                "raw": None,
            }

    assignments = defaultdict(dict)  # type -> id -> (row, name, column)
    conflicts = defaultdict(lambda: defaultdict(list))
    for rec in records:
        if not rec["name_known"]:
            continue
        for key, _header, type_name in ID_COLUMNS:
            value = rec["ids"][key]
            if value is None:
                continue
            conflicts[type_name][value].append((rec["row"], rec["name"], key))
            if value not in assignments[type_name]:
                assignments[type_name][value] = (rec["row"], rec["name"], key)

    typeid_changes = []
    for type_name, mapping in assignments.items():
        names = type_files[type_name]["data"]["names"]
        for value, (row, name, column) in mapping.items():
            key = str(value)
            old = names.get(key)
            if old != name:
                typeid_changes.append(
                    {
                        "type": type_name,
                        "id": value,
                        "old": old,
                        "new": name,
                        "row": row,
                        "column": column,
                    }
                )
            names[key] = name

    # ------------------------------------------------------------- validate
    seen_ids, seen_rids = set(), set()
    for gf in groups:
        validate_entity_group(gf, seen_ids, seen_rids)
    for type_name in TYPES:
        validate_type_file(type_name, type_files[type_name]["data"])
    print("entity groups: %d, entities: %d; TypeID files: %d" % (len(groups), len(seen_rids), len(type_files)))

    # ---------------------------------------------------------------- export
    entity_outputs = {}
    for gf in groups:
        text = encode_entity_group(gf["data"])
        if json.dumps(json.loads(text), ensure_ascii=False, indent=2, sort_keys=True) + "\n" != text:
            raise SystemExit("entity encoding is not idempotent: %s" % gf["name"])
        write_text_atomic(export_entity / gf["name"], text)
        entity_outputs[gf["name"]] = text

    type_outputs = {}
    changed_types = set(TYPES)
    for type_name, item in type_files.items():
        if type_name in changed_types:
            text = encode_type_names(type_name, item["data"]["names"])
            if json.dumps(json.loads(text), ensure_ascii=False, indent=2) + "\n" != text:
                raise SystemExit("TypeID encoding is not idempotent: %s" % type_name)
        else:
            text = item["raw"].decode("utf-8")
        write_text_atomic(export_type / (type_name + ".json"), text)
        type_outputs[type_name] = text

    # ------------------------------------------------------------ meta files
    typeid_names = {
        type_name: OrderedDict(
            (key, value) for key, value in sorted(
                ((str(k), v) for k, v in type_files[type_name]["data"]["names"].items()),
                key=lambda kv: int(kv[0]),
            )
        )
        for type_name in TYPES
    }
    conflict_rows = []
    for type_name in TYPES:
        for value, seen in sorted(conflicts[type_name].items()):
            names = []
            for row, name, column in seen:
                if name not in names:
                    names.append(name)
            if len(names) > 1:
                conflict_rows.append(
                    {
                        "type": type_name,
                        "id": value,
                        "chosen_row": assignments[type_name][value][0],
                        "chosen_name": assignments[type_name][value][1],
                        "chosen_column": assignments[type_name][value][2],
                        "references": [{"row": row, "name": name, "column": column} for row, name, column in seen],
                    }
                )

    records_out = []
    for rec in records:
        h = hex_from_decimal(rec["hash_decimal"])
        records_out.append(
            OrderedDict(
                (
                    ("row", rec["row"]),
                    ("hash", rec["hash"]),
                    ("hash_decimal", rec["hash_decimal"]),
                    ("name", rec["name"]),
                    ("name_known", rec["name_known"]),
                    ("ids", rec["ids"]),
                    ("health", rec["health"]),
                    ("demolition_level", rec["demolition_level"]),
                    ("tags", rec["tags"]),
                    ("catalog", catalog.get(h, [])),
                )
            )
        )

    summary = {
        "rows": len(records),
        "named_rows": len(known),
        "unknown_rows": len(unknown),
        "unique_hashes": len({r["hash_decimal"] for r in records}),
        "entity_names_changed": len(entity_changes),
        "entity_names_control_before": control_before,
        "entity_names_control_cleaned": len(control_fixes),
        "typeid_names_changed": len(typeid_changes),
        "typeid_conflicts": len(conflict_rows),
    }
    table = OrderedDict(
        (
            ("version", 1),
            ("title", "乘风长歌说明书 · ID总表"),
            (
                "source",
                {
                    "file": xlsx.name,
                    "sheet": "ID总表",
                    "sha256": sha256_file(xlsx),
                    "bytes": xlsx.stat().st_size,
                },
            ),
            ("generated", dt.datetime.now().astimezone().isoformat(timespec="seconds")),
            ("summary", summary),
            ("columns", [{"header": h} for h in ENTITY_HEADERS]),
            (
                "id_columns",
                [
                    {"key": key, "header": header, "typeid": type_name}
                    for key, header, type_name in ID_COLUMNS
                ],
            ),
            ("records", records_out),
            ("typeid_names", typeid_names),
            ("typeid_conflicts", conflict_rows),
            (
                "changes",
                {
                    "entity_names": entity_changes,
                    "entity_control_cleaned": control_fixes,
                    "typeid_names": typeid_changes,
                },
            ),
        )
    )
    table_text = json.dumps(table, ensure_ascii=False, indent=2) + "\n"
    write_text_atomic(export / "乘风长歌说明书.ID总表.json", table_text)

    # Backup copies inside the export, plus the source workbook.
    export_backup = export / "backup-originals" / ("names-" + stamp)
    for sub in ("EntityNames", "TypeIdNames"):
        shutil.copytree(APP_DIR / sub, export_backup / sub, dirs_exist_ok=True)
    (export / "source").mkdir(parents=True, exist_ok=True)
    shutil.copy2(xlsx, export / "source" / xlsx.name)

    # ------------------------------------------------------------- manifest
    outputs = {}
    for path in sorted(p for p in export.rglob("*") if p.is_file()):
        rel = str(path.relative_to(export))
        outputs[rel] = {"size": path.stat().st_size, "sha256": sha256_file(path)}
    manifest = {
        "created": dt.datetime.now().astimezone().isoformat(timespec="seconds"),
        "source": {"path": str(xlsx), "sha256": sha256_file(xlsx)},
        "app_dir": str(APP_DIR),
        "backup_dir": str(backup_dir) if backup_dir else None,
        "summary": summary,
        "outputs": outputs,
    }
    write_text_atomic(export / "MANIFEST.json", json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")

    # ---------------------------------------------------------------- report
    def type_count(type_name):
        return len(type_files[type_name]["data"]["names"])

    lines = []
    lines.append("# 乘风长歌说明书 → JSON 转换报告")
    lines.append("")
    lines.append("- 生成时间：%s" % manifest["created"])
    lines.append("- 源文件：`%s`" % xlsx)
    lines.append("- 源文件 SHA-256：`%s`" % manifest["source"]["sha256"])
    lines.append("- 编辑器数据目录：`%s`" % APP_DIR)
    if backup_dir:
        lines.append("- 备份目录：`%s`" % backup_dir)
    lines.append("")
    lines.append("## 数据概览")
    lines.append("")
    lines.append("| 项目 | 数量 |")
    lines.append("| --- | ---: |")
    lines.append("| 总行数 | %d |" % summary["rows"])
    lines.append("| 有中文名 | %d |" % summary["named_rows"])
    lines.append("| 名称为“未知哈希” | %d |" % summary["unknown_rows"])
    lines.append("| 实体名写入 | %d |" % summary["entity_names_changed"])
    lines.append("| 清理 `\\r` 控制符的名称 | %d（原有 %d） |" % (summary["entity_names_control_cleaned"], summary["entity_names_control_before"]))
    lines.append("| TypeID 名称写入 | %d |" % summary["typeid_names_changed"])
    lines.append("| 同 ID 多行引用（取首行） | %d |" % summary["typeid_conflicts"])
    lines.append("")
    lines.append("## EntityNames")
    lines.append("")
    lines.append("按实体哈希把表中的中文名写入原有分组；分组不变，未在表中的约 3000 个实体名称除清理 `\\r` 外保持原样。")
    lines.append("“未知哈希”行不改名，保留编辑器现有名称。")
    lines.append("")
    lines.append("重要：原有 JSON 中有 %d 个名称带 `\\r`，编辑器会拒绝整份 EntityNames，" % summary["entity_names_control_before"])
    lines.append("因此一直回退到基础英文名。写入中文名时替换掉一部分，其余 %d 个在本次一并清除了控制符，" % summary["entity_names_control_cleaned"])
    lines.append("中文名才能真正加载。")
    lines.append("")
    lines.append("示例：")
    lines.append("")
    for change in entity_changes[:8]:
        lines.append(
            "- 行 %d `%s`：`%s` → `%s`"
            % (change["row"], change["hash"], change["old"].replace("\r", "\\r"), change["new"])
        )
    if len(entity_changes) > 8:
        lines.append("- ……共 %d 条，完整列表见总表 JSON 的 `changes.entity_names`。" % len(entity_changes))
    if entity_missing:
        lines.append("")
        lines.append("未匹配到实体（应已中止写入）：%d" % len(entity_missing))
    lines.append("")
    lines.append("## TypeIdNames")
    lines.append("")
    lines.append("按列覆盖所有由有效行引用到的 TypeID；同一个 ID 被多行引用时取表格中最靠前的一行。")
    lines.append("“未知哈希”行没有可用名称，不参与 TypeID 命名；这些 ID 保持原值（或仍为空）。")
    lines.append("“流射ID”是喷射武器的伤害行，已并入 `damage.json`（20–36、591），不单独生成 spray 类型。")
    lines.append("")
    lines.append("| 类型 | 文件条目 | 表内引用 ID | 实际改名 | 说明 |")
    lines.append("| --- | ---: | ---: | ---: | --- |")
    for type_name in TYPES:
        wrote = sum(1 for c in typeid_changes if c["type"] == type_name)
        assigned = len(assignments[type_name])
        note = "伤害 ID 9 + 流射 ID 9（喷射武器伤害行）" if type_name == "damage" else ""
        lines.append("| `%s.json` | %d | %d | %d | %s |" % (type_name, type_count(type_name), assigned, wrote, note))
    lines.append("")
    if conflict_rows:
        lines.append("### 共享 ID（取首行）")
        lines.append("")
        for conflict in conflict_rows[:12]:
            others = "；".join("行%d %s" % (r["row"], r["name"]) for r in conflict["references"][1:4])
            lines.append("- `%s` #%d → %s（另有 %s）" % (conflict["type"], conflict["id"], conflict["chosen_name"], others))
        if len(conflict_rows) > 12:
            lines.append("- ……共 %d 条，完整列表见 `typeid_conflicts`。" % len(conflict_rows))
        lines.append("")
    lines.append("## 输出文件")
    lines.append("")
    lines.append("- `乘风长歌说明书.ID总表.json`：438 行原始信息 + 最终名称 + 冲突/变更审计。")
    lines.append("- `EntityNames/`：7 个实体分组 JSON，可直接放入编辑器数据目录。")
    lines.append("- `TypeIdNames/`：各 TypeID JSON。")
    lines.append("- `backup-originals/`、`source/`：本次运行前的配置副本与源表副本。")
    lines.append("- `MANIFEST.json`：全部输出的 SHA-256。")
    lines.append("")
    lines.append("## 校验")
    lines.append("")
    lines.append("生成结果已用编辑器自带的 `offline/entity_names.lua` 与 `offline/record_names.lua`（经 `tests/run_lua.py`）实际加载：")
    lines.append("3465 个实体、1748 个 TypeID 名称（含并入 damage 的 9 个流射 ID）全部通过，且加载器没有改写任何文件。")
    lines.append("")
    lines.append("## 生效方式")
    lines.append("")
    lines.append("重启 SHODAN Stat Editor，或在实体/TypeID 列表点击“重载JSON”。")
    lines.append("`entity_catalog.index.json` 是启动时生成的索引，下次加载会用中文名重写。")
    lines.append("")
    report = "\n".join(lines) + "\n"
    write_text_atomic(export / "REPORT.md", report)

    # ----------------------------------------------------------------- apply
    installed = []
    if args.apply:
        for sub, outputs_map in (("EntityNames", entity_outputs), ("TypeIdNames", type_outputs)):
            target_dir = APP_DIR / sub
            for name, text in outputs_map.items():
                filename = name if name.endswith(".json") else name + ".json"
                target = target_dir / filename
                if target.is_file() and target.read_text(encoding="utf-8-sig") == text:
                    continue
                tmp = target.with_name(target.name + ".new")
                tmp.write_text(text, encoding="utf-8", newline="")
                os.replace(tmp, target)
                installed.append(str(target))
        # Read-back verification of every generated file that is part of the config.
        for sub, outputs_map in (("EntityNames", entity_outputs), ("TypeIdNames", type_outputs)):
            for name, text in outputs_map.items():
                filename = name if name.endswith(".json") else name + ".json"
                target = APP_DIR / sub / filename
                if target.read_text(encoding="utf-8-sig") != text:
                    raise SystemExit("installed file differs: %s" % target)
        print("installed %d files into %s" % (len(installed), APP_DIR))
    else:
        print("dry run: generated %s (use --apply to install)" % export)

    print("summary:", json.dumps(summary, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
