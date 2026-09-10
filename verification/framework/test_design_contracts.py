"""Executable contract lifecycle and negative gates in isolated workspaces."""
import copy
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('design_contracts', ROOT / 'scripts/design_contracts.py')
DC = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(DC)


class DesignContractsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='llm2rtl-contract-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for folder in ('contracts', 'config', 'docs', 'scripts', 'src', 'ip'):
            shutil.copytree(ROOT / folder, self.root / folder)
        self.index = DC.init(self.root, 'test', 'r01', 'config/hardware/zcu104.json', ['gemm'])

    def read(self, file):
        return json.loads((self.root / file).read_text())

    def write(self, file, value):
        (self.root / file).write_text(json.dumps(value, indent=2) + '\n')

    def fill(self):
        # Deliberately bounded synthetic contracts: tests structural gating, not HDL correctness.
        na = {'not_applicable': True, 'reason': 'Synthetic loader regression only',
              'approved_by': 'test-parent'}
        def resolve(v):
            if v is None:
                return copy.deepcopy(na)
            if isinstance(v, dict):
                return {k: resolve(x) for k, x in v.items()}
            if isinstance(v, list):
                return [resolve(x) for x in v]
            return v
        index = self.read(self.index)
        for file in list(index['design_contracts'].values()) + list(index['module_contracts'].values()):
            self.write(file, resolve(self.read(file)))
        module = index['module_contracts']['gemm']
        doc = self.read(module)
        doc['variant'] = json.loads((ROOT / 'verification/framework/fixtures/projection_gemm_ws32_w4a4_acc16.json').read_text())
        self.write(module, doc)
        index['transport'] = {
            'ddr_local_transfers': True, 'engine': DC.ENGINE,
            'interface_contract': DC.ENGINE + '/interface_contract.json',
            'command_owner': 'model_scheduler', 'error_policy_owner': 'model_scheduler',
            'connections': {name: {'source': name + '_producer', 'sink': name + '_consumer'}
                            for name in ('command', 'completion', 'ddr', 'local_memory')},
            'integration_verification': 'Synthetic only; real integration must audit RTL endpoints and source closure'
        }
        index['verification_plan'] = 'Unit test scope only; no RTL or board claim'
        self.write(self.index, index)

    def frozen(self):
        self.fill()
        return DC.freeze(self.root, self.index, 'test-parent')

    def test_transport_invalid_declarations_block_freeze(self):
        self.fill()
        original = self.read(self.index)
        for field, value in (('engine', 'custom_dma'), ('command_owner', 'gemm'),
                             ('error_policy_owner', 'engine'), ('connections', {}),
                             ('interface_contract', 'other.json'),
                             ('ddr_local_transfers', 'false'),
                             ('integration_verification', {'not_applicable': True})):
            with self.subTest(field=field):
                index = copy.deepcopy(original)
                index['transport'][field] = value
                self.write(self.index, index)
                with self.assertRaises(DC.ContractError):
                    DC.freeze(self.root, self.index, 'test-parent')
        for value in (None, {'not_applicable': True, 'reason': 'skip', 'approved_by': 'parent'},
                      {'ddr_local_transfers': False, 'reason': 'skip'}):
            index = copy.deepcopy(original)
            index['transport'] = value
            self.write(self.index, index)
            with self.assertRaises(DC.ContractError):
                DC.freeze(self.root, self.index, 'test-parent')

    def test_non_ddr_compute_bundle_allowed(self):
        self.fill()
        index = self.read(self.index)
        module = index['module_contracts']['gemm']
        doc = self.read(module)
        del doc['variant']  # Local-only module, not the DDR-backed historical fixture.
        self.write(module, doc)
        index['transport'] = {'ddr_local_transfers': False, 'reason': 'Standalone local-memory compute test'}
        self.write(self.index, index)
        digest = DC.freeze(self.root, self.index, 'test-parent')
        result = DC.consume(self.root, self.index, digest)
        self.assertFalse(any(f.startswith(DC.ENGINE) for f in result['sha256']))

    def test_inline_alternative_transport_blocked(self):
        self.fill()
        file = self.read(self.index)['module_contracts']['gemm']
        doc = self.read(file)
        doc['variant']['external_transfers']['weight']['transport'] = 'custom_dma'
        self.write(file, doc)
        with self.assertRaises(DC.ContractError):
            DC.freeze(self.root, self.index, 'test-parent')

    def test_engine_sources_bound_and_mutation_blocked(self):
        digest = self.frozen()
        result = DC.consume(self.root, self.index, digest)
        self.assertTrue(all(f'{DC.ENGINE}/rtl/{n}.sv' in result['sha256'] for n in DC.ENGINE_RTL))
        file = self.root / DC.ENGINE / 'rtl/datamover_engine.sv'
        file.write_text(file.read_text() + '\n// changed\n')
        with self.assertRaises(DC.ContractError):
            DC.consume(self.root, self.index, digest)

    def test_missing_engine_source_blocked(self):
        self.fill()
        (self.root / DC.ENGINE / 'rtl/datamover_engine.sv').unlink()
        with self.assertRaises(DC.ContractError):
            DC.freeze(self.root, self.index, 'test-parent')

    def test_init_creates_drafts_and_module_identity(self):
        index = self.read(self.index)
        self.assertEqual(index['status'], 'draft')
        self.assertEqual(len(index['design_contracts']), 5)
        self.assertEqual(self.read(index['module_contracts']['gemm'])['module_id'], 'gemm')

    def test_existing_revision_not_overwritten(self):
        before = (self.root / self.index).read_bytes()
        with self.assertRaises(DC.ContractError):
            DC.init(self.root, 'test', 'r01', 'config/hardware/zcu104.json', ['gemm'])
        self.assertEqual(before, (self.root / self.index).read_bytes())

    def test_unresolved_draft_cannot_freeze(self):
        with self.assertRaises(DC.ContractError):
            DC.freeze(self.root, self.index, 'test-parent')
        self.assertEqual(self.read(self.index)['status'], 'draft')

    def test_interrupted_freeze_blocks_consumption_and_can_resume(self):
        self.fill()
        original = DC.atomic_write
        count = 0
        def fail_third(p, *args, **kwargs):
            nonlocal count
            count += 1
            if count == 3:
                raise OSError('injected write failure')
            return original(p, *args, **kwargs)
        with patch.object(DC, 'atomic_write', fail_third):
            with self.assertRaises(OSError):
                DC.freeze(self.root, self.index, 'test-parent')
        self.assertEqual(self.read(self.index)['status'], 'draft')
        with self.assertRaises(DC.ContractError):
            DC.consume(self.root, self.index, DC.sha(self.root, self.index), 'gemm')
        digest = DC.freeze(self.root, self.index, 'test-parent')
        self.assertEqual(DC.consume(self.root, self.index, digest, 'gemm')['status'], 'passed')

    def test_partial_write_failure_preserves_json_and_can_resume(self):
        self.fill()
        original = json.dump
        count = 0
        def fail_partial(doc, stream, *args, **kwargs):
            nonlocal count
            count += 1
            if count == 3:
                stream.write('{"interrupted":')
                raise OSError('injected partial write ENOSPC')
            return original(doc, stream, *args, **kwargs)
        with patch.object(DC.json, 'dump', fail_partial):
            with self.assertRaises(OSError):
                DC.freeze(self.root, self.index, 'test-parent')
        index = self.read(self.index)
        self.assertEqual(index['status'], 'draft')
        for file in list(index['design_contracts'].values()) + list(index['module_contracts'].values()):
            self.assertIsInstance(self.read(file), dict)
        with self.assertRaises(DC.ContractError):
            DC.consume(self.root, self.index, DC.sha(self.root, self.index), 'gemm')
        digest = DC.freeze(self.root, self.index, 'test-parent')
        self.assertEqual(DC.consume(self.root, self.index, digest, 'gemm')['status'], 'passed')

    def test_draft_cannot_be_consumed(self):
        with self.assertRaises(DC.ContractError):
            DC.consume(self.root, self.index, DC.sha(self.root, self.index), 'gemm')

    def test_freeze_consume_no_writes(self):
        digest = self.frozen()
        files = [p for p in self.root.rglob('*') if p.is_file()]
        before = {p: (p.read_bytes(), p.stat().st_mtime_ns) for p in files}
        a = DC.consume(self.root, self.index, digest, 'gemm')
        b = DC.consume(self.root, self.index, digest, 'gemm')
        self.assertEqual(a, b)
        self.assertEqual(a['status'], 'passed')
        self.assertEqual(before, {p: (p.read_bytes(), p.stat().st_mtime_ns) for p in files})

    def test_wrong_revision_rejected(self):
        self.fill()
        file = self.read(self.index)['module_contracts']['gemm']
        doc = self.read(file); doc['revision'] = 'r02'; self.write(file, doc)
        with self.assertRaises(DC.ContractError):
            DC.freeze(self.root, self.index, 'test-parent')

    def test_missing_contract_rejected(self):
        self.fill()
        file = self.read(self.index)['design_contracts']['memory_ownership']
        (self.root / file).unlink()
        with self.assertRaises(DC.ContractError):
            DC.freeze(self.root, self.index, 'test-parent')

    def test_deleted_field_rejected(self):
        self.fill()
        file = self.read(self.index)['module_contracts']['gemm']
        doc = self.read(file); del doc['interface']; self.write(file, doc)
        with self.assertRaises(DC.ContractError):
            DC.freeze(self.root, self.index, 'test-parent')

    def test_post_freeze_mutation_rejected(self):
        digest = self.frozen()
        file = self.read(self.index)['module_contracts']['gemm']
        doc = self.read(file); doc['scope'] = 'changed'; self.write(file, doc)
        with self.assertRaises(DC.ContractError):
            DC.consume(self.root, self.index, digest, 'gemm')

    def test_hardware_and_policy_changes_rejected(self):
        digest = self.frozen()
        for file in ('config/hardware/zcu104.json', 'contracts/address_ownership.json'):
            with self.subTest(file=file):
                original = (self.root / file).read_text()
                (self.root / file).write_text(original + ' ')
                with self.assertRaises(DC.ContractError):
                    DC.consume(self.root, self.index, digest, 'gemm')
                (self.root / file).write_text(original)

    def test_bad_pin_or_unknown_module_rejected(self):
        digest = self.frozen()
        for pin, module in [('0' * 64, 'gemm'), (digest, 'unknown')]:
            with self.assertRaises(DC.ContractError):
                DC.consume(self.root, self.index, pin, module)

    def test_cross_design_path_rejected(self):
        self.fill()
        index = self.read(self.index)
        index['module_contracts']['gemm'] = '../outside.json'
        self.write(self.index, index)
        with self.assertRaises(DC.ContractError):
            DC.freeze(self.root, self.index, 'test-parent')

    def test_symlink_rejected(self):
        file = self.read(self.index)['module_contracts']['gemm']
        (self.root / file).unlink()
        (self.root / file).symlink_to(self.root / self.index)
        with self.assertRaises(DC.ContractError):
            DC.freeze(self.root, self.index, 'test-parent')

    def test_cli_bound_variant_and_tamper(self):
        digest = self.frozen()
        cmd = [sys.executable, str(self.root / 'src/codegen/variant_contract.py'),
               '--contract-index', self.index, '--expected-sha256', digest, '--module', 'gemm']
        result = subprocess.run(cmd, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(json.loads(result.stdout)['contract_gate']['status'], 'passed')
        file = self.read(self.index)['module_contracts']['gemm']
        doc = self.read(file); doc['numeric'] = 'changed'; self.write(file, doc)
        result = subprocess.run(cmd, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('hash mismatch', result.stdout)

    def test_cli_rejects_unbound_production(self):
        result = subprocess.run([sys.executable, str(self.root / 'src/codegen/variant_contract.py')],
                                capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('requires --contract-index', result.stderr)

    def test_cli_full_lifecycle(self):
        cli = [sys.executable, str(self.root / 'scripts/design_contracts.py')]
        def run(*args):
            return subprocess.run(cli + list(args), capture_output=True, text=True)
        created = run('init', '--design-id', 'test', '--revision', 'r02',
                      '--hardware-profile', 'config/hardware/zcu104.json', '--module', 'gemm')
        self.assertEqual(created.returncode, 0, created.stdout + created.stderr)
        self.index = json.loads(created.stdout)['index']
        blocked = run('freeze', '--index', self.index, '--approved-by', 'test-parent')
        self.assertNotEqual(blocked.returncode, 0)
        self.fill()
        frozen = run('freeze', '--index', self.index, '--approved-by', 'test-parent')
        self.assertEqual(frozen.returncode, 0, frozen.stdout + frozen.stderr)
        digest = json.loads(frozen.stdout)['index_sha256']
        checked = run('check', '--index', self.index, '--expected-sha256', digest, '--module', 'gemm')
        self.assertEqual(checked.returncode, 0, checked.stdout + checked.stderr)
        self.assertEqual(json.loads(checked.stdout)['module']['module_id'], 'gemm')

    def test_cli_cannot_overwrite_frozen_input(self):
        digest = self.frozen()
        file = self.read(self.index)['module_contracts']['gemm']
        target = self.root / file
        before = (target.read_bytes(), target.stat().st_mtime_ns)
        result = subprocess.run([sys.executable, str(self.root / 'src/codegen/variant_contract.py'),
            '--contract-index', self.index, '--expected-sha256', digest, '--module', 'gemm',
            '--output', str(target)], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(before, (target.read_bytes(), target.stat().st_mtime_ns))
        self.assertEqual(DC.consume(self.root, self.index, digest, 'gemm')['status'], 'passed')


if __name__ == '__main__':
    unittest.main()
