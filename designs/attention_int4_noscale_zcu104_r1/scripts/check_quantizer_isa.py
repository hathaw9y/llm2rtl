#!/usr/bin/env python3
"""Pin validation for the standalone ISA quantizer integration packet.

This is a scoped operator declaration/identity gate, not simulation or signoff.
It uses the repository's current minimal contracts; no legacy planning hierarchy.
"""
from pathlib import Path
import argparse,hashlib,json,sys
BASE=Path(__file__).resolve().parents[1]
ROOT=BASE.parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
from infrastructure_sources import resolve_reference
PACKET=BASE/'modules/attention_quantizer_isa.json'
EXPECTED='cb0734d094aaa449f4f1cdcee01ac0f3cc43aac427bc1aab0288d7850d027a47'


def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()


def check(root=ROOT,require_rtl=False):
    root=Path(root).resolve()
    base=root/'designs/attention_int4_noscale_zcu104_r1'
    path=base/'modules/attention_quantizer_isa.json'
    if not path.is_file() or path.is_symlink() or digest(path)!=EXPECTED:
        raise ValueError('integration packet identity mismatch')
    doc=json.loads(path.read_text())
    if doc['status']!='frozen':raise ValueError('packet is not frozen')
    pins={}
    for name in ['child','child_contract','child_independent_review','native_contract','controller_contract','controller_index']:
        ref=doc[name];pins[ref['path']]=ref['sha256']
    pins.update(doc['common_contracts'])
    amendment='designs/attention_int4_noscale_zcu104_r1/modules/attention_quantizer_isa_generation_addendum.json'
    pins[amendment]='ab828c7a28def8494661c4f17378a20d265028160dd0626989a22132cc1b6de1'
    addendum=json.loads((root/amendment).read_text())
    if addendum.get('status')!='approved_by_parent' or addendum['parent_packet']['sha256']!=EXPECTED:
        raise ValueError('configuration addendum identity mismatch')
    for name,wanted in pins.items():
        relative=Path(name)
        if relative.is_absolute() or '..' in relative.parts:
            raise ValueError('unsafe pin path')
        source=resolve_reference(relative,root=root,expected_sha256=wanted)
        if not source.is_file() or source.is_symlink() or digest(source)!=wanted:
            raise ValueError('pinned input identity mismatch: '+name)
    if doc['isa']['opcodes']!={'END':0,'MM2S':1,'S2MM':2,'QUANTIZE':3}:
        raise ValueError('opcode mapping mismatch')
    if json.loads(resolve_reference(doc['controller_contract']['path'],root=root,
        expected_sha256=doc['controller_contract']['sha256']).read_text())['version']!=4:
        raise ValueError('requires completion-qualified controller v4')
    generated={}
    if require_rtl:
        for relative in doc['generated_sources']:
            p=base/relative
            if not p.is_file() or p.is_symlink():raise ValueError('missing generated source: '+relative)
            generated[str(p.relative_to(root))]=digest(p)
    return {'status':'passed_operator_contract_identity','packet_sha256':EXPECTED,
            'checked_inputs':pins,'generated_sources':generated,
            'limitations':'Only declaration and source identity; no RTL behavior or board proof.'}


if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--require-rtl',action='store_true');args=ap.parse_args()
    try:print(json.dumps(check(require_rtl=args.require_rtl),indent=2))
    except (ValueError,OSError,KeyError) as error:
        print(json.dumps({'status':'failed','error':str(error)}));sys.exit(1)
