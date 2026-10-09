import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'scripts' / 'check_infrastructure_template.py'
SPEC = importlib.util.spec_from_file_location('infrastructure_template_test', SCRIPT)
CHECKER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECKER)


class InfrastructureTemplateTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for relative in ('contracts/common', 'ip/infrastructure/cmd_dispatcher_template',
                         'ip/infrastructure/bank_subsystem/contracts'):
            shutil.copytree(ROOT / relative, self.root / relative)

    def test_frozen_identity_passes_without_rtl_gate(self):
        result = CHECKER.check(self.root, require_rtl=False)
        self.assertEqual(result['status'], 'passed_contract_identity')

    def test_local_bank_identity_change_fails_closed(self):
        path = self.root / 'contracts/common/local_bank_contract.json'
        value = json.loads(path.read_text())
        value['ownership_mode'] = 'read_write_split'
        path.write_text(json.dumps(value))
        with self.assertRaisesRegex(CHECKER.TemplateError, 'SHA-256 mismatch'):
            CHECKER.check(self.root, require_rtl=False)

    def test_command_bram_cannot_become_data_bank_zero(self):
        contract_path = self.root / 'ip/infrastructure/cmd_dispatcher_template/template_contract.json'
        contract = json.loads(contract_path.read_text())
        contract['fixed_architecture']['command_bram_is_not_a_data_bank'] = False
        contract_path.write_text(json.dumps(contract))
        index_path = self.root / CHECKER.INDEX
        index = json.loads(index_path.read_text())
        index['contract']['sha256'] = CHECKER.digest(contract_path)
        index_path.write_text(json.dumps(index))
        with self.assertRaisesRegex(CHECKER.TemplateError, 'separate'):
            CHECKER.check(self.root, require_rtl=False)

    def test_native_bank_identity_change_fails_closed(self):
        path = self.root / 'ip/infrastructure/bank_subsystem/contracts/native_v3.json'
        path.write_text(path.read_text() + ' ')
        with self.assertRaisesRegex(CHECKER.TemplateError, 'SHA-256 mismatch'):
            CHECKER.check(self.root, require_rtl=False)

    def test_native_acknowledgement_cannot_be_removed(self):
        rtl_path = self.root / 'ip/infrastructure/cmd_dispatcher_template/rtl/cmd_dispatcher_template.sv'
        rtl_path.write_text(rtl_path.read_text().replace(
            'bank_rd_release_accepted', 'removed_read_release_ack'))
        with self.assertRaisesRegex(CHECKER.TemplateError, 'missing fixed port'):
            CHECKER.check(self.root, require_rtl=True)

    def test_rtl_gate_requires_executable_user_hooks(self):
        rtl_path = self.root / 'ip/infrastructure/cmd_dispatcher_template/rtl/cmd_dispatcher_template.sv'
        rtl = rtl_path.read_text()
        rtl_path.write_text(rtl.replace('user_executor_fault_w',
                                        'removed_executor_fault_hook'))
        with self.assertRaisesRegex(CHECKER.TemplateError, 'executable USER hook'):
            CHECKER.check(self.root, require_rtl=True)


if __name__ == '__main__':
    unittest.main()
