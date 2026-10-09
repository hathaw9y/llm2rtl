import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'scripts' / 'check_isa_design.py'
SPEC = importlib.util.spec_from_file_location('minimal_isa_design_test', SCRIPT)
CHECKER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECKER)


class IsaDesignTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        shutil.copytree(ROOT / 'contracts', self.root / 'contracts')
        (self.root / 'scripts').mkdir()
        shutil.copy2(ROOT / 'scripts/check_common_contracts.py',
                     self.root / 'scripts/check_common_contracts.py')
        self.design_rel = Path('designs/demo_r1')
        self.base = self.root / self.design_rel
        (self.base / 'modules').mkdir(parents=True)
        self.source_sha = '1' * 64
        self.trace = {
            'schema': 'llm2rtl.model_trace.v1', 'design_id': 'demo', 'revision': 'r1',
            'model_identity': {'model_id': 'fixture', 'revision': 'exact',
                               'transformers_version': 'fixture', 'source_path': 'fixture.py',
                               'source_sha256': self.source_sha},
            'operations': [
                {'operation_id': 'embedding', 'semantic_kind': 'token_row_load',
                 'source_location': 'fixture.py:1'},
                {'operation_id': 'projection', 'semantic_kind': 'linear',
                 'source_location': 'fixture.py:2'}],
            'workloads': [{'workload_id': 'decode_q1', 'conditions': {'q': 1},
                           'operations': ['embedding', 'projection']}],
            'unobserved_paths': [], 'unsupported_paths': []}
        self.write('model_trace.json', self.trace)
        common = self.common_inventory()
        self.isa = {
            'schema': 'llm2rtl.isa_spec.v1', 'design_id': 'demo', 'revision': 'r1',
            'status': 'reviewed', 'common_contracts': common,
            'instruction_record': {'width_bits': 128},
            'command_transport': {'command_order_owner': 'ps_software',
                                  'residency_tiling_owner': 'ps_software',
                                  'recovery_policy_owner': 'ps_software',
                                  'pl_dispatcher_role': 'route_execute_report_only',
                                  'request_protocol': 'ready_valid',
                                  'response_protocol': 'ready_valid',
                                  'program_transport': 'ps_preloaded_command_bram',
                                  'queue_policy': 'no_ring_queue',
                                  'dispatch_policy': 'strict_in_order_single_pc_scoreboard',
                                  'execution_policy': 'issue_on_request_handshake_with_scoreboard_completion',
                                  'outstanding_policy': 'bank_hazard_limited_multiple',
                                  'pc_advance_event': 'executor_command_acceptance',
                                  'response_collection': 'independent_of_current_pc',
                                  'program_terminal_policy': 'end_opcode_then_drain_outstanding',
                                  'blocked_pc_policy': 'stall_without_lookahead',
                                  'program_publish_order': [
                                      'instruction_records_ending_in_END', 'start'],
                                  'mutation_while_busy': 'forbidden'},
            'opcodes': [
                self.opcode('DMA_LOAD', 'datamover_executor', 'dma_load',
                            [('ddr', 'external_ddr_address'), ('dst', 'local_bank_id')]),
                self.opcode('DMA_STORE', 'datamover_executor', 'dma_store',
                            [('src', 'local_bank_id'), ('ddr', 'external_ddr_address')]),
                self.opcode('GEMM', 'gemm_executor', 'compute',
                            [('a', 'local_bank_id'), ('b', 'local_bank_id'),
                             ('c', 'local_bank_id'), ('m', 'dimension')]),
                self.opcode('END', 'isa_command_dispatcher', 'control', [])],
            'unresolved_decisions': []}
        self.write('isa_spec.json', self.isa)
        self.banks = {
            'schema': 'llm2rtl.bank_layout.v1', 'design_id': 'demo', 'revision': 'r1',
            'ownership_model': {'mode': 'single_exclusive_lock_per_bank'},
            'banks': [self.bank(name) for name in ('BANK_A', 'BANK_B', 'BANK_C')]}
        self.write('bank_layout.json', self.banks)
        self.validation = {
            'schema': 'llm2rtl.isa_validation.v1', 'design_id': 'demo', 'revision': 'r1',
            'model_trace': self.ref('model_trace.json'),
            'isa_spec': self.ref('isa_spec.json'),
            'bank_layout': self.ref('bank_layout.json'),
            'status': 'passed', 'no_host_tensor_compute': True,
            'model_source_sha256': self.source_sha,
            'lowerings': [
                {'operation_id': 'embedding',
                 'instructions': [{'opcode': 'DMA_LOAD', 'banks': ['BANK_A']}]},
                {'operation_id': 'projection',
                 'instructions': [{'opcode': 'GEMM',
                                   'banks': ['BANK_A', 'BANK_B', 'BANK_C']}]}],
            'workload_results': [{'workload_id': 'decode_q1', 'status': 'passed',
                                  'vector_sha256': '2' * 64}]}
        self.write('isa_validation.json', self.validation)

    def common_inventory(self):
        return {relative: hashlib.sha256((self.root / relative).read_bytes()).hexdigest()
                for relative in ('contracts/common/isa_command_contract.json',
                                 'contracts/common/local_bank_contract.json',
                                 'contracts/common/evidence_identity_contract.json',
                                 'contracts/common/engine_completion_contract.json')}

    @staticmethod
    def opcode(name, module, opcode_class, operands):
        return {'opcode': name, 'module_id': module, 'opcode_class': opcode_class,
                'operands': [{'name': operand, 'kind': kind} for operand, kind in operands],
                'operand_semantics': 'fixture', 'completion_semantics': 'one response',
                'failure_semantics': 'no commit'}

    @staticmethod
    def bank(name):
        return {'bank_id': name, 'capacity_words': 1024, 'word_bits': 128,
                'format': 'fixture', 'layout': 'row_major',
                'producers': ['fixture'], 'consumers': ['fixture']}

    def write(self, name, value):
        (self.base / name).write_text(json.dumps(value, indent=2) + '\n')

    def ref(self, name):
        path = self.base / name
        return {'path': str(path.relative_to(self.root)),
                'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}

    def refresh_validation_refs(self):
        self.validation['model_trace'] = self.ref('model_trace.json')
        self.validation['isa_spec'] = self.ref('isa_spec.json')
        self.validation['bank_layout'] = self.ref('bank_layout.json')
        self.write('isa_validation.json', self.validation)

    def check(self, **kwargs):
        return CHECKER.check(self.root, self.design_rel, **kwargs)

    def test_legacy_three_contract_revision_keeps_original_boundary(self):
        del self.isa['common_contracts']['contracts/common/engine_completion_contract.json']
        self.write('isa_spec.json', self.isa)
        self.refresh_validation_refs()
        self.assertFalse(self.check()['engine_completion_contract_pinned'])

    def test_stale_completion_contract_pin_fails(self):
        self.isa['common_contracts']['contracts/common/engine_completion_contract.json'] = '0' * 64
        self.write('isa_spec.json', self.isa)
        self.refresh_validation_refs()
        with self.assertRaisesRegex(CHECKER.DesignError, 'common contract identities'):
            self.check()

    def test_valid_minimal_design(self):
        result = self.check()
        self.assertEqual((result['operation_count'], result['opcode_count'], result['bank_count']),
                         (2, 4, 3))

    def test_compute_cannot_receive_ddr_or_local_offset(self):
        gemm = self.isa['opcodes'][2]
        for kind in ('external_ddr_address', 'local_bank_offset'):
            modified = copy.deepcopy(self.isa)
            modified['opcodes'][2]['operands'].append({'name': 'illegal', 'kind': kind})
            self.write('isa_spec.json', modified)
            self.refresh_validation_refs()
            with self.assertRaisesRegex(CHECKER.DesignError, 'compute uses bank IDs only'):
                self.check()
        self.write('isa_spec.json', self.isa)

    def test_dma_requires_ddr_and_bank(self):
        self.isa['opcodes'][0]['operands'] = [{'name': 'dst', 'kind': 'local_bank_id'}]
        self.write('isa_spec.json', self.isa)
        self.refresh_validation_refs()
        with self.assertRaisesRegex(CHECKER.DesignError, 'DMA_LOAD requires'):
            self.check()

    def test_every_operation_and_workload_must_pass(self):
        self.validation['lowerings'].pop()
        self.write('isa_validation.json', self.validation)
        with self.assertRaisesRegex(CHECKER.DesignError, 'unlowered model operations'):
            self.check()
        self.validation['lowerings'].append({
            'operation_id': 'projection',
            'instructions': [{'opcode': 'GEMM', 'banks': ['BANK_A', 'BANK_B', 'BANK_C']}]})
        self.validation['workload_results'] = []
        self.write('isa_validation.json', self.validation)
        with self.assertRaisesRegex(CHECKER.DesignError, 'missing workload results'):
            self.check()

    def test_unknown_bank_and_source_mismatch_are_rejected(self):
        self.validation['lowerings'][1]['instructions'][0]['banks'][0] = 'UNKNOWN'
        self.write('isa_validation.json', self.validation)
        with self.assertRaisesRegex(CHECKER.DesignError, 'unknown bank'):
            self.check()
        self.validation['lowerings'][1]['instructions'][0]['banks'][0] = 'BANK_A'
        self.validation['model_source_sha256'] = '3' * 64
        self.write('isa_validation.json', self.validation)
        with self.assertRaisesRegex(CHECKER.DesignError, 'model source identity mismatch'):
            self.check()

    def test_unresolved_decisions_and_stale_common_contracts_block(self):
        self.isa['unresolved_decisions'] = ['numeric boundary']
        self.write('isa_spec.json', self.isa)
        self.refresh_validation_refs()
        with self.assertRaisesRegex(CHECKER.DesignError, 'unresolved ISA decisions'):
            self.check()
        self.isa['unresolved_decisions'] = []
        self.isa['common_contracts']['contracts/common/isa_command_contract.json'] = '0' * 64
        self.write('isa_spec.json', self.isa)
        self.refresh_validation_refs()
        with self.assertRaisesRegex(CHECKER.DesignError, 'common contract identities'):
            self.check()

    def test_ring_queue_and_lookahead_are_rejected(self):
        for field, value, message in (
                ('queue_policy', 'producer_consumer_ring', 'must not use'),
                ('dispatch_policy', 'out_of_order_window', 'single-PC'),
                ('blocked_pc_policy', 'scan_later_commands', 'without examining')):
            modified = copy.deepcopy(self.isa)
            modified['command_transport'][field] = value
            self.write('isa_spec.json', modified)
            self.refresh_validation_refs()
            with self.assertRaisesRegex(CHECKER.DesignError, message):
                self.check()
        self.write('isa_spec.json', self.isa)

    def test_issue_completion_decoupling_is_required(self):
        for field, value, message in (
                ('execution_policy', 'execute_to_completion_before_next_fetch',
                 'advance after request acceptance'),
                ('outstanding_policy', 'single', 'multiple nonconflicting'),
                ('pc_advance_event', 'executor_completion', 'when.*accepted'),
                ('response_collection', 'current_pc_only', 'independently')):
            modified = copy.deepcopy(self.isa)
            modified['command_transport'][field] = value
            self.write('isa_spec.json', modified)
            self.refresh_validation_refs()
            with self.assertRaisesRegex(CHECKER.DesignError, message):
                self.check()
        self.write('isa_spec.json', self.isa)

    def test_optional_module_contract_is_hash_pinned(self):
        module = {'schema': 'llm2rtl.module_contract.v1', 'design_id': 'demo',
                  'revision': 'r1', 'module_id': 'gemm_executor', 'opcode': 'GEMM',
                  'status': 'frozen', 'interface': {'banks': True},
                  'numeric': {'format': 'fixture'}, 'verification': {'golden': 'fixture'}}
        self.write('modules/gemm_executor.json', module)
        digest = self.ref('modules/gemm_executor.json')['sha256']
        self.assertIsNotNone(self.check(module_id='gemm_executor',
                                        expected_module_sha256=digest)['module_checked'])
        with self.assertRaisesRegex(CHECKER.DesignError, 'SHA-256 mismatch'):
            self.check(module_id='gemm_executor', expected_module_sha256='0' * 64)

    def test_infrastructure_dispatcher_contract_is_hash_pinned(self):
        module = {'schema': 'llm2rtl.module_contract.v1', 'design_id': 'demo',
                  'revision': 'r1', 'module_id': 'isa_command_dispatcher',
                  'module_kind': 'infrastructure',
                  'routed_opcodes': ['DMA_LOAD', 'DMA_STORE', 'GEMM'],
                  'status': 'frozen', 'interface': {'command_bram': True},
                  'numeric': {'kind': 'control_only'},
                  'verification': {'golden': 'state_machine_model'}}
        self.write('modules/isa_command_dispatcher.json', module)
        digest = self.ref('modules/isa_command_dispatcher.json')['sha256']
        result = self.check(module_id='isa_command_dispatcher',
                            expected_module_sha256=digest)
        self.assertIsNotNone(result['module_checked'])

        module['routed_opcodes'] = ['DMA_LOAD', 'UNKNOWN']
        self.write('modules/isa_command_dispatcher.json', module)
        digest = self.ref('modules/isa_command_dispatcher.json')['sha256']
        with self.assertRaisesRegex(CHECKER.DesignError, 'unique known opcodes'):
            self.check(module_id='isa_command_dispatcher',
                       expected_module_sha256=digest)


if __name__ == '__main__':
    unittest.main()
