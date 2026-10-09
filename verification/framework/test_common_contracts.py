import copy
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'scripts' / 'check_common_contracts.py'
SPEC = importlib.util.spec_from_file_location('minimal_common_contracts_test', SCRIPT)
CHECKER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECKER)


class CommonContractsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        shutil.copytree(ROOT / 'contracts', self.root / 'contracts')

    def test_active_four_contracts_pass(self):
        result = CHECKER.check(self.root)
        self.assertEqual(result['contract_count'], 4)
        self.assertEqual(set(result['contracts']), set(CHECKER.FILES.values()))

    def test_early_engine_completion_is_rejected(self):
        path = self.root / CHECKER.FILES['engine_completion']
        value = json.loads(path.read_text())
        value['completion_rule'] = 'completion_after_read_issue'
        path.write_text(json.dumps(value))
        with self.assertRaisesRegex(CHECKER.ContractError, 'all read responses'):
            CHECKER.check(self.root)

    def test_compute_address_invariant_cannot_be_removed(self):
        path = self.root / CHECKER.FILES['isa_command']
        value = json.loads(path.read_text())
        value['opcode_classes']['compute']['forbidden_operand_kinds'].remove(
            'external_ddr_address')
        path.write_text(json.dumps(value))
        with self.assertRaisesRegex(CHECKER.ContractError, 'raw-address operands'):
            CHECKER.check(self.root)

    def test_ps_and_dispatcher_ownership_are_fixed(self):
        path = self.root / CHECKER.FILES['isa_command']
        value = json.loads(path.read_text())
        value['command_order_owner'] = 'pl_scheduler'
        path.write_text(json.dumps(value))
        with self.assertRaisesRegex(CHECKER.ContractError, 'must be ps_software'):
            CHECKER.check(self.root)

    def test_command_bram_cannot_reserve_data_bank_zero(self):
        path = self.root / CHECKER.FILES['local_bank']
        value = json.loads(path.read_text())
        value['ownership_rules'].remove('data_bank_zero_is_legal')
        value['ownership_rules'].append('bank_zero_is_reserved_for_command_bram')
        path.write_text(json.dumps(value))
        with self.assertRaisesRegex(CHECKER.ContractError, 'bank zero'):
            CHECKER.check(self.root)


if __name__ == '__main__':
    unittest.main()
