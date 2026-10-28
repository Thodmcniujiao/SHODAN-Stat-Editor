"""Packs SHODAN Stat Editor Offline: the launcher, LuaJIT, libsodium, the host and the built stat_editor.lua.
  python package.py [<name>]   ->  ../addons/stat_editor/release/<name>.zip (in the GitHub repository: release/) (default SHODAN-Stat-Editor-Offline-v<version>)"""
import os, re, subprocess, sys, zipfile
HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.join(HERE, '..', 'addons', 'stat_editor')
PANEL = os.path.join(ADDON, 'stat_editor_offline.lua')   # build.py --offline
if not os.path.exists(PANEL):                             # the GitHub repository: the built panel is src/'s
    PANEL = os.path.join(HERE, '..', 'src', 'stat_editor_offline.lua')
RELEASE = os.path.join(ADDON if os.path.isdir(ADDON) else HERE, 'release')
TOP = 'SHODAN Stat Editor Offline'
files = {
    'SHODAN Stat Editor Offline.exe': os.path.join(HERE, 'launcher', 'SHODAN Stat Editor Offline.exe'),
    'lua51.dll': os.path.join(HERE, 'runtime', 'lua51.dll'),
    'libsodium.dll': os.path.join(HERE, 'runtime', 'libsodium.dll'),
    'shodan_hash.dll': os.path.join(HERE, 'launcher', 'shodan_hash.dll'),
    'app/stat_editor.lua': PANEL,
}
# Runtime modules live directly in offline/. Discover them so adding a component
# cannot leave either release format with a stale hand-maintained module list.
for name in sorted(os.listdir(HERE)):
    if name.endswith('.lua') and os.path.isfile(os.path.join(HERE, name)):
        files['app/' + name] = os.path.join(HERE, name)
files['app/entity_names.tsv'] = os.path.join(HERE, 'entity_names.tsv')
files['app/entity_catalog.default.json'] = os.path.join(HERE, 'entity_catalog.default.json')
files['LICENSE'] = os.path.join(HERE, '..', 'LICENSE')
files['ENTITY_DEMOLITION.md'] = os.path.join(HERE, 'ENTITY_DEMOLITION.md')
files['ENTITY_COMPONENTS.md'] = os.path.join(HERE, 'ENTITY_COMPONENTS.md')
files['BOMBARDMENT_COMPONENTS.md'] = os.path.join(HERE, 'BOMBARDMENT_COMPONENTS.md')
files['ORBITAL_WEAPON_COMPONENTS.md'] = os.path.join(HERE, 'ORBITAL_WEAPON_COMPONENTS.md')
files['NAMED_PARAMETERS.md'] = os.path.join(HERE, 'NAMED_PARAMETERS.md')
files['PLAYER_SAVE.md'] = os.path.join(HERE, 'PLAYER_SAVE.md')
files['PRESETS.md'] = os.path.join(HERE, 'PRESETS.md')
files['PRELOAD_COMPONENTS.md'] = os.path.join(HERE, 'PRELOAD_COMPONENTS.md')
files['PLANET_SETTINGS.md'] = os.path.join(HERE, 'PLANET_SETTINGS.md')
files['ENEMY_DATA.md'] = os.path.join(HERE, 'ENEMY_DATA.md')
files['PLAYER_DATA.md'] = os.path.join(HERE, 'PLAYER_DATA.md')
files['SPAWN_EDITOR.md'] = os.path.join(HERE, 'SPAWN_EDITOR.md')
files['MODIFIER_ATTACHMENTS.md'] = os.path.join(HERE, 'MODIFIER_ATTACHMENTS.md')
files['REFERENCE_NAVIGATION.md'] = os.path.join(HERE, 'REFERENCE_NAVIGATION.md')
files['STRATAGEM_COMPONENTS.md'] = os.path.join(HERE, 'STRATAGEM_COMPONENTS.md')
files['DAMAGE_COMPONENTS.md'] = os.path.join(HERE, 'DAMAGE_COMPONENTS.md')
files['PROJECTILE_COMPONENTS.md'] = os.path.join(HERE, 'PROJECTILE_COMPONENTS.md')
files['EXPLOSION_COMPONENTS.md'] = os.path.join(HERE, 'EXPLOSION_COMPONENTS.md')
files['ARC_COMPONENTS.md'] = os.path.join(HERE, 'ARC_COMPONENTS.md')
files['BEAM_COMPONENTS.md'] = os.path.join(HERE, 'BEAM_COMPONENTS.md')
files['ENTITY_CATALOG_API.md'] = os.path.join(HERE, 'ENTITY_CATALOG_API.md')
files['ENTITY_CATALOG_SCHEMA.json'] = os.path.join(HERE, 'entity_catalog.schema.json')
DEV = re.compile(r'[ \t]*--\[\[DEV\]\].*?--\[\[/DEV\]\][^\n]*\n', re.S)   # test hooks: not in the package
VERSION = re.search(r"version = '([\d.]+)'", open(PANEL, encoding='utf-8').read()).group(1)
readme = open(os.path.join(HERE, 'RELEASE_README.txt'), encoding='utf-8').read()
# app/build.txt: which build this is, for the updater (a development build is new when its commit differs).
# The commit: SSEO_COMMIT (the CI's), else the GitHub repository's HEAD (package after committing a release).
REPO = os.path.join(HERE, '..') if not os.path.isdir(ADDON) else os.path.join(HERE, '..', '..', 'github', 'SHODAN-Stat-Editor')
CHANNEL = os.environ.get('SSEO_CHANNEL', 'release')
COMMIT = os.environ.get('SSEO_COMMIT', '')
if not COMMIT and os.path.isdir(os.path.join(REPO, '.git')):
    git = lambda *a: subprocess.run(['git', '-C', REPO] + list(a), capture_output=True, text=True).stdout.strip()
    COMMIT = git('rev-parse', 'HEAD')
    if git('status', '--porcelain', '--untracked-files=no'):
        print('note: the repository has uncommitted changes; build.txt names its HEAD', COMMIT[:7])
build_txt = 'version=%s\ncommit=%s\nchannel=%s\n' % (VERSION, COMMIT, CHANNEL)
if os.environ.get('SSEO_BUILT'):
    build_txt += 'built=' + os.environ['SSEO_BUILT'] + '\n'
os.makedirs(RELEASE, exist_ok=True)
name = sys.argv[1] if len(sys.argv) > 1 else 'SHODAN-Stat-Editor-Offline-v' + VERSION
out = os.path.join(RELEASE, name + '.zip')
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for arc, src in sorted(files.items()):
        if arc.startswith('app/') and arc != 'app/stat_editor.lua':
            text = DEV.sub('', open(src, encoding='utf-8').read())
            assert 'DEV' not in text and 'SHODAN_HOST_TEST' not in text, arc
            z.writestr(TOP + '/' + arc, text)
        else:
            z.write(src, TOP + '/' + arc)
    z.writestr(TOP + '/README.txt', readme.format(version=VERSION).replace('\n', '\r\n'))
    z.writestr(TOP + '/app/build.txt', build_txt)
    notices = [open(os.path.join(HERE, 'licenses', n), encoding='utf-8').read().strip() for n in ('LuaJIT.txt', 'libsodium.txt')]
    z.writestr(TOP + '/THIRD-PARTY-NOTICES.txt', ('\n\n' + '=' * 79 + '\n\n').join(notices).replace('\n', '\r\n') + '\r\n')
print(out, os.path.getsize(out) // 1024, 'KB;', build_txt.replace('\n', ' '))
