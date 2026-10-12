#!/usr/bin/env python3
"""Check design-time reference identities and authoring extension boundaries."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
INDEX = Path('ip/infrastructure/contracts/reference_templates.json')


class ReferenceError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise ReferenceError(message)


def read_index(path):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, f'duplicate JSON key: {key}')
            result[key] = value
        return result
    return json.loads(path.read_text(encoding='utf-8'), object_pairs_hook=unique)


def pinned_file(root, record):
    require(isinstance(record, dict), 'reference record required')
    relative, expected = record.get('path'), record.get('sha256')
    require(isinstance(relative, str), 'relative reference path required')
    path = Path(relative)
    require(not path.is_absolute() and '..' not in path.parts
            and path.as_posix() == relative, f'unsafe reference: {relative}')
    source = root / path
    require(source.is_file() and not source.is_symlink()
            and source.resolve() == source, f'regular reference required: {relative}')
    require(isinstance(expected, str) and re.fullmatch(r'[0-9a-f]{64}', expected),
            f'invalid reference SHA-256: {relative}')
    require(hashlib.sha256(source.read_bytes()).hexdigest() == expected,
            f'reference SHA-256 mismatch: {relative}')
    return source


def check(root=ROOT):
    root = Path(root).resolve()
    index = read_index(root / INDEX)
    require(index.get('schema') == 'llm2rtl.design_reference_templates.v1',
            'unsupported design-reference schema')
    require(index.get('scope') == 'design_inputs_not_generated_model',
            'reference scope must exclude generated model claims')
    require(index.get('default_control_family') == 'native_reference_engine',
            'native reference controller/engine family required')
    templates = index.get('templates')
    require(isinstance(templates, dict) and set(templates) == {'controller', 'executor_engine', 'fabric'},
            'controller, per-operation engine and native fabric required')
    checked = []
    for name, record in templates.items():
        path = pinned_file(root, record)
        require(path.parent == root / 'ip/infrastructure/templates'
                and path.name.endswith('.sv.tpl'), f'authoring template path required: {name}')
        text = path.read_text(encoding='utf-8')
        tokens = record.get('name_tokens')
        require(isinstance(tokens, list) and tokens
                and len(tokens) == len(set(tokens)), f'name tokens required: {name}')
        for token in tokens + record.get('required_render_tokens', []):
            require(isinstance(token, str) and re.fullmatch(r'__[A-Z_]+__', token)
                    and token in text, f'missing render token: {name}: {token}')
        regions = record.get('extension_regions')
        require(isinstance(regions, list) and regions
                and len(regions) == len(set(regions)), f'extension regions required: {name}')
        for region in regions:
            require(isinstance(region, str) and re.fullmatch(r'USER_[A-Z_]+', region),
                    f'invalid extension region: {name}: {region}')
            begin, end = region + '_BEGIN', region + '_END'
            require(text.count(begin) == 1 and text.count(end) == 1
                    and text.index(begin) < text.index(end),
                    f'extension region must occur once and in order: {name}: {region}')
        checked.append(record['path'])
    for name in ('native_bank_contract', 'engine_completion_contract'):
        checked.append(str(pinned_file(root, index[name]).relative_to(root)))
    bank_templates = index.get('bank_templates')
    require(isinstance(bank_templates, list) and {r.get('path') for r in bank_templates} == {
        'ip/infrastructure/templates/bank_config_pkg.sv.tpl',
        'ip/infrastructure/templates/bank_subsystem.sv.tpl'}, 'native bank templates required')
    for record in bank_templates:
        checked.append(str(pinned_file(root, record).relative_to(root)))
    examples = index.get('source_examples')
    require(isinstance(examples, list) and examples, 'captured reference source examples required')
    for record in examples:
        source = pinned_file(root, record)
        require('ip/infrastructure/references/' in record['path'], 'captured example path required')
        checked.append(str(source.relative_to(root)))
    for record in index.get('compatibility_inputs', []):
        checked.append(str(pinned_file(root, record).relative_to(root)))
    return {'status': 'passed_reference_identity_and_structure',
            'default_control_family': index['default_control_family'],
            'template_count': len(templates), 'source_example_count': len(examples),
            'checked_inputs': checked,
            'limitations': 'Identity and authoring structure only; rendered RTL requires simulation/lint and model-specific verification.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=ROOT)
    args = parser.parse_args()
    try:
        print(json.dumps(check(args.root), ensure_ascii=False, indent=2))
    except (ReferenceError, OSError, ValueError, KeyError, TypeError) as error:
        parser.exit(1, f'design references: {error}\n')


if __name__ == '__main__':
    main()
