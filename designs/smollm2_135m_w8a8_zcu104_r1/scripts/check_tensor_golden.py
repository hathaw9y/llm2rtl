"""Artifact integrity and ISA framing checks; not an independent tensor oracle."""
import gzip
import hashlib
import json
from pathlib import Path
from isa_codec import validate_command

DESIGN=Path(__file__).resolve().parents[1]
def check():
    root=DESIGN/'verification'/'tensor_golden'
    m=json.loads((root/'manifest.json').read_text())
    digest=lambda data: hashlib.sha256(data).hexdigest()
    for name,expected in m['source_sha256'].items():
        assert digest((DESIGN/'scripts'/name).read_bytes())==expected,name
    for name,expected in m['contract_sha256'].items():
        assert digest((DESIGN/'contracts'/name).read_bytes())==expected,name
    ledger=json.loads((root/'command_ledger.json').read_text())
    assert digest((root/'command_ledger.json').read_bytes())==m['command_ledger_sha256']
    program=(root/m['program']['file']).read_bytes()
    assert digest(program)==m['program']['sha256']
    assert len(program)==16*len(ledger)
    next_offset=0
    for fragment in m['program']['fragments']:
        offset,count=fragment['byte_offset'],fragment['record_count']
        assert offset==next_offset and 1<=count<=16
        records=[int.from_bytes(program[offset+j*16:offset+(j+1)*16],'little') for j in range(count)]
        assert records[-1]==0 and all(records[:-1])
        for record in records: validate_command(record)
        next_offset+=count*16
    assert next_offset==len(program)
    for index,event in enumerate(ledger):
        assert event['status']=='OK'
        assert int(event['hex128'],16)==int.from_bytes(program[index*16:(index+1)*16],'little')
    for vector in m['vectors']:
        event=ledger[vector['command_id']-1]
        assert vector['hex128']==event['hex128'] and vector['opcode']==event['opcode']
        for item in vector['inputs']:
            for component,artifact in item['components'].items():
                data=gzip.decompress((root/artifact['file']).read_bytes())
                assert len(data)==artifact['bytes'] and digest(data)==artifact['sha256']
                assert digest(data)==event['before'][str(item['bank'])]['components'][component]['sha256']
        for component,artifact in vector['outputs'].items():
            data=gzip.decompress((root/artifact['file']).read_bytes())
            coverage=gzip.decompress((root/artifact['coverage_file']).read_bytes())
            assert len(data)==len(coverage)==artifact['bytes']
            assert set(coverage)<=set((0,1))
            assert digest(coverage)==artifact['coverage_sha256']
            assert digest(data)==artifact['sha256']
            assert digest(data)==event['after'][str(vector['output_bank'])]['components'][component]['sha256']
    opcodes=sorted({event['opcode'] for event in ledger})
    assert len(opcodes)==15
    return {'status':'PASS_ARTIFACT_INTEGRITY_ONLY','commands':len(ledger),'vectors':len(m['vectors']),
            'fragments':len(m['program']['fragments']),'opcodes':opcodes,'workloads':m['workloads']}

if __name__=='__main__': print(json.dumps(check(),indent=2))
