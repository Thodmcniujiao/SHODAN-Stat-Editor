"""Optional mitmproxy addon for the editor's portable effect-definition plan.

Optional definition overrides and additive client-side planet assignments.
Assignments only append to Status.planetActiveEffects; no ownership, campaigns,
WarInfo, authentication, server writes or request-body changes.
Importing/checking this module needs only Python's standard library.
"""
from __future__ import annotations

import argparse
import asyncio
import copy
import json
import math
import os
import ssl
import hashlib
import time
from collections import Counter
from pathlib import Path
from urllib.parse import urlsplit
from urllib.request import ProxyHandler, build_opener

HOST = 'api.live.prod.thehelldiversgame.com'
FIELDS = {'gameplayEffectId32', 'effectType', 'flags', 'nameHash',
          'descriptionFluffHash', 'descriptionGamePlayLongHash',
          'descriptionGamePlayShortHash', 'valueTypes', 'values'}
MAX_BYTES = 4 * 1024 * 1024
CATALOG_URL = 'https://' + HOST + '/api/WarSeason/GalacticWarEffects'


def valid_value(key, value):
    if key not in FIELDS:
        return False
    if key in {'values', 'valueTypes'}:
        if not isinstance(value, list) or len(value) > 16:
            return False
        for n in value:
            if type(n) not in (int, float):
                return False
            try:
                if not math.isfinite(n):
                    return False
            except OverflowError:
                return False
            if key == 'valueTypes' and (type(n) is not int or not 0 <= n <= 0xFFFFFFFF):
                return False
        return True
    return type(value) is int and 0 <= value <= 0xFFFFFFFF


def valid_definition(row):
    return (isinstance(row, dict) and type(row.get('id')) is int and row['id'] > 0
            and all(key in row and valid_value(key, row[key]) for key in FIELDS))


def load_plan(path):
    """Malformed files disable the plan; do not overwrite or partially recover."""
    try:
        with Path(path).open('rb') as stream:
            raw = stream.read(MAX_BYTES + 1)
        if len(raw) > MAX_BYTES:
            return None
        plan = json.loads(raw.decode('utf-8-sig'))
        if (not isinstance(plan, dict) or type(plan.get('version')) is not int
                or plan['version'] != 1 or type(plan.get('enabled')) is not bool
                or not isinstance(plan.get('effects'), dict)):
            return None
        return plan
    except (OSError, ValueError, UnicodeError):
        return None


def patch_definitions(document, plan):
    """Return (new document, changed IDs); stale definitions fail closed per ID.

    Comparing the full original definition prevents a saved ID from silently
    changing meaning after an update. Do not replace new IDs, remove server
    fields or allow a plan to rewrite the catalogue's identity namespace.
    """
    if (not isinstance(plan, dict) or type(plan.get('version')) is not int
            or plan['version'] != 1 or plan.get('enabled') is not True
            or not isinstance(plan.get('effects'), dict)):
        return document, []
    rows = document.get('galacticEffects') if isinstance(document, dict) else document
    if not isinstance(rows, list):
        return document, []
    counts = Counter(row['id'] for row in rows
                     if isinstance(row, dict) and type(row.get('id')) is int)
    output, changed = copy.deepcopy(document), []
    target = output['galacticEffects'] if isinstance(output, dict) else output
    for row, replacement in zip(rows, target):
        if not valid_definition(row) or counts[row['id']] != 1:
            continue
        entry = plan['effects'].get(str(row['id']))
        if not isinstance(entry, dict) or entry.get('enabled') is not True:
            continue
        base, changes = entry.get('base'), entry.get('changes')
        if (not valid_definition(base) or base['id'] != row['id']
                or not isinstance(changes, dict)
                or not all(valid_value(k, v) for k, v in changes.items())):
            continue
        # Strict type checks above reject bool-as-int and non-finite numbers.
        if any(base[key] != row[key] for key in FIELDS):
            continue
        different = {k: v for k, v in changes.items() if v != row[k]}
        if different:
            replacement.update(different)
            changed.append(row['id'])
    return (output if changed else document), changed


def matches(request):
    if request.method != 'GET':
        return False
    try:
        url = urlsplit(request.pretty_url)
        parts = url.path.rstrip('/').lower().split('/')
        path_ok = (parts == ['', 'api', 'warseason', 'galacticwareffects']
                   or len(parts) == 5 and parts[:3] == ['', 'api', 'warseason']
                   and parts[3].isdigit() and parts[4] == 'galacticwareffects')
        return url.scheme == 'https' and url.hostname == HOST and url.port in (None, 443) and path_ok
    except (ValueError, AttributeError):
        return False


