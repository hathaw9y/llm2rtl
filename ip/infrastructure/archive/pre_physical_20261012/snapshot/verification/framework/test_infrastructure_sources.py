import copy
import importlib.util
import json
import os
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
        for record in self.manifest['sources'].values():
            source = self.root / record['path']
            source.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / record['path'], source)
            view = self.root / record['navigation_view']
            view.parent.mkdir(parents=True, exist_ok=True)
            view.symlink_to(os.path.relpath(source, view.parent))
        path = self.root / SOURCES.MANIFEST
        path.write_text(json.dumps(self.manifest))

    def test_dependency_order_and_regular_original_paths(self):
        paths = SOURCES.resolve_profile('legacy_fabric', self.root)
        ids = [path.stem for path in paths]
        self.assertEqual(len(paths), len(set(paths)))
        self.assertLess(ids.index('bank_config_pkg'), ids.index('bank_sparse_router'))
        self.assertLess(ids.index('datamover_engine_pkg'), ids.index('datamover_engine'))
        self.assertLess(ids.index('fifo'), ids.index('datamover_command_queue'))
        self.assertTrue(all(not p.is_symlink() and p.resolve() == p for p in paths))

    def test_modified_rtl_is_not_silently_repinned(self):
        path = self.root / self.manifest['sources']['fifo']['path']
        path.write_bytes(path.read_bytes() + b'\n')
        with self.assertRaisesRegex(SOURCES.SourceError, 'SHA-256 mismatch'):
            SOURCES.resolve_profile('adapters', self.root)

    def test_alias_plus_original_profile_is_rejected(self):
        self.manifest['profiles']['adapters']['roots'].append(
            self.manifest['sources']['mm2s_adapter']['navigation_view'])
        with self.assertRaisesRegex(SOURCES.SourceError, 'source IDs, not path aliases'):
            SOURCES.resolve_profile('adapters', self.root, self.manifest)

    def test_original_symlink_is_rejected(self):
        record = self.manifest['sources']['fifo']
        source = self.root / record['path']
        saved = source.with_suffix('.saved')
        source.rename(saved)
        source.symlink_to(saved.name)
        with self.assertRaisesRegex(SOURCES.SourceError, 'regular source required'):
            SOURCES.resolve_profile('adapters', self.root)

    def test_redirected_view_is_rejected(self):
        view = self.root / self.manifest['sources']['fifo']['navigation_view']
        view.unlink()
        target = self.root / self.manifest['sources']['pipeline']['path']
        view.symlink_to(os.path.relpath(target, view.parent))
        with self.assertRaisesRegex(SOURCES.SourceError, 'invalid navigation link'):
            SOURCES.validate_inventory(self.root)

    def test_cycle_is_rejected(self):
        self.manifest['sources']['fifo']['depends_on'] = ['datamover_command_queue']
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


if __name__ == '__main__':
    unittest.main()
