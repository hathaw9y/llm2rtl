#!/usr/bin/env python3
"""Resolve bounded profiles to physical role-based infrastructure RTL files."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = Path('ip/infrastructure/sources.json')
ROLES = {'bank', 'datamover', 'controller', 'utils'}


class SourceError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise SourceError(message)


def load_manifest(root=ROOT):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, f'duplicate JSON key: {key}')
            result[key] = value
        return result
    return json.loads((Path(root) / MANIFEST).read_text(), object_pairs_hook=unique)


def regular_source(root, relative):
    require(isinstance(relative, str) and relative, 'source path required')
    path = Path(relative)
    require(not path.is_absolute() and '..' not in path.parts
            and path.as_posix() == relative, f'unsafe source path: {relative}')
    require(len(path.parts) == 4 and path.parts[:2] == ('ip', 'infrastructure')
            and path.parts[2] in ROLES and path.suffix == '.sv',
            f'physical role RTL path required: {relative}')
    result = root / path
    require(result.is_file() and not result.is_symlink()
            and result.resolve() == result, f'regular source required: {relative}')
    return result


def _ordered_ids(roots, sources):
    require(isinstance(roots, list) and roots, 'nonempty profile roots required')
    require(all(isinstance(sid, str) and sid in sources for sid in roots),
            'profile must use source IDs, not path aliases')
    require(len(roots) == len(set(roots)), 'duplicate profile root')
    ordered, active, visited = [], set(), set()

    def visit(sid):
        require(sid not in active, f'dependency cycle: {sid}')
        if sid in visited:
            return
        active.add(sid)
        for dependency in sources[sid]['depends_on']:
            visit(dependency)
        active.remove(sid)
        visited.add(sid)
        ordered.append(sid)

    for sid in roots:
        visit(sid)
    return ordered


def validate_inventory(root=ROOT, manifest=None, include_compatibility=False):
    root = Path(root).resolve()
    manifest = load_manifest(root) if manifest is None else manifest
    require(manifest.get('schema') == 'llm2rtl.infrastructure_sources.v2',
            'invalid source manifest schema')
    sources = manifest.get('sources')
    require(isinstance(sources, dict) and sources, 'source inventory required')
    paths, symbols, roles = set(), set(), {}
    for sid, record in sources.items():
        require(isinstance(record, dict) and record.get('role') in ROLES,
                f'invalid source role: {sid}')
        source = regular_source(root, record.get('path'))
        require(source not in paths, f'duplicate original source: {source}')
        paths.add(source)
        require(hashlib.sha256(source.read_bytes()).hexdigest() == record.get('sha256'),
                f'source SHA-256 mismatch: {record["path"]}')
        text = re.sub(r'/\*.*?\*/|//[^\n]*', '', source.read_text(), flags=re.S)
        declarations = re.findall(r'^\s*(?:module|package)\s+(\w+)', text, flags=re.M)
        require(declarations == [sid], f'one matching declaration required: {sid}')
        require(sid not in symbols, f'duplicate declaration: {sid}')
        symbols.add(sid)
        dependencies = record.get('depends_on')
        require(isinstance(dependencies, list)
                and all(isinstance(dep, str) and dep in sources for dep in dependencies)
                and len(dependencies) == len(set(dependencies)),
                f'invalid dependencies: {sid}')
        role = record['role']
        require(source.parent.name == role, f'physical role mismatch: {sid}')
        roles[role] = roles.get(role, 0) + 1
    base = root / 'ip/infrastructure'
    actual = {p for role in ROLES for p in (base / role).glob('*.sv')}
    require(actual == paths, 'manifest must cover exactly the active original RTL inventory')
    require(not (base / 'rtl').exists(), 'obsolete navigation view must be removed')
    _ordered_ids(list(sources), sources)
    profiles = manifest.get('profiles')
    require(isinstance(profiles, dict) and profiles, 'profiles required')
    for profile, record in profiles.items():
        require(isinstance(record, dict), f'invalid profile: {profile}')
        _ordered_ids(record.get('roots'), sources)
    compatibility_count = 0
    if include_compatibility:
        compatibility = manifest.get('compatibility_sources', {})
        compatibility_profiles = manifest.get('compatibility_profiles', {})
        require(isinstance(compatibility, dict) and compatibility,
                'compatibility source inventory required')
        for sid, record in compatibility.items():
            relative = record.get('path')
            require(isinstance(relative, str) and (
                relative.startswith('ip/infrastructure/archive/') or sid in sources),
                f'compatibility source must be archived or retained: {sid}')
            source = resolve_reference(relative, root, record.get('sha256'))
            text = re.sub(r'/\*.*?\*/|//[^\n]*', '', source.read_text(), flags=re.S)
            require(re.findall(r'^\s*(?:module|package)\s+(\w+)', text, flags=re.M) == [sid],
                    f'one matching compatibility declaration required: {sid}')
            dependencies = record.get('depends_on')
            require(isinstance(dependencies, list) and
                    all(dep in compatibility for dep in dependencies) and
                    len(dependencies) == len(set(dependencies)),
                    f'invalid compatibility dependencies: {sid}')
            if sid in sources:
                require(record == sources[sid], f'retained source compatibility pin differs: {sid}')
        require(isinstance(compatibility_profiles, dict) and compatibility_profiles,
                'compatibility profiles required')
        _ordered_ids(list(compatibility), compatibility)
        for profile, record in compatibility_profiles.items():
            _ordered_ids(record.get('roots'), compatibility)
        compatibility_count = len(compatibility)
    return {'status': 'passed_source_inventory', 'source_count': len(paths),
            'navigation_link_count': 0, 'roles': roles,
            'profile_count': len(profiles),
            'compatibility_included': include_compatibility,
            'compatibility_source_count': compatibility_count,
            'limitations': 'Source paths, hashes and declared dependencies only; no RTL correctness or timing claim.'}


def resolve_profile(profile, root=ROOT, manifest=None, include_compatibility=False):
    root = Path(root).resolve()
    manifest = load_manifest(root) if manifest is None else manifest
    validate_inventory(root, manifest, include_compatibility=include_compatibility)
    if include_compatibility and profile in manifest.get('compatibility_profiles', {}):
        sources = manifest['compatibility_sources']
        ids = _ordered_ids(manifest['compatibility_profiles'][profile]['roots'], sources)
        return [resolve_reference(sources[sid]['path'], root, sources[sid]['sha256']) for sid in ids]
    require(profile in manifest['profiles'], f'unknown profile: {profile}')
    ids = _ordered_ids(manifest['profiles'][profile]['roots'], manifest['sources'])
    return [regular_source(root, manifest['sources'][sid]['path']) for sid in ids]


def resolve_reference(path, root=ROOT, expected_sha256=None):
    """Resolve a frozen old reference without rewriting its declared source pin."""
    root = Path(root).resolve()
    path = Path(path)
    if path.is_absolute():
        try:
            path = path.relative_to(root)
        except ValueError as error:
            raise SourceError(f'reference outside repository: {path}') from error
    require('..' not in path.parts, f'unsafe reference: {path}')
    relative = path.as_posix()
    migration = json.loads((root / 'ip/infrastructure/migration.json').read_text())
    require(migration.get('schema') == 'llm2rtl.infrastructure_relocation.v1',
            'invalid relocation manifest')
    record = migration['relocations'].get(relative)
    if record is not None:
        relative = record['path']
        if expected_sha256 is None:
            expected_sha256 = record['sha256']
    elif any(relative.startswith(prefix) for prefix in migration['archived_prefixes']):
        relative = migration['snapshot_root'] + '/' + relative
    target = Path(relative)
    require(not target.is_absolute() and '..' not in target.parts,
            f'unsafe relocated reference: {target}')
    result = root / target
    require(result.is_file() and not result.is_symlink() and result.resolve() == result,
            f'regular relocated reference required: {target}')
    if expected_sha256 is not None:
        require(hashlib.sha256(result.read_bytes()).hexdigest() == expected_sha256,
                f'relocated reference SHA-256 mismatch: {target}')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--profile', default='all')
    parser.add_argument('--include-compatibility', action='store_true',
                        help='explicitly use archived pre-removal source profiles')
    parser.add_argument('--format', choices=('json', 'filelist', 'tcl'), default='json')
    args = parser.parse_args()
    try:
        root = args.root.resolve()
        manifest = load_manifest(root)
        if args.check:
            print(json.dumps(validate_inventory(root, manifest,
                             include_compatibility=args.include_compatibility), indent=2))
            return
        paths = resolve_profile(args.profile, root, manifest,
                                include_compatibility=args.include_compatibility)
        if args.format == 'filelist':
            print('\n'.join(str(path) for path in paths))
        elif args.format == 'tcl':
            for path in paths:
                require(not any(c in str(path) for c in '{}\n\r'), 'unsupported Tcl path')
                print('read_verilog -sv {' + str(path) + '}')
        else:
            print(json.dumps({'profile': args.profile, 'compatibility_included': args.include_compatibility,
                'source_order': [
                {'path': str(path.relative_to(root)),
                 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
                for path in paths], 'navigation_paths_used_for_build': False}, indent=2))
    except (SourceError, OSError, TypeError, KeyError, ValueError) as error:
        parser.exit(1, f'infrastructure sources: {error}\n')


if __name__ == '__main__':
    main()