def status_war_id(request):
    if request.method != 'GET':
        return None
    try:
        url = urlsplit(request.pretty_url)
        parts = url.path.rstrip('/').lower().split('/')
        if (url.scheme == 'https' and url.hostname == HOST and url.port in (None, 443)
                and len(parts) == 5 and parts[:3] == ['', 'api', 'warseason']
                and parts[3].isdigit() and parts[4] == 'status'):
            return int(parts[3])
    except (ValueError, AttributeError):
        pass
    return None


def catalogue(document):
    rows = document.get('galacticEffects') if isinstance(document, dict) else document
    if not isinstance(rows, list) or not rows or not all(valid_definition(row) for row in rows):
        raise ValueError('实时词条目录格式不兼容，未添加词条。')
    result = {row['id']: row for row in rows}
    if len(result) != len(rows):
        raise ValueError('实时词条目录含重复 ID，未添加词条。')
    return result


def load_assignments(path):
    # Assignments have their own schema, independent of definition overrides.
    try:
        with Path(path).open('rb') as stream:
            raw = stream.read(MAX_BYTES + 1)
        if len(raw) > MAX_BYTES:
            return None
        plan = json.loads(raw.decode('utf-8-sig'))
        if (not isinstance(plan, dict) or type(plan.get('version')) is not int or plan['version'] != 1
                or type(plan.get('enabled')) is not bool or type(plan.get('war_id')) is not int
                or not all(isinstance(plan.get(k), dict) for k in ('targets', 'definitions', 'icon_pairs'))):
            return None
        return plan
    except (OSError, ValueError, UnicodeError):
        return None


def patch_status(document, plan, current_catalog, war_id):
    """Atomic, additive rewrite. The supplied catalogue must be live this session."""
    if not plan or plan.get('enabled') is not True:
        return document, 0
    if plan.get('war_id') != war_id:
        raise ValueError('战争编号已变化，请更新星球目录后重新设置。')
    if not current_catalog:
        raise ValueError('等待本次实时词条目录，战况保持原样。')
    if not isinstance(document, dict):
        raise ValueError('战况结构不兼容，未添加词条。')
    planets, entries = document.get('planetStatus'), document.get('planetActiveEffects')
    if not isinstance(planets, list) or not isinstance(entries, list):
        raise ValueError('战况缺少星球／词条列表，未添加词条。')
    if any(not isinstance(p, dict) or type(p.get('index')) is not int for p in planets):
        raise ValueError('星球条目格式不兼容，未添加词条。')
    known = {p['index'] for p in planets}
    if len(known) != len(planets):
        raise ValueError('战况含重复星球编号，未添加词条。')
    pairs = set()
    for entry in entries:
        if (not isinstance(entry, dict) or type(entry.get('index')) is not int
                or type(entry.get('galacticEffectId')) is not int):
            raise ValueError('原有词条条目格式不兼容，未添加词条。')
        pairs.add((entry['index'], entry['galacticEffectId']))

    def validate_id(effect):
        row = current_catalog.get(effect)
        base = plan['definitions'].get(str(effect))
        if not row or not isinstance(base, dict) or any(
                type(base.get(k)) is not int or base[k] != row[k] for k in ('effectType', 'nameHash')):
            raise ValueError(f'词条 {effect} 缺失或目录定义已更新，请重载／更新目录。')
        return row

    additions = []
    for key, target in plan['targets'].items():
        if (not isinstance(key, str) or not key.isascii() or not key.isdigit()
                or str(int(key)) != key or not isinstance(target, dict)
                or type(target.get('include_icons')) is not bool or not isinstance(target.get('effects'), list)):
            raise ValueError('星球词条计划格式错误，未添加词条。')
        planet = int(key)
        requested = target['effects']
        if not requested:
            continue
        if planet not in known:
            raise ValueError(f'星球 {planet} 不在本次战况中，未添加词条。')
        if any(type(e) is not int or e <= 0 for e in requested):
            raise ValueError('词条编号格式错误，未添加词条。')
        expanded = []
        for effect in requested:
            row = validate_id(effect)
            expanded.append(effect)
            paired = plan['icon_pairs'].get(str(effect))
            if target['include_icons'] and paired is not None:
                if type(paired) is not int:
                    raise ValueError('配对图标编号格式错误，未添加词条。')
                icon = validate_id(paired)
                if row['effectType'] != 40 or icon['effectType'] != 71:
                    raise ValueError('生效／图标配对类型已变化，未添加词条。')
                expanded.append(paired)
        for effect in expanded:
            if (planet, effect) not in pairs:
                additions.append({'index': planet, 'galacticEffectId': effect})
                pairs.add((planet, effect))
    if not additions:
        return document, 0
    output = copy.deepcopy(document)
    output['planetActiveEffects'] = output['planetActiveEffects'] + additions
    return output, len(additions)


