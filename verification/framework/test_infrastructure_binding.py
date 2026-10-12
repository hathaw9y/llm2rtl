import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    'infrastructure_binding_test', ROOT / 'scripts/check_infrastructure_binding.py')
CHECKER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECKER)


class InfrastructureBindingTest(unittest.TestCase):
    def setUp(self):
        from test_isa_design import IsaDesignTest
        fixture = IsaDesignTest('test_valid_minimal_design')
        fixture.setUp()
        self.addCleanup(fixture.doCleanups)
        self.fixture = fixture
        self.root = fixture.root
        for relative in ('ip/infrastructure/bank', 'ip/infrastructure/datamover',
                         'ip/infrastructure/controller', 'ip/infrastructure/utils',
                         'ip/infrastructure/templates', 'ip/infrastructure/contracts'):
            if (ROOT / relative).exists():
                shutil.copytree(ROOT / relative, self.root / relative)
            else:
                (self.root / relative).mkdir(parents=True, exist_ok=True)
        relative = 'ip/infrastructure/archive/pre_reference_integrated_20261012'
        shutil.copytree(ROOT / relative, self.root / relative)
        shutil.copy2(ROOT / 'ip/infrastructure/migration.json', self.root / 'ip/infrastructure/migration.json')
        shutil.copy2(ROOT / 'scripts/check_isa_design.py',
                     self.root / 'scripts/check_isa_design.py')
        for index, bank in enumerate(fixture.banks['banks']):
            bank['numeric_id'] = index
        fixture.write('bank_layout.json', fixture.banks)
        fixture.refresh_validation_refs()
        self.binding = {
            'schema': 'llm2rtl.execution_fabric_binding.v1',
            'design_dir': str(fixture.design_rel), 'design_id': 'demo', 'revision': 'r1',
            'isa_spec_sha256': hashlib.sha256((fixture.base/'isa_spec.json').read_bytes()).hexdigest(),
            'bank_layout_sha256': hashlib.sha256((fixture.base/'bank_layout.json').read_bytes()).hexdigest(),
            'dispatcher_module': 'demo_dispatcher', 'bank_subsystem_module': 'demo_banks',
            'bank_count': 3, 'port_role_width': 3,
            'owner_roles': {'MM2S_ARBITER': 1, 'S2MM_ARBITER': 2,
                            'GEMM_A': 3, 'GEMM_B': 4, 'GEMM_C': 5},
            'bank_capabilities': [
                {'bank_id': 0, 'allowed_roles': ['MM2S_ARBITER', 'GEMM_A']},
                {'bank_id': 1, 'allowed_roles': ['MM2S_ARBITER', 'GEMM_B']},
                {'bank_id': 2, 'allowed_roles': ['S2MM_ARBITER', 'GEMM_C']}],
            'compute_routes': [{'opcode': 'GEMM', 'module_id': 'gemm_executor',
                                'operand_roles': {'a': 'GEMM_A', 'b': 'GEMM_B', 'c': 'GEMM_C'}}],
            'dma_adapters': [
                {'bank_id': 0, 'direction': 'load', 'module_id': 'mm2s_adapter'},
                {'bank_id': 1, 'direction': 'load', 'module_id': 'mm2s_adapter'},
                {'bank_id': 2, 'direction': 'store', 'module_id': 's2mm_adapter'}],
            'external_boundaries': {'command_bram_port': 'native_bram_b',
                                    'vendor_datamover_ports': 'axis_mm2s_s2mm',
                                    'ps_control_port': 'axi_lite'}}
        self.write_binding()

    def write_binding(self):
        path = self.fixture.base / 'fabric_binding.json'
        path.write_text(json.dumps(self.binding, indent=2) + '\n')
        return str(path.relative_to(self.root))

    def test_model_binding_passes(self):
        result = CHECKER.check_binding(self.root, self.write_binding())
        self.assertEqual(result['status'], 'passed_binding_structure')
        self.assertEqual(result['compute_opcode_count'], 1)

    def test_missing_compute_route_fails(self):
        self.binding['compute_routes'] = []
        with self.assertRaisesRegex(CHECKER.BindingError, 'missing compute routes'):
            CHECKER.check_binding(self.root, self.write_binding())

    def test_duplicate_owner_id_fails(self):
        self.binding['owner_roles']['GEMM_A'] = 1
        with self.assertRaisesRegex(CHECKER.BindingError, 'unique nonzero'):
            CHECKER.check_binding(self.root, self.write_binding())

    def test_command_bank_in_data_namespace_fails(self):
        self.fixture.banks['command_bank_id'] = 0
        self.fixture.write('bank_layout.json', self.fixture.banks)
        self.fixture.refresh_validation_refs()
        self.binding['bank_layout_sha256'] = hashlib.sha256(
            (self.fixture.base/'bank_layout.json').read_bytes()).hexdigest()
        with self.assertRaisesRegex(CHECKER.BindingError, 'command BRAM'):
            CHECKER.check_binding(self.root, self.write_binding())

    def test_template_source_identity_fails_closed(self):
        source = self.root / 'ip/infrastructure/bank/bank_ownership_table.sv'
        source.write_text(source.read_text() + '\n')
        with self.assertRaisesRegex(CHECKER.BindingError, 'ownership source SHA-256'):
            CHECKER.check_templates(self.root)

    def test_datamover_child_source_identity_fails_closed(self):
        source = CHECKER.safe_path(self.root, 'ip/infrastructure/datamover/datamover_command_queue.sv')
        source.write_text(source.read_text() + '\n')
        with self.assertRaisesRegex(CHECKER.BindingError, 'SHA-256 mismatch'):
            CHECKER.check_templates(self.root)

    def test_datamover_source_index_identity_fails_closed(self):
        template = CHECKER.read_json(self.root / CHECKER.FABRIC_TEMPLATE)
        index = self.root / template['datamover_source_index']
        index.write_text(index.read_text() + '\n')
        with self.assertRaisesRegex(CHECKER.BindingError, 'infrastructure source SHA-256'):
            CHECKER.check_templates(self.root)

    def test_active_index_cannot_inherit_historical_verification(self):
        template_path = self.root / CHECKER.FABRIC_TEMPLATE
        template = CHECKER.read_json(template_path)
        index_path = self.root / template['datamover_source_index']
        index = CHECKER.read_json(index_path)
        index['verification'] = {'status': 'historical_pass'}
        index_path.write_text(json.dumps(index))
        for pin in template['pinned_infrastructure']:
            if pin['path'] == template['datamover_source_index']:
                pin['sha256'] = CHECKER.sha256(index_path)
        template_path.write_text(json.dumps(template))
        with self.assertRaisesRegex(CHECKER.BindingError, 'must not inherit'):
            CHECKER.check_templates(self.root)


if __name__ == '__main__':
    unittest.main()
