#!/usr/bin/env python3
"""Resolve bounded infrastructure profiles to the original regular RTL files."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = Path('ip/infrastructure/sources.json')
ROLES = {'bank', 'datamover', 'controller', 'utils', 'integration'}


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
    require(len(path.parts) == 5 and path.parts[:2] == ('ip', 'infrastructure')
            and path.parts[2] not in ('rtl', 'evidence')
            and path.parts[3] == 'rtl' and path.suffix == '.sv',
            f'original packet RTL path required: {relative}')
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


def validate_inventory(root=ROOT, manifest=None):
    root = Path(root).resolve()
    manifest = load_manifest(root) if manifest is None else manifest
    require(manifest.get('schema') == 'llm2rtl.infrastructure_sources.v1',
            'invalid source manifest schema')
    require(manifest.get('navigation_only') is True, 'views must be navigation only')
    sources = manifest.get('sources')
    require(isinstance(sources, dict) and sources, 'source inventory required')
    paths, symbols, views, roles = set(), set(), set(), {}
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
        view_relative = f'ip/infrastructure/rtl/{role}/{source.name}'
        require(record.get('navigation_view') == view_relative, f'view path mismatch: {sid}')
        view = root / view_relative
        require(view.is_symlink() and not Path(os.readlink(view)).is_absolute()
                and view.resolve() == source, f'invalid navigation link: {view_relative}')
        views.add(view)
        roles[role] = roles.get(role, 0) + 1
    base = root / 'ip/infrastructure'
    actual = {p for directory in base.iterdir()
              if directory.is_dir() and directory.name not in ('rtl', 'evidence')
              for p in (directory / 'rtl').glob('*.sv')}
    require(actual == paths, 'manifest must cover exactly the active original RTL inventory')
    actual_views = {p for role in ROLES for p in (base / 'rtl' / role).glob('*.sv')}
    require(actual_views == views, 'unlisted or missing navigation view')
    _ordered_ids(list(sources), sources)
    profiles = manifest.get('profiles')
    require(isinstance(profiles, dict) and profiles, 'profiles required')
    for profile, record in profiles.items():
        require(isinstance(record, dict), f'invalid profile: {profile}')
        _ordered_ids(record.get('roots'), sources)
    return {'status': 'passed_source_inventory', 'source_count': len(paths),
            'navigation_link_count': len(views), 'roles': roles,
            'profile_count': len(profiles),
            'limitations': 'Source paths, hashes and declared dependencies only; no RTL correctness or timing claim.'}


def resolve_profile(profile, root=ROOT, manifest=None):
    root = Path(root).resolve()
    manifest = load_manifest(root) if manifest is None else manifest
    validate_inventory(root, manifest)
    require(profile in manifest['profiles'], f'unknown profile: {profile}')
    ids = _ordered_ids(manifest['profiles'][profile]['roots'], manifest['sources'])
    return [regular_source(root, manifest['sources'][sid]['path']) for sid in ids]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--profile', default='all')
    parser.add_argument('--format', choices=('json', 'filelist', 'tcl'), default='json')
    args = parser.parse_args()
    try:
        root = args.root.resolve()
        manifest = load_manifest(root)
        if args.check:
            print(json.dumps(validate_inventory(root, manifest), indent=2))
            return
        paths = resolve_profile(args.profile, root, manifest)
        if args.format == 'filelist':
            print('\n'.join(str(path) for path in paths))
        elif args.format == 'tcl':
            for path in paths:
                require(not any(c in str(path) for c in '{}\n\r'), 'unsupported Tcl path')
                print('read_verilog -sv {' + str(path) + '}')
        else:
            print(json.dumps({'profile': args.profile, 'source_order': [
                {'path': str(path.relative_to(root)),
                 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
                for path in paths], 'navigation_paths_used_for_build': False}, indent=2))
    except (SourceError, OSError, TypeError, KeyError, ValueError) as error:
        parser.exit(1, f'infrastructure sources: {error}\n')


if __name__ == '__main__':
    main()
