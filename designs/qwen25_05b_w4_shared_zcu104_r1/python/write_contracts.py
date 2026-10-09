"""Create this revision's contracts from current common files and fresh evidence."""
import hashlib,json
from pathlib import Path
import isa
BASE=Path(__file__).resolve().parents[1];ROOT=BASE.parents[1]
RESEARCH=ROOT/'verification/research/qwen2_5_0_5b_initial_review'
ID='qwen25_05b_w4_shared_zcu104';REV='r1'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(name,data):
    (BASE/name).parent.mkdir(exist_ok=True,parents=True)
    (BASE/name).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
def identified(schema):return {'schema':schema,'design_id':ID,'revision':REV}
def ref(p):return {'path':str(p.relative_to(ROOT)),'sha256':sha(p)}

def main():
    semantics={
        'embedding_lookup':'Token address lookup on PS; explicit W4 row/scale DMA and PL DEQUANT.',
        'rmsnorm':'FP32 reduction/rsqrt, intermediate BF16, BF16 gamma multiply.',
        'weight_projection':'Explicit activation extract, W4/scale DMA, group128 GEMM and BF16 conversion.',
        'bias':'FP32 projection plus BF16 bias before BF16 output.',
        'rope_table':'Fixed pinned-reference BF16 table DMA from DDR.',
        'rope_rotation':'BF16 rounded products and sum, rotate-half per64 feature head.',
        'KV_append':'Explicit per-token/head DMA_STORE; commit cache length only after workload success.',
        'KV_read':'Explicit one-head context DMA_LOAD after DDR store dependency END.',
        'GQA_mapping':'Seven Q heads reuse a KV head; no physical repeat tensor.',
        'QK_transpose':'Shared BF16 GEMM with semantic transpose mode, FP32 score.',
        'scale_causal_softmax':'BF16 QK/scale boundaries, explicit mask, FP32 stable approximate softmax, BF16 probability.',
        'PV':'Shared BF16 GEMM, FP32 result, BF16 CAST.',
        'residual':'BF16 residual add in vector.',
        'SiLU_times_up':'FP32 approximate SiLU with intermediate BF16 before BF16 up multiply.',
        'head_layout':'Semantic extract/insert between distinct bank handles, with coverage checks.',
        'LM_head':'Tied quantization codes/scales, independent DDR tile representation; last-token logits only.'}
    trace=identified('llm2rtl.model_trace.v1')
    trace.update(model_identity={'model_id':'Qwen/Qwen2.5-0.5B','revision':'060db6499f32faf8b98477b0a26969ef7d8b9987',
                                'transformers_version':'4.46.3','source_path':str((RESEARCH/'modeling_qwen2.py').relative_to(ROOT)),
                                'source_sha256':sha(RESEARCH/'modeling_qwen2.py')},
                 operations=[{'operation_id':name,'semantic_kind':description,'source_location':'pinned modeling_qwen2.py; original_reference_trace/summary.json'} for name,description in semantics.items()],
                 workloads=[{'workload_id':p,'operations':list(semantics),'conditions':{'batch':1,'tokens':t,'prefix':prefix,'padding':False,'last_logits_only':True}} for p,t,prefix in [('prefill',[9707,11],0),('decode',[151643],2)]],
                 supported_scope={'max_prefill':512,'max_context':1024,'decode_rows':1,'layers':24},
                 unobserved_paths=['An ISA-produced prefix1023 followed by decode1024 has not been numerically executed; boundary test uses a declared reference seed.'],
                 unsupported_paths=['batch>1','padding','custom/noncontiguous position IDs','sliding eviction','sampling/argmax','training/dropout'])
    write('model_trace.json',trace)
    numeric={'status':'selected_by_agent_under_user_delegation','FP32':'RNE, no FMA; input/output subnormals flushed to signed zero. Finite arithmetic overflow/nonfinite input produces identified error, no valid destination commit.',
             'BF16':'RNE conversion and arithmetic boundaries per agreed nonlinear_rounding_decision; BF16 subnormals flushed to signed zero.',
             'GEMM':'Adjacent tree16 followed by sequential K16 step accumulation; group128 FP32 scale then sequential group output accumulation. Zero K-tail lanes.',
             'RMSNorm':'FP32 tree16/serial sum, multiply FP32(1/896), add FP32(1e-6); rsqrt normalized256 midpoint LUT,3 unfused Newton steps and exponent adjustment. BF16 before gamma.',
             'Softmax':'BF16 QK and score/8; causal masked entries excluded from exp and denominator, probability0. Stable exp2: FP32(x*log2e),256 segments linear interpolation, exponent scale; FTZ below FP32 normal range. FP32 tree16/serial sum; reciprocal256 seed LUT with2 Newton steps. BF16 probabilities.',
             'SiLU':'Stable sigmoid via exp(-abs(x)) and reciprocal(1+exp); sign selection; BF16 SiLU before up multiply.',
             'RoPE':'Pinned default table; BF16 products independently rounded, then BF16 sum. No fused product/add.',
             'nonlinear_unit_test_bounds':{'rsqrt_relative':3e-7,'reciprocal_relative':3e-7,'exp_relative_on_minus80_to0':6e-6},
             'ISA_vs_quantized_reference':{'logits_relative_l2_max':.05,'logits_cosine_min':.995,'KV_relative_l2_max':.05,'current_small_observation':'bit-identical logits and all-layer KV; see fresh report'},
             'original_BF16_quality_probe':{'relative_l2_max':.35,'cosine_min':.90,'status':'failed_small_probe; no original-model quality acceptance claim'},
             'hardware_golden':'RTL must exactly match selected arithmetic and golden words; quality tolerances never excuse RTL/interpreter mismatch.'}
    write('numeric_contract.json',numeric)
    common={str(p.relative_to(ROOT)):sha(p) for p in sorted((ROOT/'contracts/common').glob('*.json'))}
    transport={'command_order_owner':'ps_software','residency_tiling_owner':'ps_software','recovery_policy_owner':'ps_software','pl_dispatcher_role':'route_execute_report_only','request_protocol':'ready_valid','response_protocol':'ready_valid','program_transport':'ps_preloaded_command_bram','queue_policy':'no_ring_queue','dispatch_policy':'strict_in_order_single_pc_scoreboard','execution_policy':'issue_on_request_handshake_with_scoreboard_completion','outstanding_policy':'bank_hazard_limited_multiple','pc_advance_event':'executor_command_acceptance','response_collection':'independent_of_current_pc','program_terminal_policy':'end_opcode_then_drain_outstanding','blocked_pc_policy':'stall_without_lookahead','program_publish_order':['instruction_records_ending_in_END','start'],'mutation_while_busy':'forbidden'}
    modules={'END':'isa_command_dispatcher','DMA_LOAD':'datamover_executor','DMA_STORE':'datamover_executor','GEMM':'gemm_executor','RMSNORM':'rmsnorm_executor','ROPE':'rope_executor','SOFTMAX_MASKED':'softmax_executor','VECTOR':'vector_executor'}
    opcodes=[]
    for name,value in isa.OP.items():
        cls='dma_load' if value==1 else 'dma_store' if value==2 else 'control' if value==0 else 'compute'
        operands=[]
        if value in (1,2): operands=[{'name':'ddr','kind':'external_ddr_address'},{'name':'bank','kind':'local_bank_id'},{'name':'bytes','kind':'transfer_length'},{'name':'offset','kind':'local_bank_offset'}]
        elif value: operands=[{'name':k,'kind':'local_bank_id'} for k in (['src','dst'] if value==6 else ['src0','src1','dst'])]+[{'name':'shape','kind':'dimension'},{'name':'mode_flags','kind':'flags'}]
        if value==3: operands.append({'name':'scale_bank','kind':'local_bank_id'})
        opcodes.append({'opcode':name,'encoding':value,'module_id':modules[name],'opcode_class':cls,'operands':operands,
                        'operand_semantics':'Explicit DMA DDR/local transfer.' if value in (1,2) else 'Logical bank handles and semantic selectors; no raw compute address.',
                        'completion_semantics':'Exactly one identified success/error response; END drains all outstanding commands.',
                        'failure_semantics':'No destination valid commit or source last_use consumption on failure; partially written destination invalid.'})
    spec=identified('llm2rtl.isa_spec.v1');spec.update(status='reviewed',unresolved_decisions=[],common_contracts=common,command_transport=transport,opcodes=opcodes,
         instruction_record={'width_bits':256,'bytes_per_record':32,'byte_order':'little_endian','fields':[{'name':n,'bit_offset':off,'width_bits':bits} for n,off,bits in isa.FIELDS],'reserved_zero_bits':[0,18],'DMA_large_rows':'m=0 uses extent_n as row count; compute M is1..16'},
         command_capacity={'records':1024,'non_END_max':1023,'double_buffer':False,'DDR_alias_rule':'Chunker drains at END before overlapping store->load, conservatively irrespective of bank alias.'},
         autonomy_authorization='User: 너가 이제 알아서 다 정해봐.',numeric_contract=ref(BASE/'numeric_contract.json'),
         status_limits='Reviewed contracts do not mean verified RTL or accepted original BF16 quality.')
    write('isa_spec.json',spec)
    old=json.loads((RESEARCH/'bank_candidate.json').read_text());bankdoc=identified('llm2rtl.bank_layout.v1')
    bankdoc.update(ownership_model={'mode':'single_exclusive_lock_per_bank','acquire':'All operand roles atomically acquire at command acceptance.','release':'Matching command completion only, independently of PC.'},native_read_latency=3,DMA_stream_bits=64,banks=[])
    for b in old['banks']:
        bankdoc['banks'].append({'bank_id':str(b['bank_id']),'name':b['name'],'capacity_words':b['capacity_bytes']//16,'word_bits':128,'format':b['format'],'layout':b['role'],'memory_kind':b['memory_kind_proposal'],
                                'producers':['DMA_LOAD','GEMM','RMSNORM','ROPE','SOFTMAX_MASKED','VECTOR'],'consumers':['DMA_STORE','GEMM','RMSNORM','ROPE','SOFTMAX_MASKED','VECTOR'],
                                'capability_note':'Descriptor format/shape and opcode role enforce runtime compatibility; lists are possible roles, not blanket valid-format permission.'})
    bankdoc['descriptor_fields']=['format','shape','stride','tensor_identity','layout','valid','busy','owner','assembly_coverage','next_K_group','partial_sum']
    bankdoc['SCORE_reuse']='FP32 attention[M,L] stride4096 or FFN[M,128] stride512; mutually exclusive lifetimes and explicit INIT.'
    bankdoc['synthesis_status']='not_synthesized'
    bank_evidence=BASE/'evidence/bank_fabric_200mhz_ooc_run002'
    if (bank_evidence/'invocation.json').exists() and json.loads((bank_evidence/'invocation.json').read_text())['returncode']==0:
        bankdoc['synthesis_status']='passed_200MHz_bank_fabric_OOC_only'
        bankdoc['synthesis_evidence']={name:ref(bank_evidence/name) for name in ('manifest.json','invocation.json','timing_summary.rpt','utilization.rpt')}
        bankdoc['measured_resources']={'BRAM36_tiles':70,'URAM288':10,'CLB_LUTs':37251,'clock_MHz':200,'setup_slack_ns':.327,'hold_slack_ns':.108,'scope':'23 data banks and role fabric only; excludes command memory, compute, DataMover and PS/PL composition.'}
    write('bank_layout.json',bankdoc)
    for name in ('gemm','rmsnorm','rope','softmax','vector'):
        opcode={'gemm':'GEMM','rmsnorm':'RMSNORM','rope':'ROPE','softmax':'SOFTMAX_MASKED','vector':'VECTOR'}[name]
        m=identified('llm2rtl.module_contract.v1');m.update(module_id=name+'_executor',module_kind='opcode_executor',opcode=opcode,status='frozen',
          authorization='Remaining implementation decisions delegated by user; no historical skill approval rules.',
          interface={'request':['cmd_valid','cmd_ready','cmd_id[9:0]','mode','bank IDs','semantic dimensions/selectors','flags'],
                     'response':['rsp_valid','rsp_ready','rsp_cmd_id[9:0]','rsp_error','rsp_error_code'],
                     'response_rule':'One stable ready/valid response per accepted command; capacity one active command per executor.',
                     'bank_ports':'Role-routed128-bit native reads with latency3 and byte-masked128-bit writes. Module computes memory word addresses internally; commands have no raw offsets.',
                     'target_clock_MHz':200,'reset':'Cancels active work and invalidates affected state; normal END/DONE is not reset.'},
          numeric={'contract':ref(BASE/'numeric_contract.json'),'operation':opcode,'parallelism':{'K':16,'outputs':4,'rows':1} if name=='gemm' else {'elements':1},
                   'architecture':'GEMM product/reduction pipelines plus serial group accumulation.' if name=='gemm' else 'Sequential bank traversal and unfused FP32 arithmetic, explicit BF16 boundaries.',
                   'FP32_core':'Custom six-stage FP32 RNE/FTZ add/multiply, unfused; exponent preparation and alignment are separate stages, with whole-pipeline response backpressure. Exact source/ROM simulation and OOC identities must match the implementation.'},
          verification={'golden':'Fresh command_golden.safetensors and independent scalar arithmetic tests; exact numeric words plus descriptor changes.',
                        'RTL':['reset/backpressure','one response','source preservation on error','tail/shape coverage','all supported modes'],
                        'synthesis':'Fresh200MHz OOC plus resource evidence for this exact module and later full integration.',
                        'board':'Not verified; user-run after full integration artifacts.'})
        write('modules/'+name+'_executor.json',m)
    report_path=BASE/'evidence/isa_small_run002/report.json'
    if report_path.exists():
        report=json.loads(report_path.read_text())
        lowering_map={'embedding_lookup':['DMA_LOAD','VECTOR'],'rmsnorm':['DMA_LOAD','RMSNORM'],'weight_projection':['VECTOR','DMA_LOAD','GEMM','VECTOR'],'bias':['DMA_LOAD','VECTOR'],'rope_table':['DMA_LOAD'],'rope_rotation':['ROPE'],'KV_append':['DMA_STORE'],'KV_read':['DMA_LOAD'],'GQA_mapping':['VECTOR','GEMM'],'QK_transpose':['GEMM'],'scale_causal_softmax':['SOFTMAX_MASKED'],'PV':['GEMM','VECTOR'],'residual':['VECTOR'],'SiLU_times_up':['VECTOR'],'head_layout':['VECTOR'],'LM_head':['VECTOR','DMA_LOAD','GEMM','VECTOR','DMA_STORE']}
        v=identified('llm2rtl.isa_validation.v1');v.update(status='passed' if report['status']=='passed_small_ISA_numeric_paths' else 'failed',no_host_tensor_compute=True,
             model_trace=ref(BASE/'model_trace.json'),isa_spec=ref(BASE/'isa_spec.json'),bank_layout=ref(BASE/'bank_layout.json'),model_source_sha256=trace['model_identity']['source_sha256'],
             lowerings=[{'operation_id':name,'instructions':[{'opcode':op,'banks':[]} for op in lowering_map[name]]} for name in semantics],
             workload_results=[{'workload_id':r['phase'],'status':r['numeric_comparison_status'],'vector_sha256':sha(report_path.parent/(r['phase']+'_tensors.safetensors'))} for r in report['results']],
             evidence=ref(report_path),scope='Small prefill/decode only; W4 reference numerical execution. Original BF16 quality probe failed. No RTL/board claim.',
             full_scope_status='failed_prefill512_KV_tolerance',
             extended_evidence=ref(BASE/'evidence/isa_extended_run001/report.json'),
             extended_limitations='prefill17 passed; prefill512 KV relative L2 threshold failed; decode1024 passed with a reference-seeded prefix1023. No full ISA-generated1023-token chain proof.')
        write('isa_validation.json',v)

if __name__=='__main__':main()
