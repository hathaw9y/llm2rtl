"""Scoped proposal/frozen-module consistency; does not grant model PASS."""
import hashlib
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
DESIGN=Path(__file__).resolve().parents[1]
def read(p): return json.loads(p.read_text())
def check_ref(reference):
    p=ROOT/reference['path']
    assert p.is_file() and hashlib.sha256(p.read_bytes()).hexdigest()==reference['sha256'],reference['path']
    return read(p) if p.suffix=='.json' else p.read_text()
def check():
    m=read(DESIGN/'modules/int8_gemm_executor.json')
    assert m['status'] in ('proposed_implementation_review','frozen')
    frozen=m['status']=='frozen'
    if frozen:
        manifest=read(DESIGN/'contracts/gemm_module_manifest.json')
        assert manifest['status']=='frozen'
        assert (manifest['design_id'],manifest['revision'])==(m['design_id'],m['revision'])
        approval=check_ref(manifest['approval'])
        assert approval['status']=='approved' and approval['module_id']==m['module_id']
        assert (approval['design_id'],approval['revision'])==(m['design_id'],m['revision'])
        assert approval['user_reply']=='그래'
        assert manifest['contracts']==approval['frozen_contracts']
        assert manifest['baseline_contracts']==m['design_refs']
        assert manifest['golden']==m['golden'] and manifest['common_contracts']==m['common_contracts']
        for reference in manifest['contracts'].values(): check_ref(reference)
        for reference in approval['approved_proposal_snapshot'].values(): check_ref(reference)
        assert m['approved_proposal_sha256']==approval['approved_proposal_snapshot'][m['module_id']]['sha256']
        assert {n:r for n,r in manifest['contracts'].items() if n!=m['module_id']}==m['children']
    for r in m['common_contracts'].values(): check_ref(r)
    for r in m['design_refs'].values(): check_ref(r)
    children={n:check_ref(r) for n,r in m['children'].items()}
    golden=check_ref(m['golden']); check_ref(m['hardware_profile']); check_ref(m['workflow'])
    isa=read(DESIGN/'isa_spec.json')
    owned={o['opcode'] for o in isa['opcodes'] if o['module_id']==m['module_id']}
    assert owned==set(m['implemented_opcodes'])
    assert {v['opcode'] for v in golden['vectors']}>=owned
    for child in children.values():
        assert (child['design_id'],child['revision'],child['parent'])==(m['design_id'],m['revision'],m['module_id'])
        assert child['status']==m['status']
    core=children['int8_dot_core']; epi=children['fp32_bf16_epilogue']
    assert core['architecture']['n_lanes']*core['architecture']['k_lanes']==256
    assert core['architecture']['max_logical_rows']==3*32
    assert epi['architecture']['lanes']==4
    assert not m['numeric']['overflow_runtime_detector'] and not core['numeric']['overflow_detector']
    assert max(core['numeric']['legal_bounds'].values())<2**31
    buffers={b['name']:b['bytes'] for b in m['memory']['buffers']}
    assert buffers['A_staging']>=max(32*1536,3*32*64,3*32*1024)
    assert buffers['B_panels']==2*16*32 and buffers['partial_sums']==96*16*4
    assert buffers['result_FIFO']==128*(16*4+16) and 128>=96
    assert sum(buffers.values())==m['memory']['logical_buffer_total_bytes']==116768
    clock_fields=('clock_mhz','clock_period_ns') if frozen else ('proposed_clock_mhz','proposed_clock_period_ns')
    assert m['target'][clock_fields[0]]*m['target'][clock_fields[1]]==1000
    completion=check_ref(m['common_contracts']['engine_completion_contract'])
    assert completion['completion_rule']=='engine_resp_valid_only_after_all_reads_received_and_processed_and_all_writes_accepted'
    # Ideal unstalled body counts separate staged arithmetic from local read
    # throughput. They exclude setup, scale, packing, stalls and DDR entirely.
    examples=[]
    for rows in (1,32):
        examples.append({'mode':'GEMM M%d N192 K1536'%rows,'staged_compute_issue_cycles':rows*12*96,
                         'B_256bit_read_requests':12*48*16,'A_256bit_read_requests':rows*1536//32})
        examples.append({'mode':'QK per KV-head N16 K64; query_rows%d'%rows,
                         'staged_compute_issue_cycles':3*rows*4,'B_128bit_read_requests':16*64//16})
        examples.append({'mode':'PV per KV-head N16 K1024; query_rows%d'%rows,
                         'staged_compute_issue_cycles':3*rows*64,'B_128bit_read_requests':1024})
    return {'status':'PASS_FROZEN_MODULE_STRUCTURE_APPROVAL_AND_PIN_IDENTITY_ONLY' if frozen else 'PASS_PROPOSAL_STRUCTURE_AND_PIN_IDENTITY_ONLY','module_id':m['module_id'],
            'module_sha256':hashlib.sha256((DESIGN/'modules/int8_gemm_executor.json').read_bytes()).hexdigest(),
            'logical_internal_buffer_bytes':116768,'logical_bank_pool_bytes':2224928,
            'ideal_body_examples':examples,'implementation_review':'approved; contract frozen' if frozen else 'pending concrete user review',
            'RTL_dispatch':'no dispatch performed by this checker','canonical_full_model_gate':'pending; not bypassed',
            'RTL_simulation_synthesis_board':'not run'}
if __name__=='__main__': print(json.dumps(check(),indent=2))
