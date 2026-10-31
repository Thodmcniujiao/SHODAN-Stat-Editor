"""Audit the public ZIP without reading or copying a user's local release folder."""
import argparse
import hashlib
import re
import zipfile
from pathlib import Path, PurePosixPath


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('archive', type=Path)
    parser.add_argument('--commit', required=True)
    parser.add_argument('--channel', default='dev')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    top = 'SHODAN Stat Editor Offline/'
    secrets = re.compile(rb'ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|sk-[A-Za-z0-9_-]{36,}|-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----')
    binary_sources = {
        'SHODAN Stat Editor Offline.exe': root / 'offline/launcher/SHODAN Stat Editor Offline.exe',
        'lua51.dll': root / 'offline/runtime/lua51.dll',
        'libsodium.dll': root / 'offline/runtime/libsodium.dll',
        'shodan_hash.dll': root / 'offline/launcher/shodan_hash.dll',
    }
    dev_block = re.compile(r'[ \t]*--\[\[DEV\]\].*?--\[\[/DEV\]\][^\n]*\n', re.S)
    with zipfile.ZipFile(args.archive) as archive:
        assert archive.testzip() is None, 'Archive checksum failure'
        names = archive.namelist()
        assert len({n.casefold() for n in names}) == len(names), 'Duplicate archive entries'
        for name in names:
            assert name.startswith(top) and '\\' not in name, f'Unexpected archive path: {name}'
            path = PurePosixPath(name[len(top):])
            assert not path.is_absolute() and '..' not in path.parts
            assert path.parts, name
            relative = path.as_posix()
            assert path.parts[0] in {'app', 'Names', 'Presets', 'docs', 'licenses', 'README.txt', *binary_sources}, name
            assert not any(p.lower() in {'data', 'originals', 'logs', '.git', '.test-work', '__pycache__'} for p in path.parts), name
            if path.parts[0] == 'Presets':
                assert relative == 'Presets/README.txt', f'Personal preset in archive: {name}'
            if path.parts[0] == 'Names':
                source = root / 'offline' / relative
                assert source.is_file() and archive.read(name) == source.read_bytes(), f'Non-default names: {name}'
            assert path.suffix.lower() not in {'.sav', '.dl_bin', '.dl_typelib', '.dmp', '.log', '.tmp', '.lnk', '.xlsx', '.xlsm', '.pdb'}, name
            if path.suffix.lower() in {'.exe', '.dll'}:
                assert relative in binary_sources, name
            elif path.suffix.lower() in {'.lua', '.json', '.txt', '.md', '.tsv'}:
                assert not secrets.search(archive.read(name)), f'Credential-shaped text in {name}'
        for relative, source in binary_sources.items():
            assert archive.read(top + relative) == source.read_bytes(), relative
        assert archive.read(top + 'app/stat_editor.lua') == (root / 'src/stat_editor_offline.lua').read_bytes()
        for source in (root / 'offline').glob('*.lua'):
            expected = dev_block.sub('', source.read_text(encoding='utf-8'))
            assert archive.read(top + 'app/' + source.name).decode('utf-8') == expected, source.name
        for required in ['README.txt', 'docs/README.md', 'docs/PORTABLE_DATA.md', 'Presets/README.txt',
                         'licenses/LICENSE', 'licenses/THIRD-PARTY-NOTICES.txt', 'app/parameter_preferences.lua', 'app/user_paths.lua']:
            assert top + required in names, required
        metadata = dict(line.split('=', 1) for line in archive.read(top + 'app/build.txt').decode().splitlines() if '=' in line)
        assert metadata['commit'] == args.commit and metadata['channel'] == args.channel, metadata
        assert re.fullmatch(r'\d{8}-\d{6}', metadata['built']), 'Missing window build stamp'
    print(f'PASS clean release ZIP: {len(names)} files; exact source/runtime, portable modules, no personal data; SHA256 {hashlib.sha256(args.archive.read_bytes()).hexdigest()}')


if __name__ == '__main__':
    main()
