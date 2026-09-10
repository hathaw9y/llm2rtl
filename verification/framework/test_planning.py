"""Synthetic planning reference tests. No model, HDL, or hardware claims."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'scripts/check_planning.py'
SPEC = importlib.util.spec_from_file_location('check_planning', SCRIPT)
CP = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CP)


def node(name, graph='prefill'):
    return {'graph_id': graph, 'node_id': name}


class PlanningTest(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix='llm2rtl-planning-test-')
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.mapping_path = 'planning/module_mapping.json'
        self.approval_path = 'planning/module_mapping_approval.json'
        self.plan_path = 'planning/bringup.json'
        self.graph_path = 'planning/model_graph.json'
        self.write('profile.json', {'scope': 'synthetic test only'})
        self.graph = {
            'schema': 'llm2rtl.model_graph.v1', 'design_id': 'demo', 'revision': 'r01',
            'graphs': [{'id': 'prefill', 'nodes': [
                {'id': 'norm', 'op': 'rmsnorm'}, {'id': 'q', 'op': 'linear'},
                {'id': 'k', 'op': 'linear'}]}]
        }
        self.write(self.graph_path, self.graph)
        self.mapping = {
            'schema': 'llm2rtl.module_mapping.v1', 'design_id': 'demo', 'revision': 'r01',
            'path_base': 'repository_root', 'scope': 'model', 'status': 'reviewed',
            'model_graph': self.ref(self.graph_path), 'hardware_profile': self.ref('profile.json'),
            'architecture': {'choice': 'synthetic shared projection'},
            'numeric_policy': {'scope': 'No numerical validation performed'},
            'memory_plan': {'scope': 'Synthetic local-memory-only test'},
            'modules': [
                {'module_id': name, 'role': 'compute', 'implementation': 'generated',
                 'rationale': 'Synthetic test module'} for name in ('norm', 'projection')],
            'mappings': [
                {'mapping_id': name, 'nodes': [node(n) for n in ns], 'module_ids': [name],
                 'transform': 'shared' if name == 'projection' else 'direct',
                 'rationale': 'Synthetic reference coverage',
                 'numeric_validation': 'No numerical evidence; this is a checker test'}
                for name, ns in [('norm', ['norm']), ('projection', ['q', 'k'])]],
            'unmapped_nodes': [], 'review': {'reviewed_by': 'test-parent', 'limitations': ['Structure only']}
        }
        self.plan = {
            'schema': 'llm2rtl.bringup.v1', 'design_id': 'demo', 'revision': 'r01',
            'model_graph': self.mapping['model_graph'],
            'hardware_profile': self.mapping['hardware_profile'],
            'target': {'nodes': [node(n) for n in ('norm', 'q', 'k')]},
            'stages': [
                {'stage_id': 's01', 'depends_on': [], 'new_modules': ['norm'], 'reused_modules': [],
                 'graph_coverage': {'added': [node('norm')], 'cumulative': [node('norm')]},
                 'hardware_checkpoint_required': True},
                {'stage_id': 's02', 'depends_on': ['s01'], 'new_modules': ['projection'],
                 'reused_modules': ['norm'], 'graph_coverage': {
                     'added': [node('q'), node('k')],
                     'cumulative': [node(n) for n in ('norm', 'q', 'k')]},
                 'hardware_checkpoint_required': True}]
        }
        self.save()
        self.approve_fixture()

    def write(self, name, data):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')

    def ref(self, name):
        return {'path': name, 'sha256': hashlib.sha256((self.root / name).read_bytes()).hexdigest()}

    def save(self):
        self.write(self.mapping_path, self.mapping)
        self.mapping_hash = self.ref(self.mapping_path)['sha256']
        self.plan['module_mapping'] = self.ref(self.mapping_path)
        self.write(self.plan_path, self.plan)

    def check(self, **kwargs):
        kwargs.setdefault('expected_mapping', self.mapping_hash)
        kwargs.setdefault('expected_approval', self.approval_hash)
        return CP.check(self.root, self.mapping_path, self.plan_path, **kwargs)

    def approve_fixture(self, write_plan=True):
        # Synthetic test data, never evidence of a real user's authorization.
        self.write(self.approval_path, {
            'schema': 'llm2rtl.module_mapping_approval.v1', 'path_base': 'repository_root',
            'design_id': self.mapping['design_id'], 'revision': self.mapping['revision'],
            'module_mapping': self.ref(self.mapping_path), 'decision': 'approved',
            'scope': 'implement_this_mapping', 'recorded_by': 'test-parent',
            'request': {'message_ref': 'synthetic/request/1',
                        'text': 'Fixture only: approve implementation of mapping ' + self.ref(self.mapping_path)['sha256']},
            'user_response': {'actor': 'user', 'message_ref': 'synthetic/response/1',
                              'text': 'Fixture only: I approve the presented mapping for implementation.'}})
        self.approval_hash = self.ref(self.approval_path)['sha256']
        self.plan['module_mapping_approval'] = self.ref(self.approval_path)
        if write_plan:
            self.write(self.plan_path, self.plan)

    def stage(self, name='s01', **kwargs):
        return self.check(expected_mapping=self.ref(self.mapping_path)['sha256'],
                          expected_bringup=self.ref(self.plan_path)['sha256'],
                          expected_approval=self.approval_hash,
                          stage_id=name, **kwargs)

    def rejected(self, pattern):
        return self.assertRaisesRegex(CP.PlanningError, pattern)

    def test_valid_mapping_and_cumulative_plan_are_read_only(self):
        before = {p: p.read_bytes() for p in self.root.rglob('*') if p.is_file()}
        result = self.check()
        self.assertEqual(result['status'], 'passed_structure_only')
        self.assertFalse(result['stage_reference_gate_passed'])
        self.assertTrue(result['user_approval_declaration_checked'])
        self.assertFalse(result['bringup_generation_gate_passed'])
        self.assertEqual((result['node_count'], result['module_count'], result['stage_count']), (3, 2, 2))
        self.assertTrue(self.stage('s02', module_id='projection')['stage_reference_gate_passed'])
        self.assertTrue(self.stage('s02')['user_approval_declaration_checked'])
        self.assertEqual(before, {p: p.read_bytes() for p in self.root.rglob('*') if p.is_file()})

    def test_mapping_can_be_checked_before_bringup_exists(self):
        (self.root / self.plan_path).unlink()
        self.assertEqual(CP.check(self.root, self.mapping_path)['stage_count'], 0)

    def preflight(self, **kwargs):
        kwargs.setdefault('expected_mapping', self.mapping_hash)
        kwargs.setdefault('expected_approval', self.approval_hash)
        return CP.check(self.root, self.mapping_path, before_bringup=True, **kwargs)

    def test_mapping_approval_then_bringup_generation_lifecycle(self):
        (self.root / self.plan_path).unlink()
        (self.root / self.approval_path).unlink()
        mapping_bytes = (self.root / self.mapping_path).read_bytes()
        result = CP.check(self.root, self.mapping_path)
        self.assertFalse(result['bringup_generation_gate_passed'])
        self.assertFalse(result['user_approval_declaration_checked'])
        with self.rejected('missing file'):
            self.preflight()
        self.assertFalse((self.root / self.plan_path).exists())
        self.approve_fixture(write_plan=False)  # Simulate a real decision before plan creation.
        before = {p: p.read_bytes() for p in self.root.rglob('*') if p.is_file()}
        result = self.preflight()
        self.assertTrue(result['bringup_generation_gate_passed'])
        self.assertTrue(result['user_approval_declaration_checked'])
        self.assertEqual(result['stage_count'], 0)
        self.assertEqual(before, {p: p.read_bytes() for p in self.root.rglob('*') if p.is_file()})
        self.assertEqual(mapping_bytes, (self.root / self.mapping_path).read_bytes())
        self.write(self.plan_path, self.plan)
        self.assertTrue(self.check()['user_approval_declaration_checked'])
        self.assertTrue(self.stage('s02')['stage_reference_gate_passed'])

    def test_bringup_generation_requires_both_approval_pins_and_parent_review(self):
        (self.root / self.plan_path).unlink()
        with self.rejected('requires approved mapping'):
            CP.check(self.root, self.mapping_path, before_bringup=True)
        with self.rejected('approval SHA-256 required'):
            self.preflight(expected_approval=None)
        with self.rejected('packet mapping SHA-256'):
            self.preflight(expected_mapping='0' * 64)
        with self.rejected('packet approval SHA-256'):
            self.preflight(expected_approval='0' * 64)
        for status in ('draft', 'blocked'):
            self.mapping['status'] = status
            self.write(self.mapping_path, self.mapping)
            self.mapping_hash = self.ref(self.mapping_path)['sha256']
            self.approve_fixture(write_plan=False)
            with self.rejected('parent-reviewed'):
                self.preflight()

    def test_bringup_generation_cannot_reuse_approval_after_mapping_change(self):
        (self.root / self.plan_path).unlink()
        self.mapping['architecture']['choice'] = 'new architecture needs approval'
        self.write(self.mapping_path, self.mapping)
        self.mapping_hash = self.ref(self.mapping_path)['sha256']
        with self.rejected('fresh user confirmation'):
            self.preflight()

    def test_bringup_generation_rejects_nonapproval_and_parent_instead_of_user(self):
        (self.root / self.plan_path).unlink()
        original = json.loads((self.root / self.approval_path).read_text())
        for decision in ('pending', 'changes_requested', 'rejected', 'revoked'):
            approval = copy.deepcopy(original)
            approval['decision'] = decision
            self.write(self.approval_path, approval)
            self.approval_hash = self.ref(self.approval_path)['sha256']
            with self.rejected('explicit user approval'):
                self.preflight()
        original['user_response']['actor'] = 'parent'
        self.write(self.approval_path, original)
        self.approval_hash = self.ref(self.approval_path)['sha256']
        with self.rejected('cannot substitute'):
            self.preflight()

    def test_bringup_generation_cannot_overwrite_existing_or_symlinked_plan(self):
        original = (self.root / self.plan_path).read_bytes()
        with self.rejected('already exists'):
            self.preflight()
        self.assertEqual(original, (self.root / self.plan_path).read_bytes())
        (self.root / self.plan_path).unlink()
        (self.root / self.plan_path).symlink_to(self.root / 'missing.json')
        with self.rejected('already exists'):
            self.preflight()

    def test_bringup_generation_and_consumption_flags_cannot_mix(self):
        (self.root / self.plan_path).unlink()
        for kwargs in ({'bringup_path': self.plan_path}, {'stage_id': 's01'},
                       {'module_id': 'norm'}, {'expected_bringup': '0' * 64}):
            with self.subTest(kwargs=kwargs), self.rejected('cannot be combined'):
                self.preflight(**kwargs)

    def test_unpinned_bringup_validation_cannot_bypass_user_approval(self):
        with self.rejected('requires approved mapping'):
            CP.check(self.root, self.mapping_path, self.plan_path)
        with self.rejected('approval SHA-256 required'):
            CP.check(self.root, self.mapping_path, self.plan_path,
                     expected_mapping=self.mapping_hash)
        (self.root / self.approval_path).unlink()
        with self.rejected('missing file'):
            self.check()  # No stage selected: still requires approval.

    def test_bringup_must_bind_the_checked_approval_reference(self):
        original = copy.deepcopy(self.plan)
        del self.plan['module_mapping_approval']
        self.write(self.plan_path, self.plan)
        with self.rejected('bringup.module_mapping_approval'):
            self.check()
        self.plan = copy.deepcopy(original)
        self.plan['module_mapping_approval']['sha256'] = '0' * 64
        self.write(self.plan_path, self.plan)
        with self.rejected('stale reference hash'):
            self.check()
        self.plan = copy.deepcopy(original)
        self.write('planning/copied_approval.json',
                   json.loads((self.root / self.approval_path).read_text()))
        self.plan['module_mapping_approval'] = self.ref('planning/copied_approval.json')
        self.write(self.plan_path, self.plan)
        with self.rejected('checked mapping approval'):
            self.check()

    def test_cli_before_bringup_is_a_read_only_approval_gate(self):
        (self.root / self.plan_path).unlink()
        command = [sys.executable, str(SCRIPT), '--root', str(self.root),
                   '--mapping', self.mapping_path, '--before-bringup']
        result = subprocess.run(command, capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 1)
        command.extend(['--expected-mapping-sha256', self.mapping_hash,
                        '--expected-approval-sha256', self.approval_hash])
        result = subprocess.run(command, capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(json.loads(result.stdout)['bringup_generation_gate_passed'])
        self.assertFalse((self.root / self.plan_path).exists())

    def test_missing_mapping_file_fails(self):
        (self.root / self.mapping_path).unlink()
        with self.rejected('missing file'):
            self.check()

    def test_old_inline_mapping_is_rejected(self):
        self.plan['module_mapping']['entries'] = self.mapping['mappings']
        self.write(self.plan_path, self.plan)
        with self.rejected('only path and sha256'):
            self.check()

    def test_source_and_packet_hash_changes_are_rejected(self):
        for path in (self.graph_path, 'profile.json', self.mapping_path):
            with self.subTest(path=path):
                original = (self.root / path).read_bytes()
                (self.root / path).write_bytes(original + b'\n')
                with self.rejected('stale reference hash|packet mapping SHA-256'):
                    self.check()
                (self.root / path).write_bytes(original)
        with self.rejected('packet mapping SHA-256'):
            self.check(expected_mapping='0' * 64)
        with self.rejected('packet bringup SHA-256'):
            self.check(expected_bringup='0' * 64)

    def test_missing_source_file_rejected(self):
        (self.root / self.graph_path).unlink()
        with self.rejected('missing file'):
            self.check()

    def test_noncanonical_mapping_and_different_link_are_rejected(self):
        self.write('planning/alternative.json', self.mapping)
        with self.rejected('canonical module_mapping.json'):
            CP.check(self.root, 'planning/alternative.json')
        self.write('other/module_mapping.json', self.mapping)
        self.plan['module_mapping'] = self.ref('other/module_mapping.json')
        self.write(self.plan_path, self.plan)
        with self.rejected('different mapping'):
            self.check()

    def test_revision_and_profile_mismatch_rejected(self):
        for field, value in [('revision', 'r02'), ('design_id', 'different'),
                             ('hardware_profile', {'path': 'elsewhere', 'sha256': '0' * 64})]:
            with self.subTest(field=field):
                original = self.plan[field]
                self.plan[field] = value
                self.save()
                with self.rejected('mismatch'):
                    self.check()
                self.plan[field] = original
        self.graph['revision'] = 'r02'
        self.write(self.graph_path, self.graph)
        self.mapping['model_graph'] = self.ref(self.graph_path)
        self.save()
        with self.rejected('graph revision mismatch'):
            self.check()

    def test_unknown_graph_node_and_module_references(self):
        original = copy.deepcopy(self.mapping)
        for key, value in [('nodes', [node('missing')]), ('nodes', [node('norm', 'unknown')]),
                           ('module_ids', ['unknown'])]:
            with self.subTest(key=key, value=value):
                self.mapping = copy.deepcopy(original)
                self.mapping['mappings'][0][key] = value
                self.save()
                with self.rejected('unknown'):
                    self.check()

    def test_unaccounted_node_is_not_silently_dropped(self):
        self.mapping['mappings'][1]['nodes'].pop()
        self.save()
        with self.rejected('unaccounted graph nodes'):
            self.check()

    def test_blocked_future_nodes_preserved_without_blocking_earlier_stage(self):
        self.mapping['mappings'][1]['nodes'].remove(node('k'))
        self.mapping['unmapped_nodes'] = [{'node': node('k'), 'status': 'blocked',
                                          'reason': 'Numeric validation pending'}]
        self.save()
        self.approve_fixture()
        self.assertEqual(self.check()['unmapped_node_count'], 1)
        self.assertTrue(self.stage('s01')['stage_reference_gate_passed'])
        with self.rejected('blocked/unmapped'):
            self.stage('s02')

    def test_excluded_node_cannot_remain_in_target(self):
        self.mapping['mappings'][1]['nodes'].remove(node('k'))
        self.mapping['unmapped_nodes'] = [{'node': node('k'), 'status': 'excluded',
                                          'reason': 'Declared outside bounded target'}]
        self.save()
        with self.rejected('excluded nodes'):
            self.check()
        self.plan['target']['nodes'].remove(node('k'))
        for field in ('added', 'cumulative'):
            self.plan['stages'][1]['graph_coverage'][field].remove(node('k'))
        self.save()
        self.approve_fixture()
        self.assertTrue(self.stage('s02')['stage_reference_gate_passed'])

    def test_duplicate_ids_and_conflicting_dispositions_rejected(self):
        original = copy.deepcopy(self.mapping)
        mutations = [
            lambda m: m['modules'].append(copy.deepcopy(m['modules'][0])),
            lambda m: m['mappings'].append(copy.deepcopy(m['mappings'][0])),
            lambda m: m['mappings'][1]['nodes'].append(node('norm')),
            lambda m: m['unmapped_nodes'].append({'node': node('norm'), 'status': 'blocked', 'reason': 'conflict'})]
        for mutate in mutations:
            self.mapping = copy.deepcopy(original)
            mutate(self.mapping)
            self.save()
            with self.rejected('duplicate|more than once|conflicting'):
                self.check()

    def test_split_and_infrastructure_modules_need_no_fake_nodes(self):
        self.mapping['modules'].extend([
            {'module_id': 'reduction', 'role': 'compute', 'implementation': 'generated', 'rationale': 'Split reduction'},
            {'module_id': 'transport', 'role': 'transport', 'implementation': 'reused', 'rationale': 'Infrastructure'}])
        self.mapping['mappings'][1]['module_ids'].append('reduction')
        self.plan['stages'][1]['new_modules'].extend(['reduction', 'transport'])
        self.save()
        self.approve_fixture()
        self.assertEqual(self.check()['module_count'], 4)

    def test_stage_dependencies_module_availability_and_coverage(self):
        original = copy.deepcopy(self.plan)
        mutations = [
            ('dependency', lambda p: p['stages'][0]['depends_on'].append('s02')),
            ('previous stage', lambda p: p['stages'][1].update(depends_on=[])),
            ('prior modules', lambda p: p['stages'][1].update(reused_modules=[])),
            ('already introduced', lambda p: p['stages'][1]['new_modules'].append('norm')),
            ('unknown', lambda p: p['stages'][1]['new_modules'].append('unknown')),
            ('before their modules', lambda p: p['stages'][1].update(new_modules=[])),
            ('coverage', lambda p: p['stages'][1]['graph_coverage']['cumulative'].remove(node('norm'))),
            ('checkpoint', lambda p: p['stages'][0].update(hardware_checkpoint_required=False)),
            ('duplicate stage', lambda p: p['stages'][1].update(stage_id='s01'))]
        for pattern, mutate in mutations:
            with self.subTest(pattern=pattern):
                self.plan = copy.deepcopy(original)
                mutate(self.plan)
                self.save()
                with self.rejected(pattern):
                    self.check()

    def test_final_target_coverage_is_required(self):
        self.plan['stages'].pop()
        self.save()
        with self.rejected('final stage'):
            self.check()

    def test_stage_gate_requires_review_and_packet_hashes(self):
        with self.rejected('packet-provided'):
            self.check(stage_id='s01')
        with self.rejected('not available'):
            self.stage('s01', module_id='projection')
        with self.rejected('unknown stage'):
            self.stage('unknown')
        for status in ('draft', 'blocked'):
            self.mapping['status'] = status
            self.mapping['review']['reviewed_by'] = None
            self.save()
            self.assertEqual(CP.check(self.root, self.mapping_path)['mapping_status'], status)
            with self.rejected('parent-reviewed'):
                self.stage()

    def test_standalone_operator_uses_spec_not_fabricated_graph(self):
        self.write('operator_spec.json', {'operator': 'int4 dot', 'scope': 'synthetic checker fixture'})
        self.mapping.pop('model_graph')
        self.mapping.update(scope='operator', scope_reason='Standalone operator, no model',
                            operator_spec=self.ref('operator_spec.json'))
        for mapping in self.mapping['mappings']:
            mapping['nodes'] = []
        self.save()
        self.assertEqual(CP.check(self.root, self.mapping_path)['node_count'], 0)
        self.approve_fixture()
        result = CP.check(self.root, self.mapping_path,
                          expected_mapping=self.ref(self.mapping_path)['sha256'],
                          expected_approval=self.approval_hash, module_id='projection')
        self.assertEqual(result['mapping_status'], 'reviewed')
        with self.rejected('unknown operator module'):
            CP.check(self.root, self.mapping_path,
                     expected_mapping=self.ref(self.mapping_path)['sha256'], module_id='missing')
        self.plan.pop('model_graph')
        self.plan['operator_spec'] = self.mapping['operator_spec']
        self.plan['target']['nodes'] = []
        for stage in self.plan['stages']:
            stage['graph_coverage'] = {'added': [], 'cumulative': []}
        self.save()
        self.assertTrue(self.stage('s02')['stage_reference_gate_passed'])
        self.mapping['model_graph'] = self.ref(self.graph_path)
        self.save()
        with self.rejected('must not be mixed'):
            self.check()

    def test_empty_operator_mapping_and_unreviewed_consumption_rejected(self):
        self.mapping['status'] = 'draft'
        self.save()
        with self.rejected('parent-reviewed'):
            CP.check(self.root, self.mapping_path, expected_mapping=self.ref(self.mapping_path)['sha256'])
        self.mapping.pop('model_graph')
        self.mapping.update(scope='operator', operator_spec=self.ref(self.graph_path),
                            scope_reason='Synthetic standalone spec', mappings=[])
        self.save()
        with self.rejected('at least one mapping entry'):
            CP.check(self.root, self.mapping_path)

    def test_approval_not_needed_for_proposal_but_mandatory_for_consumption(self):
        (self.root / self.approval_path).unlink()
        self.assertFalse(CP.check(self.root, self.mapping_path)['user_approval_declaration_checked'])
        with self.rejected('missing file'):
            self.stage()
        with self.rejected('approval SHA-256 required'):
            self.check(expected_mapping=self.ref(self.mapping_path)['sha256'], expected_approval=None)

    def test_mapping_edit_cannot_reuse_prior_user_approval(self):
        self.mapping['architecture']['choice'] = 'different architecture'
        self.save()
        self.assertEqual(CP.check(self.root, self.mapping_path)['status'], 'passed_structure_only')
        with self.rejected('fresh user confirmation'):
            self.stage()
        self.approve_fixture()  # Explicitly simulate a new user decision on the changed mapping.
        self.assertTrue(self.stage()['user_approval_declaration_checked'])

    def test_approval_is_pinned_separately_from_mapping(self):
        file = self.root / self.approval_path
        file.write_bytes(file.read_bytes() + b'\n')
        with self.rejected('packet approval SHA-256 mismatch'):
            self.stage()

    def test_nonapproval_decisions_and_parent_self_approval_rejected(self):
        original = json.loads((self.root / self.approval_path).read_text())
        mutations = [
            ('user approval', lambda a: a.update(decision='pending')),
            ('user approval', lambda a: a.update(decision='changes_requested')),
            ('user approval', lambda a: a.update(decision='rejected')),
            ('user approval', lambda a: a.update(decision='revoked')),
            ('cannot substitute', lambda a: a['user_response'].update(actor='parent')),
            ('scope required', lambda a: a.update(scope='input_confirmation')),
            ('approval revision mismatch', lambda a: a.update(revision='r02')),
            ('exact mapping', lambda a: a['module_mapping'].update(sha256='0' * 64)),
            ('exact mapping', lambda a: a['module_mapping'].update(path='other/module_mapping.json'))]
        for pattern, mutate in mutations:
            with self.subTest(pattern=pattern):
                approval = copy.deepcopy(original)
                mutate(approval)
                self.write(self.approval_path, approval)
                self.approval_hash = self.ref(self.approval_path)['sha256']
                with self.rejected(pattern):
                    self.stage()

    def test_missing_approval_message_evidence_rejected(self):
        original = json.loads((self.root / self.approval_path).read_text())
        for name in ('request', 'user_response'):
            for field in ('message_ref', 'text'):
                with self.subTest(name=name, field=field):
                    approval = copy.deepcopy(original)
                    approval[name][field] = ''
                    self.write(self.approval_path, approval)
                    self.approval_hash = self.ref(self.approval_path)['sha256']
                    with self.rejected('nonempty text'):
                        self.stage()

    def test_operator_cannot_bypass_approval_without_bringup(self):
        self.mapping.pop('model_graph')
        self.mapping.update(scope='operator', operator_spec=self.ref(self.graph_path),
                            scope_reason='Synthetic standalone spec')
        for mapping in self.mapping['mappings']:
            mapping['nodes'] = []
        self.save()
        with self.rejected('approval SHA-256 required'):
            CP.check(self.root, self.mapping_path,
                     expected_mapping=self.ref(self.mapping_path)['sha256'], module_id='projection')

    def test_cli_requires_and_accepts_exact_approval(self):
        command = [sys.executable, str(SCRIPT), '--root', str(self.root),
                   '--mapping', self.mapping_path, '--bringup', self.plan_path,
                   '--expected-mapping-sha256', self.ref(self.mapping_path)['sha256'],
                   '--expected-bringup-sha256', self.ref(self.plan_path)['sha256'], '--stage', 's01']
        result = subprocess.run(command, capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 1)
        self.assertIn('approval SHA-256', json.loads(result.stdout)['error'])
        command.extend(['--expected-approval-sha256', self.approval_hash])
        result = subprocess.run(command, capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(json.loads(result.stdout)['user_approval_declaration_checked'])

    def test_paths_cannot_escape_root_or_follow_symlinks(self):
        original = copy.deepcopy(self.mapping)
        for name in ('../outside.json', str(self.root / 'profile.json'), './profile.json'):
            self.mapping = copy.deepcopy(original)
            self.mapping['hardware_profile']['path'] = name
            self.save()
            with self.rejected('path'):
                self.check()
        (self.root / 'linked.json').symlink_to(self.root / 'profile.json')
        self.mapping = original
        self.mapping['hardware_profile']['path'] = 'linked.json'
        self.save()
        with self.rejected('symlink forbidden'):
            self.check()

    def test_malformed_json_duplicate_keys_and_missing_fields_fail_cleanly(self):
        for payload in ('{bad', '{"schema": 1, "schema": 2}', '{"value": NaN}', '[]'):
            (self.root / self.mapping_path).write_text(payload)
            with self.assertRaises(CP.PlanningError):
                self.check()
        original = copy.deepcopy(self.mapping)
        for field in ('modules', 'mappings', 'unmapped_nodes', 'scope', 'review', 'hardware_profile'):
            self.mapping = copy.deepcopy(original)
            self.mapping.pop(field)
            self.save()
            with self.assertRaises(CP.PlanningError):
                self.check()

    def test_cli_exit_codes_and_readable_json(self):
        command = [sys.executable, str(SCRIPT), '--root', str(self.root),
                   '--mapping', self.mapping_path, '--bringup', self.plan_path,
                   '--expected-mapping-sha256', self.mapping_hash,
                   '--expected-approval-sha256', self.approval_hash]
        result = subprocess.run(command, capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)['status'], 'passed_structure_only')
        (self.root / self.mapping_path).unlink()
        result = subprocess.run(command, capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(json.loads(result.stdout)['status'], 'blocked')


class RepeatedGraphTest(unittest.TestCase):
    def repeated(self):
        repeat = {'id': 'layers', 'op': 'repeat_template', 'attributes': {
            'template_id': 'decoder', 'count': 2,
            'bindings': [{'instance_id': 'L0'}, {'instance_id': 'L1'}]}}
        return {'schema': 'llm2rtl.model_graph.v1',
                'templates': {'decoder': {'nodes': [{'id': 'q'}, {'id': 'k'}]}},
                'graphs': [{'id': 'prefill', 'nodes': [repeat]},
                           {'id': 'decode', 'nodes': [copy.deepcopy(repeat)]}]}

    def test_repeat_nodes_are_instance_scoped_in_each_graph(self):
        nodes = CP.graph_nodes(self.repeated())
        self.assertEqual(len(nodes), 10)
        self.assertIn(('decode', 'layers/L1/q'), nodes)
        with self.assertRaisesRegex(CP.PlanningError, 'unknown graph/node'):
            CP.node_refs([node('layers/L2/q')], nodes, 'test')

    def test_nested_repeat_paths_do_not_alias_shared_template_instances(self):
        graph = self.repeated()
        graph['templates']['decoder']['nodes'].append({
            'id': 'inner', 'op': 'repeat_template', 'attributes': {
                'template_id': 'inner_body', 'count': 1, 'bindings': [{'instance_id': 'I0'}]}})
        graph['templates']['inner_body'] = {'nodes': [{'id': 'q'}]}
        nodes = CP.graph_nodes(graph)
        self.assertIn(('prefill', 'layers/L0/inner/I0/q'), nodes)
        self.assertIn(('decode', 'layers/L1/inner/I0/q'), nodes)
        self.assertEqual(len(nodes), 18)

    def test_repeat_count_instances_recursion_and_graph_duplicates_rejected(self):
        for mutation in ('count', 'instance', 'template', 'recursion', 'graph', 'node'):
            with self.subTest(mutation=mutation):
                graph = self.repeated()
                repeat = graph['graphs'][0]['nodes'][0]
                attrs = repeat['attributes']
                if mutation == 'count':
                    attrs['count'] = 3
                elif mutation == 'instance':
                    attrs['bindings'][1]['instance_id'] = 'L0'
                elif mutation == 'template':
                    attrs['template_id'] = 'unknown'
                elif mutation == 'recursion':
                    graph['templates']['decoder']['nodes'].append(copy.deepcopy(repeat))
                elif mutation == 'graph':
                    graph['graphs'][1]['id'] = 'prefill'
                else:
                    graph['templates']['decoder']['nodes'].append({'id': 'q'})
                with self.assertRaises(CP.PlanningError):
                    CP.graph_nodes(graph)


if __name__ == '__main__':
    unittest.main()
