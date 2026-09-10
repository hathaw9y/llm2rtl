"""Skill validation and rollback tests use only disposable directories."""
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
import sync_project_skills as sync
from validate_project_skills import validate_skill


class SkillSyncTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='llm2rtl-sync-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source, self.target = self.root / 'source', self.root / 'runtime'
        self.source.mkdir(); self.target.mkdir()
        for name in ('alpha', 'beta'):
            self.make(self.source, name, 'new')
            self.make(self.target, name, 'old')

    def make(self, root, name, body):
        p = root / name
        p.mkdir()
        (p / 'SKILL.md').write_text(f'---\nname: {name}\ndescription: Test skill\n---\n{body}\n')

    def before(self):
        return {n: sync.snapshot(self.target / n) for n in ('alpha', 'beta')}

    def assert_unchanged(self, expected):
        self.assertEqual(expected, self.before())

    def test_same_or_nested_paths_rejected_without_writes(self):
        before = sync.snapshot(self.source)
        for target in (self.source, self.source / 'nested', self.root):
            with self.subTest(target=target), self.assertRaises(ValueError):
                sync.sync(self.source, target)
        self.assertEqual(before, sync.snapshot(self.source))

    def test_symlink_root_and_target_skill_rejected(self):
        alias = self.root / 'alias'; alias.symlink_to(self.source, target_is_directory=True)
        with self.assertRaises(ValueError):
            sync.sync(self.source, alias)
        empty = self.root / 'empty'; empty.mkdir()
        (empty / 'alpha').symlink_to(self.source / 'alpha', target_is_directory=True)
        with self.assertRaises(ValueError):
            sync.sync(self.source, empty, ['alpha'])

    def test_symlink_inside_source_rejected(self):
        (self.source / 'alpha' / 'alias').symlink_to(self.source / 'beta' / 'SKILL.md')
        before = self.before()
        with self.assertRaises(ValueError):
            sync.sync(self.source, self.target)
        self.assert_unchanged(before)

    def test_invalid_skill_blocks_whole_batch_before_writes(self):
        (self.source / 'beta' / 'SKILL.md').write_text('invalid')
        before = sync.snapshot(self.target)
        with self.assertRaises(ValueError):
            sync.sync(self.source, self.target)
        self.assertEqual(before, sync.snapshot(self.target))

    def test_dry_run_does_not_create_root_or_change_existing_files(self):
        before = sync.snapshot(self.target)
        times = {p: p.stat().st_mtime_ns for p in self.target.rglob('*')}
        self.assertEqual(sync.sync(self.source, self.target, dry_run=True)['status'], 'dry_run')
        missing = self.root / 'missing'
        sync.sync(self.source, missing, dry_run=True)
        self.assertFalse(missing.exists())
        self.assertEqual(before, sync.snapshot(self.target))
        self.assertEqual(times, {p: p.stat().st_mtime_ns for p in self.target.rglob('*')})

    def test_external_validator_failure_preserves_existing_targets(self):
        validator = self.root / 'reject.py'
        validator.write_text('raise SystemExit(1)\n')
        before = self.before()
        with self.assertRaises(RuntimeError):
            sync.sync(self.source, self.target, validator=validator)
        self.assert_unchanged(before)

    def test_external_validator_cannot_run_in_dry_run(self):
        before = sync.snapshot(self.target)
        with self.assertRaises(ValueError):
            sync.sync(self.source, self.target, dry_run=True, validator=self.root / 'not_run.py')
        self.assertEqual(before, sync.snapshot(self.target))

    def test_selected_sync_preserves_backup_and_unselected_skill(self):
        before = self.before()
        result = sync.sync(self.source, self.target, ['alpha'])
        self.assertEqual(sync.snapshot(self.source / 'alpha'), sync.snapshot(self.target / 'alpha'))
        self.assertEqual(before['beta'], sync.snapshot(self.target / 'beta'))
        self.assertEqual(before['alpha'], sync.snapshot(Path(result['backup_directory']) / 'previous/alpha'))

    def test_copy_failure_preserves_existing_targets(self):
        before = self.before()
        with patch.object(sync.shutil, 'copytree', side_effect=OSError('copy failure')):
            with self.assertRaises(RuntimeError):
                sync.sync(self.source, self.target)
        self.assert_unchanged(before)

    def test_later_replacement_failure_rolls_back_whole_batch(self):
        before = self.before()
        original = Path.rename
        def fail_install(p, destination):
            if p.parent.name == 'staged' and p.name == 'beta':
                raise OSError('install failure')
            return original(p, destination)
        with patch.object(Path, 'rename', fail_install):
            with self.assertRaises(RuntimeError):
                sync.sync(self.source, self.target)
        self.assert_unchanged(before)
        self.assertFalse((self.target / '.skill-sync.lock').exists())

    def test_interrupt_rolls_back(self):
        before = self.before()
        original = Path.rename
        def interrupt_install(p, destination):
            if p.parent.name == 'staged':
                raise KeyboardInterrupt()
            return original(p, destination)
        with patch.object(Path, 'rename', interrupt_install):
            with self.assertRaises(RuntimeError):
                sync.sync(self.source, self.target)
        self.assert_unchanged(before)

    def test_active_lock_is_not_removed(self):
        lock = self.target / '.skill-sync.lock'; lock.mkdir()
        before = sync.snapshot(self.target)
        with self.assertRaises(FileExistsError):
            sync.sync(self.source, self.target)
        self.assertEqual(before, sync.snapshot(self.target))

    def test_byte_comparison_detects_same_size_and_time_changes(self):
        sync.sync(self.source, self.target)
        p = self.target / 'alpha/SKILL.md'
        old = p.stat()
        p.write_text(p.read_text().replace('new', 'bad'))
        import os
        os.utime(p, ns=(old.st_atime_ns, old.st_mtime_ns))
        self.assertNotEqual(sync.snapshot(self.source / 'alpha'), sync.snapshot(self.target / 'alpha'))

    def test_validator_rejects_bad_name_duplicate_yaml_and_missing_description(self):
        p = self.source / 'alpha/SKILL.md'
        for text in ('---\nname: beta\ndescription: Test\n---\nbody',
                     '---\nname: alpha\nname: alpha\ndescription: Test\n---\nbody',
                     '---\nname: alpha\n---\nbody'):
            p.write_text(text)
            with self.assertRaises(ValueError):
                validate_skill(p.parent)

    def test_cli_without_codex_validator(self):
        cli = [sys.executable, str(ROOT / 'scripts/sync_project_skills.py'),
               'sync', '--project-skills', str(self.source), '--runtime-skills', str(self.target)]
        result = subprocess.run(cli + ['--dry-run'], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        result = subprocess.run(cli, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