def fetch_catalogue():
    # A public GET with no game headers, cookies or credentials. Avoid proxy loops.
    opener = build_opener(ProxyHandler({}))
    with opener.open(CATALOG_URL, timeout=10) as response:
        final = urlsplit(response.geturl())
        if final.scheme != 'https' or final.hostname != HOST:
            raise ValueError('Unexpected catalogue host')
        raw = response.read(MAX_BYTES + 1)
    if len(raw) > MAX_BYTES:
        raise ValueError('Catalogue too large')
    return catalogue(json.loads(raw))


def default_plan():
    directory = Path(__file__).resolve().parents[1]  # offline/ or app/
    root = directory.parent if directory.name == 'app' else directory
    return root / 'Data/galactic_effect_overrides.json'


class LocalRevocationService:
    """An exact-path loopback CRL endpoint signed by this copy's existing CA.

    Schannel checks revocation even when this CA is in CurrentUser/Root. Give
    the API leaf a reachable CDP; do not disable peer or revocation validation.
    Based on the same mitmproxy CertStore API used by 127MU's GPL-3.0 addon.
    """
    def __init__(self, certstore, host=HOST):
        from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
        from threading import Thread
        from cryptography import x509
        crl = certstore.default_crl

        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                if self.path != '/ca.crl':
                    self.send_error(404)
                    return
                self.send_response(200)
                self.send_header('Content-Type', 'application/pkix-crl')
                self.send_header('Content-Length', str(len(crl)))
                self.end_headers()
                self.wfile.write(crl)

            def log_message(self, *args):
                pass

        self.server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        self.server.daemon_threads = True
        self.url = f'http://127.0.0.1:{self.server.server_port}/ca.crl'
        try:
            entry = certstore.get_cert(host, [x509.DNSName(host)], crl_url=self.url)
            certstore.add_cert(entry, host)
            self.certificate = entry.cert.to_pem()
            self.thread = Thread(target=self.server.serve_forever, daemon=True)
            self.thread.start()
        except BaseException:
            self.server.server_close()
            raise

    def close(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)


