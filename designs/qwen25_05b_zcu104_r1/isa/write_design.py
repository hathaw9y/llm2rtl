"""Publish a reviewable ISA draft; never freeze a module or fabricate approval."""
import hashlib,json
from pathlib import Path
from interpreter import BANK_BYTES,OPCODES,ARITIES
ROOT=Path(__file__).resolve().parents[1]
REPO=ROOT.parents[1]
def save(name,x):(ROOT/name).write_text(json.dumps(x,indent=2,ensure_ascii=False)+'\n')
def hashfile(path):return hashlib.sha256(path.read_bytes()).hexdigest()
identity={'design_id':'qwen25_05b_zcu104','revision':'r1'}
transport={'command_order_owner':'ps_software','residency_tiling_owner':'ps_software',
'recovery_policy_owner':'ps_software','pl_dispatcher_role':'route_execute_report_only',
'request_protocol':'ready_valid','response_protocol':'ready_valid','program_transport':'ps_preloaded_command_bram',
'queue_policy':'no_ring_queue','dispatch_policy':'strict_in_order_single_pc_scoreboard',
'execution_policy':'issue_on_request_handshake_with_scoreboard_completion','outstanding_policy':'bank_hazard_limited_multiple',
'pc_advance_event':'executor_command_acceptance','response_collection':'independent_of_current_pc',
'program_terminal_policy':'end_opcode_then_drain_outstanding','blocked_pc_policy':'stall_without_lookahead',
'program_publish_order':['instruction_records_ending_in_END','start'],'mutation_while_busy':'forbidden'}
bankspec={0:('ACT','BF16','token-major flat features'),1:('WGT','packed signed INT4','row-major output rows; even K low nibble'),
2:('SCALE','BF16','output-row-major K-groups'),3:('BIAS_GAMMA','BF16','vector'),4:('RESULT','BF16','token-major flat features'),
5:('VECTOR_PEER','BF16 or FP32','token-major flat features'),6:('Q','BF16','token-major 14 heads x 64'),
7:('SPARE','BF16','unallocated operand reservation'),8:('K','BF16','position-major 2 heads x 64'),
9:('V','BF16','position-major 2 heads x 64'),10:('COS','BF16','position-major split-half RoPE coefficients'),
11:('SIN','BF16','position-major split-half RoPE coefficients')}
roles={}
fields={
 'DMA_LOAD': [('dst','local_bank_id'),('ddr','external_ddr_address'),('rows','dimension'),('row_bytes','transfer_length'),('ddr_stride','stride')],
 'DMA_STORE':[('src','local_bank_id'),('ddr','external_ddr_address'),('rows','dimension'),('row_bytes','transfer_length'),('ddr_stride','stride')],
 'GEMM_W4':[(n,'local_bank_id') for n in ['activation','packed_weight','scales','bias','output']]+[(n,'dimension') for n in ['m','n','k','group_size']],
 'DEQUANT':[(n,'local_bank_id') for n in ['packed_weight','scales','output']]+[(n,'dimension') for n in ['one','rows','k','group_size']],
 'RMSNORM':[(n,'local_bank_id') for n in ['activation','gamma','output']]+[(n,'dimension') for n in ['m','k']],
 'ROPE':[(n,'local_bank_id') for n in ['activation','cos','sin','output']]+[(n,'dimension') for n in ['m','heads','head_dim']],
 'ATTENTION':[(n,'local_bank_id') for n in ['q','k','v','output']]+[(n,'dimension') for n in ['m','cache_length','query_start','head_dim']],
 'ADD':[(n,'local_bank_id') for n in ['a','b','output']]+[(n,'dimension') for n in ['m','k']],
 'SILU_MUL':[(n,'local_bank_id') for n in ['gate','up','output']]+[(n,'dimension') for n in ['m','k']],
 'CAST':[(n,'local_bank_id') for n in ['activation','output']]+[(n,'dimension') for n in ['m','k']], 'END':[]}
modules={'DMA_LOAD':'datamover_executor','DMA_STORE':'datamover_executor','GEMM_W4':'gemm_executor',
'DEQUANT':'vector_executor','RMSNORM':'rmsnorm_executor','ROPE':'rope_executor','ATTENTION':'attention_executor',
'ADD':'vector_executor','SILU_MUL':'vector_executor','CAST':'vector_executor','END':'isa_command_dispatcher'}
for op in OPCODES:
 roles[op]=[f'{modules[op]}.{name}' for name,kind in fields[op] if kind=='local_bank_id']
