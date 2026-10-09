"""Exercise the launcher from a relocated checkout without calling Codex."""
import importlib.util
import io
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from types import SimpleNamespace
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]


class LauncherTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.outside = Path(self.temp.name)
        self.repo = self.outside / 'renamed checkout'
        for relative in ('scripts/start_accelerator.py',
                         'prompts/model_hardware_accelerator.en.txt',
                         'prompts/model_hardware_accelerator.ko.txt',
                         'config/hardware/zcu104.json'):
            target = self.repo / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / relative, target)
        self.script = self.repo / 'scripts/start_accelerator.py'

    def launch(self, hardware, language='en'):
        return subprocess.run(
            [sys.executable, str(self.script), '--model', 'org/model',
             '--hardware', str(hardware), '--language', language, '--render-only'],
            cwd=self.outside, text=True, capture_output=True, check=False)

    def test_relocated_checkout_from_outside_directory(self):
        result = self.launch('config/hardware/zcu104.json')
        self.assertEqual(result.returncode, 0, result.stderr)
        prompt = next((self.repo / 'build/prompt_runs').glob('*.txt')).read_text()
        self.assertIn(f'Repository: {self.repo}', prompt)
        self.assertIn('Model: org/model', prompt)
        self.assertIn('Phase for this run: inspect_and_propose', prompt)
        self.assertIn('xczu7ev-ffvc1156-2-e', prompt)
        self.assertNotIn('{{REPO_ROOT}}', prompt)

    def test_korean_prompt_and_snapshot(self):
        result = self.launch('config/hardware/zcu104.json', language='ko')
        self.assertEqual(result.returncode, 0, result.stderr)
        prompt = next((self.repo / 'build/prompt_runs').glob('accelerator_ko_*.txt')).read_text()
        self.assertIn('모델: org/model', prompt)
        self.assertIn('[제공된 하드웨어 스펙 스냅샷]', prompt)
        self.assertIn('사용자에게는 한국어로', prompt)

    def test_external_hardware_file(self):
        hardware = self.outside / 'custom board.txt'
        hardware.write_text('FPGA: example\nDDR: 1 GiB\n', encoding='utf-8')
        result = self.launch(hardware)
        self.assertEqual(result.returncode, 0, result.stderr)
        prompt = next((self.repo / 'build/prompt_runs').glob('*.txt')).read_text()
        self.assertIn(hardware.read_text(), prompt)

    def test_missing_hardware_rejected_before_writing(self):
        result = self.launch('missing.json')
        self.assertEqual(result.returncode, 2)
        self.assertIn('not a file', result.stderr)
        self.assertFalse((self.repo / 'build').exists())

    def test_codex_receives_checkout_and_literal_prompt(self):
        spec = importlib.util.spec_from_file_location('launcher', self.script)
        launcher = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(launcher)
        with redirect_stdout(io.StringIO()), \
             patch.object(launcher.shutil, 'which', return_value='/mock/codex'), \
             patch.object(launcher.sys.stdin, 'isatty', return_value=True), \
             patch.object(launcher.sys.stdout, 'isatty', return_value=True), \
             patch.object(launcher.subprocess, 'run',
                          return_value=SimpleNamespace(returncode=7)) as run:
            code = launcher.main(['--model', 'org/model; $(literal)',
                                  '--hardware', 'config/hardware/zcu104.json'])
        self.assertEqual(code, 7)
        command = run.call_args.args[0]
        self.assertEqual(command[:3], ['/mock/codex', '--cd', str(self.repo)])
        self.assertIn('org/model; $(literal)', command[-1])
        self.assertFalse(run.call_args.kwargs.get('shell', False))