class EffectDefinitionsAddon:
    def __init__(self, path=None, assignments=None):
        self.path = Path(path) if path else default_plan()
        self.assignments = Path(assignments) if assignments else self.path.with_name('planet_effects.json')
        self.current_catalog = None
        self.catalogue_at = 0
        self.catalogue_task = None
        self.retry_at = 0
        self.heartbeat_task = None
        self.session_started = time.time()
        self.revocation_service=None
        self.connections={'client_tls_ok':0,'client_tls_failed':0,'server_tls_failed':0,
                          'requests':0,'responses':0,'last_status':0,'failure_kind':''}

    def load(self, loader):
        loader.add_option('shodan_effect_definitions', str, str(self.path),
                          'Portable SHODAN effect-definition plan')
        loader.add_option('shodan_planet_effects', str, str(self.assignments),
                          'Portable additive planet effect assignments')

    def configure(self, updated):
        if 'shodan_effect_definitions' in updated:
            from mitmproxy import ctx
            self.path = Path(ctx.options.shodan_effect_definitions)
        if 'shodan_planet_effects' in updated:
            from mitmproxy import ctx
            self.assignments = Path(ctx.options.shodan_planet_effects)

    def report(self, state, message, added=0):
        try:
            path = self.assignments.parent / 'WarProxy/planet_effect_status.json'
            path.parent.mkdir(parents=True, exist_ok=True)
            temporary = path.with_suffix('.json.tmp')
            temporary.write_text(json.dumps(dict(state=state, message=message, added=added,
                                                 updated=time.time()), ensure_ascii=False), encoding='utf-8')
            temporary.replace(path)
        except OSError:
            pass

    async def refresh_catalogue(self):
        try:
            self.current_catalog = await asyncio.to_thread(fetch_catalogue)
            self.catalogue_at = time.monotonic()
            self.report('ready', '实时词条目录已取得，等待游戏战况响应。')
        except Exception:
            self.current_catalog = None
            self.report('catalogue_error', '实时词条目录获取失败；原战况保持不变，稍后重试。')
        finally:
            self.retry_at = time.monotonic() + 30

    def schedule_catalogue(self):
        if (self.catalogue_task and not self.catalogue_task.done()) or time.monotonic() < self.retry_at:
            return
        try:
            loop = asyncio.get_running_loop()
        except RuntimeError:
            return
        self.catalogue_task = loop.create_task(self.refresh_catalogue())

    def prepare_revocation(self):
        from mitmproxy import ctx
        self.revocation_service = LocalRevocationService(ctx.master.addons.get('tlsconfig').certstore)
        session = self.assignments.parent / 'WarProxy/session-api-cert.pem'
        session.parent.mkdir(parents=True, exist_ok=True)
        session.write_bytes(self.revocation_service.certificate)
        # Pin the API leaf with its CDP through the supported certs option. A
        # later TLSConfig configure event must not replace it with a plain leaf.
        ctx.options.update(certs=[HOST + '=' + str(session)])

    def running(self):
        self.prepare_revocation()
        stop=self.assignments.parent/'WarProxy/stop.request'
        try:stop.unlink(missing_ok=True)
        except OSError:pass
        self.heartbeat_task=asyncio.get_running_loop().create_task(self.heartbeat())
        plan = load_assignments(self.assignments)
        if plan and plan['enabled']:
            self.schedule_catalogue()

    async def heartbeat(self):
        from mitmproxy import ctx
        import ctypes
        kernel=ctypes.WinDLL('kernel32',use_last_error=True)
        kernel.GetCurrentProcess.restype=ctypes.c_void_p
        kernel.GetProcessTimes.argtypes=[ctypes.c_void_p,ctypes.c_void_p,ctypes.c_void_p,ctypes.c_void_p,ctypes.c_void_p]
        created,exited,cpu,user=(ctypes.c_ulonglong() for _ in range(4))
        kernel.GetProcessTimes(kernel.GetCurrentProcess(),ctypes.byref(created),ctypes.byref(exited),ctypes.byref(cpu),ctypes.byref(user))
        folder=self.assignments.parent/'WarProxy';folder.mkdir(parents=True,exist_ok=True)
        while True:
            ready=not (folder/'stop.request').exists()
            now=time.time();defs=load_plan(self.path);assignments=load_assignments(self.assignments)
            enabled=bool(defs and defs['enabled'] or assignments and assignments['enabled'])
            thumb=''
            try:
                pem=(folder/'mitmproxy-ca-cert.pem').read_text(encoding='ascii')
                thumb=hashlib.sha1(ssl.PEM_cert_to_DER_cert(pem)).hexdigest()
            except (OSError,ValueError):pass
            health=dict(ready=ready,pid=os.getpid(),started=str(created.value),updated=now,
                        port=ctx.options.listen_port,certificate_sha1=thumb,enabled=enabled,
                        connections=dict(self.connections),crl_url=self.revocation_service.url if self.revocation_service else '')
            for filename,raw in [
                ('proxy_health.json',json.dumps(health)),
                ('steam-proxy.ini',f'[proxy]\nready={int(ready and enabled)}\nport={ctx.options.listen_port}\npid={os.getpid()}\nstarted={created.value}\nupdated={now}\ncertificate_sha1={thumb}\n')]:
                try:
                    dest=folder/filename;temp=dest.with_suffix(dest.suffix+'.tmp')
                    temp.write_text(raw,encoding='utf-8');temp.replace(dest)
                except OSError:pass
            if not ready:
                ctx.master.shutdown();return
            if enabled and not self.current_catalog:self.schedule_catalogue()
            await asyncio.sleep(1)

    def done(self):
        if self.heartbeat_task:self.heartbeat_task.cancel()
        if self.catalogue_task:self.catalogue_task.cancel()
        if self.revocation_service:self.revocation_service.close();self.revocation_service=None

    @staticmethod
    def api_tls(data):
        context=getattr(data,'context',None)
        return any(getattr(getattr(context,side,None),'sni',None)==HOST for side in ('client','server'))

    @staticmethod
    def tls_failure_kind(data):
        context=getattr(data,'context',None)
        text=' '.join(str(getattr(getattr(context,side,None),'error','') or '') for side in ('client','server')).lower()
        for words,name in [(['revocation','revoked'],'revocation'),(['unknown ca','certificate verify','certificate_unknown','unknown_ca'],'trust'),
                           (['timeout','timed out'],'timeout'),(['protocol version','no shared cipher'],'protocol'),(['reset','closed','eof'],'disconnect')]:
            if any(word in text for word in words):return name
        return 'tls'

    def tls_failed_client(self,data):
        if self.api_tls(data):
            self.connections['client_tls_failed']+=1;self.connections['failure_kind']=self.tls_failure_kind(data)
            self.report('client_tls_error','游戏 API 客户端 TLS 握手失败；尚未收到可改写的战况。')

    def tls_failed_server(self,data):
        if self.api_tls(data):
            self.connections['server_tls_failed']+=1;self.connections['failure_kind']=self.tls_failure_kind(data)
            self.report('server_tls_error','游戏 API 上游 TLS 握手失败；未关闭服务器证书验证。')

    def tls_established_client(self,data):
        if self.api_tls(data):self.connections['client_tls_ok']+=1

    def request(self, flow):
        local_url=urlsplit(flow.request.pretty_url)
        if (flow.request.method=='GET' and local_url.scheme=='http' and local_url.hostname=='127.0.0.1'
                and local_url.path=='/__shodan_health'):
            from mitmproxy import http
            health=self.assignments.parent/'WarProxy/proxy_health.json'
            try:body=health.read_bytes()
            except OSError:body=b'{}'
            flow.response=http.Response.make(200,body,{'Content-Type':'application/json','Cache-Control':'no-store'});return
        if local_url.hostname==HOST:self.connections['requests']+=1
        status = status_war_id(flow.request)
        if not matches(flow.request) and status is None:
            return
        plan = load_assignments(self.assignments) if status is not None else load_plan(self.path)
        if plan and plan['enabled']:
            # Require an actual response, rather than inventing a cached body.
            for key in ('if-none-match', 'if-modified-since'):
                flow.request.headers.pop(key, None)
        if status is not None and plan and plan['enabled'] and (not self.current_catalog or time.monotonic()-self.catalogue_at>3600):
            self.current_catalog=None;self.schedule_catalogue()

    def response(self, flow):
        if urlsplit(flow.request.pretty_url).hostname==HOST and flow.response is not None:
            self.connections['responses']+=1;self.connections['last_status']=flow.response.status_code
        status = status_war_id(flow.request)
        is_catalogue = matches(flow.request)
        if (not is_catalogue and status is None) or flow.response is None or flow.response.status_code != 200:
            return
        try:
            raw = flow.response.get_text(strict=True)
            if len(raw.encode('utf-8')) > MAX_BYTES:
                return
            document = json.loads(raw)
            if is_catalogue:
                self.current_catalog=catalogue(document);self.catalogue_at=time.monotonic()
                output, changed = patch_definitions(document, load_plan(self.path))
            else:
                plan=load_assignments(self.assignments)
                if not plan or not plan['enabled']:
                    return
                if not self.current_catalog or time.monotonic()-self.catalogue_at>3600:
                    self.current_catalog=None;self.schedule_catalogue()
                    self.report('waiting', '等待本次实时词条目录，战况保持原样。');return
                output, changed = patch_status(document,plan,self.current_catalog,status)
                self.report('applied', f'已处理游戏战况，本次追加 {changed} 条；尚需在游戏中确认实际效果。',changed)
            if not changed:
                return
            serialized = json.dumps(output, ensure_ascii=False, separators=(',', ':'), allow_nan=False)
        except (ValueError, TypeError, UnicodeError, OverflowError) as error:
            if status is not None:
                self.report('error', str(error))
            return
        flow.response.text = serialized
        for key in ('etag', 'last-modified', 'content-md5', 'digest'):
            flow.response.headers.pop(key, None)
        flow.response.headers['cache-control'] = 'no-store'


addons = [EffectDefinitionsAddon()]

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check-config', type=Path, default=default_plan(), const=default_plan(), nargs='?')
    options = parser.parse_args()
    config = load_plan(options.check_config)
    if config is None:
        raise SystemExit('Missing or invalid effect-definition plan')
    enabled = sum(isinstance(e, dict) and e.get('enabled') is True for e in config['effects'].values())
    print(f'Master enabled: {config["enabled"]}; enabled IDs: {enabled}. No network requests performed.')
