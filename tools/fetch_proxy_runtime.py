"""Fetch the pinned official portable proxy core; no install, CA or proxy changes."""
import hashlib
import json
import urllib.request
import zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
VERSION='12.3.1'
URL=f'https://downloads.mitmproxy.org/{VERSION}/mitmproxy-{VERSION}-windows-x86_64.zip'
ARCHIVE_SHA='336c03e7215876af329f57c44b1b738cfb22cd29dc7cd4c0714f15c7648af829'
EXE_SHA='e2f05da6385d8c76c2f5b7b23b5d0f7e2c23483b5ece99fe1f4e3b0c04c5f8b5'

def main():
    folder=ROOT/'offline/runtime/network';folder.mkdir(parents=True,exist_ok=True)
    archive=folder/'download.zip'
    executable=folder/'mitmdump.exe'
    if not executable.exists() or hashlib.sha256(executable.read_bytes()).hexdigest()!=EXE_SHA:
        with urllib.request.urlopen(URL,timeout=30) as response,archive.open('wb') as output:
            while block:=response.read(1024*1024):output.write(block)
        assert hashlib.sha256(archive.read_bytes()).hexdigest()==ARCHIVE_SHA,'Proxy archive hash mismatch'
        with zipfile.ZipFile(archive) as z:
            assert z.testzip() is None
            executable.write_bytes(z.read('mitmdump.exe'))
        assert hashlib.sha256(executable.read_bytes()).hexdigest()==EXE_SHA,'Proxy executable hash mismatch'
        archive.unlink()
    with urllib.request.urlopen(f'https://raw.githubusercontent.com/mitmproxy/mitmproxy/v{VERSION}/LICENSE',timeout=20) as response:
        license=response.read()
    (folder/'LICENSE.txt').write_bytes(license)
    (folder/'runtime.json').write_text(json.dumps(dict(version=VERSION,source=URL,archive_sha256=ARCHIVE_SHA,
        mitmdump_sha256=EXE_SHA),indent=2)+'\n',encoding='utf-8')
    print('Portable mitmdump '+VERSION+' verified: '+EXE_SHA)

if __name__=='__main__':main()
