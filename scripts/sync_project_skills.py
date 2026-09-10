#!/usr/bin/env python3
"""Validate and safely sync project Skills. Existing targets are backed up."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile
from pathlib import Path

from validate_project_skills import validate_skill

REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_PROJECT_SKILLS = REPO_ROOT / 'skills'
DEFAULT_RUNTIME_SKILLS = Path(os.environ.get('CODEX_HOME', Path.home() / '.codex')) / 'skills'


def safe_path(value):
    p = Path(os.path.abspath(value))
    for q in (p, *p.parents):
        if q.is_symlink():
            raise ValueError(f'Symlink path rejected: {q}')
    return p.resolve()


def snapshot(root):
    if not root.exists():
        return None
    if root.is_symlink() or not root.is_dir():
        raise ValueError(f'Expected real directory: {root}')
    result = {}
    for p in sorted(root.rglob('*')):
        mode = p.lstat().st_mode
        if stat.S_ISLNK(mode) or not (stat.S_ISREG(mode) or stat.S_ISDIR(mode)):
            raise ValueError(f'Non-regular entry rejected: {p}')
        result[p.relative_to(root).as_posix()] = (
            hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else 'directory')
    return result


def skill_dirs(source, selected=None):
    if not source.is_dir():
        raise ValueError(f'Missing source Skills: {source}')
    if selected:
        if len(selected) != len(set(selected)):
            raise ValueError('Duplicate selected Skill')
        for name in selected:
            if not re.fullmatch(r'[a-z0-9]+(?:-[a-z0-9]+)*', name):
                raise ValueError(f'Invalid selected Skill: {name}')
        paths = [source / n for n in sorted(selected)]
    else:
        paths = sorted(p for p in source.iterdir() if not p.name.startswith('.'))
    if not paths:
        raise ValueError('No Skills selected')
    return paths


def preflight(source, target=None, selected=None):
    source = safe_path(source)
    if target is not None:
        target = safe_path(target)
        if source == target or source in target.parents or target in source.parents:
            raise ValueError('Source and target must be disjoint, non-nested directories')
        if target.exists() and not target.is_dir():
            raise ValueError('Target root is not a directory')
    skills = skill_dirs(source, selected)
    sources, targets, names = {}, {}, []
    for skill in skills:
        sources[skill.name] = snapshot(skill)
        names.append(validate_skill(skill))
        if target is not None:
            safe_path(target / skill.name)
            targets[skill.name] = snapshot(target / skill.name)
    if len(set(names)) != len(names):
        raise ValueError('Duplicate Skill names')
    return source, target, skills, sources, targets


def sync(source, target, selected=None, dry_run=False, validator=None):
    source, target, skills, sources, targets = preflight(source, target, selected)
    if dry_run and validator:
        raise ValueError('--dry-run cannot execute an external validator; use the bundled validator')
    if validator:
        validator = safe_path(validator)
        if not validator.is_file():
            raise ValueError(f'Missing optional validator: {validator}')
    plan = [{'skill': p.name, 'action': 'replace_with_backup' if targets[p.name] is not None else 'install'}
            for p in skills]
    if dry_run:
        return {'status': 'dry_run', 'plan': plan, 'writes': False}
    target.mkdir(parents=True, exist_ok=True)
    lock = target / '.skill-sync.lock'
    lock.mkdir()  # Do not remove another process's lock or take it over automatically.
    session = None
    changes = []
    try:
        session = Path(tempfile.mkdtemp(prefix='.skill-sync-backup-', dir=target))
        staged, previous, failed = session / 'staged', session / 'previous', session / 'failed'
        staged.mkdir(); previous.mkdir(); failed.mkdir()
        for skill in skills:
            copy = staged / skill.name
            shutil.copytree(skill, copy, symlinks=True)
            validate_skill(copy)
            if validator:
                subprocess.run([sys.executable, str(validator), str(copy)], check=True)
            if snapshot(copy) != sources[skill.name]:
                raise ValueError(f'Staged copy mismatch: {skill.name}')
        # Finish validation of the whole batch before changing any selected target.
        for skill in skills:
            safe_path(skill); safe_path(target / skill.name)
            if snapshot(skill) != sources[skill.name] or snapshot(target / skill.name) != targets[skill.name]:
                raise ValueError(f'Source or target changed during staging: {skill.name}')
        for skill in skills:
            name = skill.name
            destination, backup = target / name, previous / name
            change = {'name': name, 'backed_up': False, 'installed': False}
            changes.append(change)
            if targets[name] is not None:
                destination.rename(backup)
                change['backed_up'] = True
            (staged / name).rename(destination)
            change['installed'] = True
            if snapshot(destination) != sources[name]:
                raise ValueError(f'Installed copy mismatch: {name}')
        return {'status': 'synced', 'plan': plan, 'backup_directory': str(session)}
    except BaseException as error:
        rollback_errors = []
        for change in reversed(changes):
            name = change['name']
            destination = target / name
            try:
                if change['installed']:
                    destination.rename(session / 'failed' / name)
                if change['backed_up']:
                    if destination.exists() or destination.is_symlink():
                        raise ValueError(f'Restore target occupied: {destination}')
                    (session / 'previous' / name).rename(destination)
            except Exception as rollback_error:
                rollback_errors.append(str(rollback_error))
        raise RuntimeError(f'Sync failed: {error}; recovery directory: {session}; '
                           f'rollback errors: {rollback_errors}') from error
    finally:
        lock.rmdir()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('check', 'sync', 'validate'), nargs='?', default='check')
    parser.add_argument('--project-skills', type=Path, default=DEFAULT_PROJECT_SKILLS)
    parser.add_argument('--runtime-skills', type=Path, default=DEFAULT_RUNTIME_SKILLS)
    parser.add_argument('--validator', type=Path,
                        help='Optional additional trusted Python validator; bundled checks always run')
    parser.add_argument('--skill', action='append')
    parser.add_argument('--dry-run', action='store_true', help='Plan sync without writes')
    args = parser.parse_args()
    try:
        if args.dry_run and args.action != 'sync':
            raise ValueError('--dry-run applies only to sync')
        if args.validator and args.action != 'sync':
            raise ValueError('--validator applies only to sync on staged copies')
        if args.action == 'sync':
            result = sync(args.project_skills, args.runtime_skills, args.skill,
                          args.dry_run, args.validator)
        else:
            _, target, skills, sources, targets = preflight(
                args.project_skills, args.runtime_skills if args.action == 'check' else None, args.skill)
            if args.action == 'check':
                mismatches = [p.name for p in skills if sources[p.name] != targets[p.name]]
                if mismatches:
                    raise ValueError(f'Skill content mismatch: {mismatches}')
            result = {'status': 'passed', 'action': args.action, 'skills': len(skills)}
        print(json.dumps(result, indent=2))
        return 0
    except (ValueError, OSError, RuntimeError, subprocess.CalledProcessError) as error:
        print(json.dumps({'status': 'failed', 'error': str(error)}))
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
