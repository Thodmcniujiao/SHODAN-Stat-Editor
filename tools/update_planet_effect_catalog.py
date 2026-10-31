"""Refresh public WarInfo planet identities, without client credentials or writes."""
import argparse
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
from urllib.request import urlopen


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--war', type=int, default=801)
    parser.add_argument('--input', type=Path)
    parser.add_argument('--output', type=Path, default=Path(__file__).resolve().parents[1] / 'offline/planet_effect_data.lua')
    args = parser.parse_args()
    url = f'https://api.live.prod.thehelldiversgame.com/api/WarSeason/{args.war}/WarInfo'
    if args.input:
        raw = args.input.read_bytes()
    else:
        with urlopen(url, timeout=20) as response:
            raw = response.read(4 * 1024 * 1024 + 1)
    assert len(raw) <= 4 * 1024 * 1024
    data = json.loads(raw)
    assert data['warId'] == args.war
    planets = [dict(index=p['index'], settingsHash=p['settingsHash'])
               for p in sorted(data['planetInfos'], key=lambda p: p['index'])]
    assert planets and len({p['index'] for p in planets}) == len(planets)
    assert all(type(p['index']) is int and p['index'] >= 0 and type(p['settingsHash']) is int for p in planets)
    result = dict(source=url, war_id=data['warId'], layout_version=data['layoutVersion'],
                  fetched_utc=datetime.now(timezone.utc).isoformat(timespec='seconds'),
                  sha256=hashlib.sha256(raw).hexdigest(), planets=planets)
    text = json.dumps(result, ensure_ascii=False, indent=2)
    args.output.write_text('-- Official WarInfo planet identities; regenerate with tools/update_planet_effect_catalog.py.\n'
                           "return require('json_data').decode([===[\n" + text + '\n]===])\n', encoding='utf-8')
    print(f'War {args.war}, layout {data["layoutVersion"]}: {len(planets)} planets')


if __name__ == '__main__':main()
