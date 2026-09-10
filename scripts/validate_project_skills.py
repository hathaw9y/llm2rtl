#!/usr/bin/env python3
"""Validate project Skill frontmatter without a Codex installation."""
from __future__ import annotations

import argparse
import re
from pathlib import Path


def validate_skill(folder: Path) -> str:
    try:
        import yaml
    except ImportError as error:
        raise ValueError('Install dependencies: python3 -m pip install -r requirements.txt') from error
    file = folder / 'SKILL.md'
    if not file.is_file():
        raise ValueError(f'Missing SKILL.md: {folder}')
    lines = file.read_text(encoding='utf-8').splitlines()
    if not lines or lines[0] != '---' or '---' not in lines[1:]:
        raise ValueError(f'Invalid frontmatter delimiters: {file}')
    end = lines.index('---', 1)
    class UniqueLoader(yaml.SafeLoader):
        pass
    def mapping(loader, node, deep=False):
        result = {}
        for key_node, value_node in node.value:
            key = loader.construct_object(key_node, deep=deep)
            if not isinstance(key, str) or key in result:
                raise ValueError(f'Non-string or duplicate YAML key: {file}')
            result[key] = loader.construct_object(value_node, deep=deep)
        return result
    UniqueLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, mapping)
    try:
        data = yaml.load('\n'.join(lines[1:end]), Loader=UniqueLoader)
    except yaml.YAMLError as error:
        raise ValueError(f'Invalid YAML: {file}: {error}') from error
    if not isinstance(data, dict):
        raise ValueError(f'Frontmatter must be a mapping: {file}')
    name = data.get('name')
    if (not isinstance(name, str) or len(name) > 64 or
            not re.fullmatch(r'[a-z0-9]+(?:-[a-z0-9]+)*', name)):
        raise ValueError(f'Invalid Skill name: {file}')
    if name != folder.name:
        raise ValueError(f'Skill name/directory mismatch: {file}')
    if not isinstance(data.get('description'), str) or not data['description'].strip():
        raise ValueError(f'Nonempty description required: {file}')
    if not '\n'.join(lines[end + 1:]).strip():
        raise ValueError(f'Empty Skill instructions: {file}')
    return name


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folders', type=Path, nargs='+')
    args = parser.parse_args()
    try:
        names = [validate_skill(p) for p in args.folders]
        if len(set(names)) != len(names):
            raise ValueError('Duplicate Skill names')
        print(f'PASS: {len(names)} Skill(s); format only, not semantic validation')
        return 0
    except (ValueError, OSError, UnicodeError) as error:
        print(f'FAIL: {error}')
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