common={str(p.relative_to(REPO)):hashfile(p) for p in sorted((REPO/'contracts/common').glob('*.json'))}
isa={'schema':'llm2rtl.isa_spec.v1',**identity,'status':'draft','common_contracts':common,
 'user_scope_evidence':['User chose INT4 weights','User explicitly assigned QK and PV to Attention executor','User asked to proceed to next step'],
 'command_transport':transport,
 'instruction_record':{'width_bits':512,'byte_order':'little_endian','bytes_per_record':64,
 'fields':[{'name':'opcode','bit_offset':0,'width_bits':8},{'name':'flags_reserved_zero','bit_offset':8,'width_bits':8},
 {'name':'response_tag','bit_offset':16,'width_bits':16},{'name':'six_bank_ids','bit_offset':32,'width_bits':48},
 {'name':'six_opcode_specific_u32_parameters','bit_offset':80,'width_bits':192},
 {'name':'dma_external_address_only','bit_offset':272,'width_bits':64},
 {'name':'dma_rows_rowbytes_stride_reserved','bit_offset':336,'width_bits':128},
 {'name':'reserved_zero','bit_offset':464,'width_bits':48}],
 'unused_bank_id':255,'unused_parameter_value':0,'bank_zero_legal':True,
 'tag_rule':'Software programs below 24,576 records use unique 16-bit tags; response echoes the accepted command tag'},
 'opcodes':[{'opcode':op,'encoding':code,'module_id':modules[op],
 'opcode_class':'dma_load' if op=='DMA_LOAD' else 'dma_store' if op=='DMA_STORE' else 'control' if op=='END' else 'compute',
 'operands':[{'name':n,'kind':k} for n,k in fields[op]],
 'operand_semantics':'Ordered bank slots and scalar parameter slots defined in operands; distinct bank operands; compute external address and DMA fields must be zero',
 'completion_semantics':'Exactly one tag-identified response per accepted command; END stops issue and drains all outstanding commands',
 'failure_semantics':'Reject invalid opcode/shape/format/range before commit; failed compute leaves destination invalid; DMA_STORE validates all ranges before any write',
 'bank_port_roles':roles[op],'numeric_semantics_source':'isa/interpreter.py',
 'implemented_in_rtl':False} for op,code in OPCODES.items()],
 'numeric_candidate':{'weights':'Signed INT4 [-7,7], -8 reserved','group_sizes_under_comparison':[32,128],
 'scales':'BF16, per output row and K group; quantization uses stored scale',
 'activations_and_kv':'BF16','projection':'Dequantize to BF16, FP32 dot and bias, BF16 output',
 'attention':'BF16 Q/K/V; FP32 dot, BF16 score, divide 8 and cast BF16, mask, FP32 stable softmax cast BF16, FP32 PV cast BF16',
 'nonlinear_reference':'Pinned PyTorch operations; RTL approximation and reduction ordering not defined',
 'zero_groups':'Scale=1, all q=0','packing':'Two complement nibble; even K low; odd-K high padding=0'},
 'supported_software_test_scope':{'batch':1,'prefill_tokens':[1,2,3,4],'decode_tokens':[5],'token_tile_max':4},
 'proposed_capacity':{'context_max':2048,'output_tile_max':128,'command_records_max':24576},
 'unresolved_decisions':['INT4 group32 versus group128 selection and model-quality acceptance',
 'User discussion of concrete first executor implementation and golden criteria',
 'Physical bank and native command-memory mapping; board linker ranges; full context validation']}
save('isa_spec.json',isa)
banks={'schema':'llm2rtl.bank_layout.v1',**identity,'status':'draft',
 'ownership_model':{'mode':'single_exclusive_lock_per_bank','acquire':'All operand banks atomically acquired with command handshake',
 'release':'Matching port-role completion releases ownership; valid data state separate from busy lock',
 'port_role_names':roles,'port_id_assignment':'Preserve common MM2S/S2MM and GEMM_ACT/WGT/PSUM IDs; additional roles require design-specific router binding'},
 'banks':[{'bank_id':str(i),'name':name,'capacity_words':BANK_BYTES[i]//16,'word_bits':128,
 'format':fmt,'layout':layout,'valid':False,'busy':False,'owner':'NONE',
 'producers':['DMA_LOAD','compute_output_where_declared'],
 'consumers':['DMA_STORE','compute_operand_where_declared']} for i,(name,fmt,layout) in bankspec.items()],
 'physical_storage_assignment':'Pending new synthesis; logical bank capacities only',
 'data_capacity_bytes':sum(BANK_BYTES.values()),
 'command_memory':{'namespace':'separate_from_data_banks','proposed_capacity_records':24576,
 'capacity_bytes':24576*64,'interface':'Native dual-port command-BRAM protocol; physical BRAM/URAM composition pending',
 'publish':'Complete END-terminated program while idle, then START'},
 'ddr_residency':'All full weight tensors and all-layer KV in DDR; PS generates explicit tile DMA; compute sees only local banks',
 'kv_prefix_policy':'Start must equal successful cached_length; failed program invalidates cache; reset permits new prefill',
 'scratch_lifetime':'Stable allocation names reused on subsequent <=4-token calls; no per-decode region accumulation',
 'limitations':['Raw capacities are not routed resource-fit evidence','No accepted board DDR address ranges']}
save('bank_layout.json',banks)
print(json.dumps({'status':'draft_written','opcodes':len(OPCODES),'data_bytes':sum(BANK_BYTES.values()),'command_bytes':24576*64}))
