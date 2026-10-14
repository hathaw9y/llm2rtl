import copy
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    'infrastructure_sources_test', ROOT / 'scripts/infrastructure_sources.py')
SOURCES = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SOURCES)


class InfrastructureSourcesTest(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory(prefix='infrastructure-sources-')
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        self.manifest = copy.deepcopy(SOURCES.load_manifest())
        for record in {**self.manifest['compatibility_sources'], **self.manifest['sources']}.values():
            source = self.root / record['path']
            source.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / record['path'], source)
        path = self.root / SOURCES.MANIFEST
        path.write_text(json.dumps(self.manifest))
        shutil.copyfile(ROOT / 'ip/infrastructure/migration.json',
                        self.root / 'ip/infrastructure/migration.json')

    def test_dependency_order_and_regular_original_paths(self):
        paths = SOURCES.resolve_profile('banks', self.root)
        ids = [path.stem for path in paths]
        self.assertEqual(len(paths), len(set(paths)))
        self.assertLess(ids.index('bram_bank'), ids.index('bank_native_memories'))
        self.assertLess(ids.index('bank_read_arbit'), ids.index('bank_arbiter'))
        self.assertTrue(all(not p.is_symlink() and p.resolve() == p for p in paths))

    def test_modified_rtl_is_not_silently_repinned(self):
        path = self.root / self.manifest['sources']['fifo']['path']
        path.write_bytes(path.read_bytes() + b'\n')
        with self.assertRaisesRegex(SOURCES.SourceError, 'SHA-256 mismatch'):
            SOURCES.resolve_profile('support', self.root)

    def test_alias_plus_original_profile_is_rejected(self):
        self.manifest['profiles']['support']['roots'].append(
            self.manifest['sources']['fifo']['path'])
        with self.assertRaisesRegex(SOURCES.SourceError, 'source IDs, not path aliases'):
            SOURCES.resolve_profile('support', self.root, self.manifest)

    def test_original_symlink_is_rejected(self):
        record = self.manifest['sources']['fifo']
        source = self.root / record['path']
        saved = source.with_suffix('.saved')
        source.rename(saved)
        source.symlink_to(saved.name)
        with self.assertRaisesRegex(SOURCES.SourceError, 'regular source required'):
            SOURCES.resolve_profile('support', self.root)

    def test_obsolete_navigation_tree_is_rejected(self):
        (self.root / 'ip/infrastructure/rtl').mkdir()
        with self.assertRaisesRegex(SOURCES.SourceError, 'obsolete navigation view'):
            SOURCES.validate_inventory(self.root)

    def test_cycle_is_rejected(self):
        self.manifest['sources']['fifo']['depends_on'] = ['pipeline']
        self.manifest['sources']['pipeline']['depends_on'] = ['fifo']
        with self.assertRaisesRegex(SOURCES.SourceError, 'dependency cycle'):
            SOURCES.validate_inventory(self.root, self.manifest)

    def test_duplicate_original_definition_is_rejected(self):
        self.manifest['sources']['pipeline']['path'] = self.manifest['sources']['fifo']['path']
        with self.assertRaisesRegex(SOURCES.SourceError, 'duplicate original source'):
            SOURCES.validate_inventory(self.root, self.manifest)

    def test_unlisted_active_source_requires_manifest_update(self):
        source = self.root / self.manifest['sources']['fifo']['path']
        shutil.copyfile(source, source.with_name('unlisted.sv'))
        with self.assertRaisesRegex(SOURCES.SourceError, 'exactly the active original RTL'):
            SOURCES.validate_inventory(self.root)

    def test_frozen_old_source_reference_resolves_to_same_bytes(self):
        old = 'ip/infrastructure/datamover_engine/rtl/uram_bank.sv'
        expected = self.manifest['sources']['uram_bank']['sha256']
        resolved = SOURCES.resolve_reference(old, self.root, expected_sha256=expected)
        self.assertEqual(resolved, self.root / 'ip/infrastructure/bank/uram_bank.sv')

    def test_frozen_reference_hash_mismatch_is_rejected(self):
        with self.assertRaisesRegex(SOURCES.SourceError, 'relocated reference SHA-256 mismatch'):
            SOURCES.resolve_reference('ip/infrastructure/datamover_engine/rtl/uram_bank.sv',
                                      self.root, expected_sha256='0' * 64)

    def test_archive_definitions_are_excluded_from_active_closure(self):
        source = self.root / self.manifest['sources']['fifo']['path']
        archived = self.root / 'ip/infrastructure/archive/old/fifo.sv'
        archived.parent.mkdir(parents=True)
        shutil.copyfile(source, archived)
        paths = SOURCES.resolve_profile('all', self.root)
        self.assertNotIn(archived, paths)
        self.assertEqual(len(paths), len(self.manifest['sources']))

    def test_removed_components_require_explicit_compatibility(self):
        with self.assertRaisesRegex(SOURCES.SourceError, 'unknown profile'):
            SOURCES.resolve_profile('dma_integration', self.root)
        active = SOURCES.resolve_profile('all', self.root)
        removed = set(self.manifest['reference_style_removed_source_ids'])
        self.assertFalse(removed & {p.stem for p in active})
        paths = SOURCES.resolve_profile('dma_integration', self.root, include_compatibility=True)
        ids = [p.stem for p in paths]
        self.assertLess(ids.index('fifo'), ids.index('datamover_command_queue'))
        self.assertLess(ids.index('datamover_engine_pkg'), ids.index('datamover_engine'))
        self.assertTrue(any('/archive/' in str(p) for p in paths))

    def test_modified_archived_component_is_rejected(self):
        r = self.manifest['compatibility_sources']['datamover_command_queue']
        p = self.root / r['path']
        p.write_bytes(p.read_bytes() + b'\n')
        with self.assertRaisesRegex(SOURCES.SourceError, 'SHA-256 mismatch'):
            SOURCES.resolve_profile('command_queue', self.root, include_compatibility=True)


if __name__ == '__main__':
    unittest.main()
