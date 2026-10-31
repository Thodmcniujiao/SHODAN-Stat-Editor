"""Launch a harmless argv/env probe through the real Windows Steam wrapper."""
import json
import os
import shutil
import socket
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(sys.platform == 'win32', 'Windows wrapper')
class Wrapper(unittest.TestCase):
    def test_arguments_working_directory_and_child_only_environment(self):
        with tempfile.TemporaryDirectory(prefix='shodan-wrapper-') as temp:
            folder = Path(temp)
            network = folder / 'program/app/network'; network.mkdir(parents=True)
            data = folder / 'program/Data'; data.mkdir()
            source = ROOT / 'offline/network/run_game_with_effect_proxy.ps1'
            script = network / source.name; shutil.copyfile(source, script)
            child = folder / 'argument probe.py'
            child.write_text('import json,os,sys\nfrom pathlib import Path\n'
                             'Path(sys.argv[1]).write_text(json.dumps(dict(args=sys.argv[2:],cwd=os.getcwd(),'
                             'proxy=os.environ.get("HTTPS_PROXY"),bypass=os.environ.get("NO_PROXY"))),encoding="utf-8")\n',
                             encoding='utf-8')
            arguments = ['with spaces', 'quote"inside', 'end slash\\', '', 'C:\\space path\\']
            env = dict(os.environ, HTTPS_PROXY='original-parent-proxy', NO_PROXY='original-bypass')
            for definition_on, assignment_on in [(False,False),(True,False),(False,True),(True,True)]:
                enabled = definition_on or assignment_on
                with self.subTest(definition_on=definition_on, assignment_on=assignment_on), socket.socket() as listener:
                    listener.bind(('127.0.0.1', 0)); listener.listen()
                    port = listener.getsockname()[1]
                    (data / 'galactic_effect_overrides.json').write_text(
                        json.dumps(dict(version=1, enabled=definition_on, effects={})), encoding='utf-8')
                    (data / 'planet_effects.json').write_text(
                        json.dumps(dict(version=1, enabled=assignment_on, war_id=801, targets={})), encoding='utf-8')
                    output = folder / 'child.json'
                    command = ['powershell.exe', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
                               '-File', str(script), '-Port', str(port), str(Path(sys.executable)),
                               str(child), str(output), *arguments]
                    result = subprocess.run(command, cwd=folder, env=env, capture_output=True, text=True, timeout=30)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    actual = json.loads(output.read_text(encoding='utf-8'))
                    self.assertEqual(actual['args'], arguments)
                    self.assertEqual(Path(actual['cwd']), folder)
                    self.assertEqual(actual['proxy'], f'http://127.0.0.1:{port}' if enabled else 'original-parent-proxy')
                    self.assertIn('original-bypass', actual['bypass'])
                    if enabled:
                        self.assertIn('playfabapi.com', actual['bypass'])
                    self.assertEqual(env['HTTPS_PROXY'], 'original-parent-proxy')


if __name__ == '__main__':
    unittest.main()
