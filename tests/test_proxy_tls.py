"""Loopback CRL lifecycle and privacy checks; no external network or CA import."""
import json
import socket
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock, patch
from urllib.error import HTTPError
from urllib.request import ProxyHandler, build_opener

from test_galactic_effect_proxy import proxy


class ProxyTLS(unittest.TestCase):
    def test_crl_is_exact_path_loopback_and_stops_with_service(self):
        store = Mock(default_crl=b'test-only-crl')
        store.get_cert.return_value.cert.to_pem.return_value = b'test-only-public-leaf'
        x509 = SimpleNamespace(DNSName=lambda host: ('dns', host))
        with patch.dict('sys.modules', {'cryptography': SimpleNamespace(x509=x509)}):
            service = proxy.LocalRevocationService(store)
        try:
            self.assertEqual(service.server.server_address[0], '127.0.0.1')
            store.get_cert.assert_called_once_with(proxy.HOST, [('dns', proxy.HOST)], crl_url=service.url)
            store.add_cert.assert_called_once_with(store.get_cert.return_value, proxy.HOST)
            self.assertEqual(service.certificate, b'test-only-public-leaf')
            opener = build_opener(ProxyHandler({}))
            with opener.open(service.url, timeout=2) as response:
                self.assertEqual(response.headers['Content-Type'], 'application/pkix-crl')
                self.assertEqual(response.read(), store.default_crl)
            for suffix in ('/mitmproxy-ca.pem', '/ca.crl?file=private', '/../../private'):
                with self.subTest(path=suffix), self.assertRaises(HTTPError) as error:
                    opener.open(service.url.removesuffix('/ca.crl') + suffix, timeout=2)
                with error.exception:
                    self.assertEqual(error.exception.code, 404)
            address = service.server.server_address
        finally:
            service.close()
        self.assertFalse(service.thread.is_alive())
        with self.assertRaises(OSError):
            socket.create_connection(address, timeout=1)

    def test_session_leaf_is_pinned_with_supported_certs_option(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            addon = proxy.EffectDefinitionsAddon(root / 'definitions.json', root / 'assignments.json')
            context = SimpleNamespace(master=Mock(), options=Mock())
            revocation = Mock(certificate=b'public-leaf-with-cdp')
            with patch.dict('sys.modules', {'mitmproxy': SimpleNamespace(ctx=context)}), \
                    patch.object(proxy, 'LocalRevocationService', return_value=revocation) as factory:
                addon.prepare_revocation()
            factory.assert_called_once_with(context.master.addons.get.return_value.certstore)
            leaf = root / 'WarProxy/session-api-cert.pem'
            self.assertEqual(leaf.read_bytes(), revocation.certificate)
            context.options.update.assert_called_once_with(certs=[proxy.HOST + '=' + str(leaf)])
            addon.done()
            revocation.close.assert_called_once()

    def test_tls_diagnostics_are_api_scoped_and_never_persist_raw_errors(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            addon = proxy.EffectDefinitionsAddon(root / 'definitions.json', root / 'assignments.json')

            def event(host, error):
                return SimpleNamespace(context=SimpleNamespace(
                    client=SimpleNamespace(sni=host, error=error), server=SimpleNamespace(sni=None, error=None)))

            addon.tls_failed_client(event('login.example', 'unrelated secret'))
            self.assertEqual(addon.connections['client_tls_failed'], 0)
            addon.tls_failed_client(event(proxy.HOST, 'revocation failure: secret-token-and-url'))
            self.assertEqual(addon.connections['client_tls_failed'], 1)
            self.assertEqual(addon.connections['failure_kind'], 'revocation')
            addon.tls_established_client(event(proxy.HOST, None))
            self.assertEqual(addon.connections['client_tls_ok'], 1)
            diagnostics = json.dumps(addon.connections) + (root / 'WarProxy/planet_effect_status.json').read_text(encoding='utf-8')
            self.assertNotIn('secret', diagnostics)


if __name__ == '__main__':
    unittest.main()
