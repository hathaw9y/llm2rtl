"""Prepare reviewable executor candidates from fresh source/reference evidence."""
import hashlib,json
from pathlib import Path
from safetensors import safe_open
ROOT=Path(__file__).resolve().parents[1]
def save(n,x): (ROOT/n).write_text(json.dumps(x,indent=2)+'\n')
ref=json.loads((ROOT/'reference/reference_capture.json').read_text())
config=json.loads((ROOT/'reference/config.json').read_text())
source=(ROOT/'reference/modeling_qwen2.py').read_text().splitlines()
def loc(fragment):
 return 'reference/modeling_qwen2.py:'+str(next(i+1 for i,line in enumerate(source) if fragment in line))
ops=[
 ('embedding','embedding_lookup','inputs_embeds = self.embed_tokens(input_ids)','DMA_LOAD','datamover_executor','PS selects token row; no PS embedding arithmetic'),
 ('input_norm','rmsnorm','hidden_states = self.input_layernorm(hidden_states)','RMSNORM','rmsnorm_executor','Shared with post-attention and final RMSNorm'),
 ('qkv','affine_projection','query_states = self.q_proj(hidden_states)','GEMM_W4','gemm_executor','Q/K/V share W4 projection with BF16 bias epilogue'),
 ('qkv_layout','reshape_transpose','query_states = query_states.view','LAYOUT','layout_executor','Explicit physical bank layouts or executor transformation; never hidden PS tensor math'),
 ('rope','rotary_position_embedding','query_states, key_states = apply_rotary_pos_emb','ROPE','rope_executor','Q and K head_dim=64, split halves rotation'),
 ('kv_append','cache_update','past_key_value.update','DMA_STORE','datamover_executor','PS computes cache addresses; store rotated K and unrotated V'),
 ('kv_read','cache_access','key_states = repeat_kv','DMA_LOAD','datamover_executor','Explicit DDR cache loads for attention tiles'),
 ('gqa','grouped_query_head_mapping','key_states = repeat_kv','ATTENTION','attention_executor','Attention executor maps seven Q heads to each KV head and reuses local KV data without DDR replication'),
 ('qk','attention_score','attn_weights = torch.matmul','ATTENTION','attention_executor','Attention executor computes QK transpose using its own attention datapath; not dispatched to the projection GEMM executor'),
 ('score_scale','attention_scale','/ math.sqrt(self.head_dim)','ATTENTION','attention_executor','Scale=1/8'),
 ('causal_mask','causal_mask','attn_weights = attn_weights + causal_mask','ATTENTION','attention_executor','Generate causal mask from global positions'),
 ('softmax','stable_softmax','attn_weights = nn.functional.softmax','ATTENTION','attention_executor','Attention executor owns stable softmax between QK transpose and PV; materialized versus tiled online algorithm and numerical boundaries remain pending'),
 ('pv','attention_value','attn_output = torch.matmul','ATTENTION','attention_executor','Attention executor computes probability-times-V using its own attention datapath; not dispatched to the projection GEMM executor'),
 ('head_merge','reshape_transpose','attn_output = attn_output.transpose','LAYOUT','layout_executor','Could be bank addressing inside attention output; layout decision pending'),
 ('o_proj','linear_projection','attn_output = self.o_proj','GEMM_W4','gemm_executor','Shared projection engine, no bias'),
 ('residual','residual_add','hidden_states = residual + hidden_states','ADD','vector_executor','Two residual adds per layer'),
 ('post_norm','rmsnorm','hidden_states = self.post_attention_layernorm','RMSNORM','rmsnorm_executor','Shared normalization'),
 ('gate_up','linear_projection','self.act_fn(self.gate_proj','GEMM_W4','gemm_executor','Two projections 896 -> 4864'),
 ('swiglu','silu_multiply','self.act_fn(self.gate_proj','SILU_MUL','vector_executor','Proposed SiLU(gate)*up fusion; no GELU'),
 ('down','linear_projection','return self.down_proj','GEMM_W4','gemm_executor','4864 -> 896; shared projection'),
 ('final_norm','rmsnorm','hidden_states = self.norm(hidden_states)','RMSNORM','rmsnorm_executor','One final RMSNorm'),
 ('lm_head','linear_projection','logits = self.lm_head','GEMM_W4','gemm_executor','Tied embedding/head weights; quantized boundary pending'),
 ('logits_cast','dtype_cast','logits = logits.float()','CAST','vector_executor','Match FP32 logits output'),
]
operations=[{'operation_id':i,'semantic_kind':kind,'source_location':loc(fragment),
 'proposed_opcode':opcode,'proposed_executor':executor,'rationale':reason,
 'observation':'Source-reviewed functional semantics with enclosing-module hooks; not operator-level dynamic trace'}
 for i,kind,fragment,opcode,executor,reason in ops]
trace={'schema':'llm2rtl.model_trace.v1','design_id':'qwen25_05b_zcu104','revision':'r1',
 'status':'reference_executed_source_reviewed_isa_pending','model_identity':ref['model_identity'],
 'operations':operations,'workloads':[{'workload_id':w,'operations':[x['operation_id'] for x in operations],
 'conditions':{'batch':1,'input_ids':ref['input_ids'][w], 'use_cache':True,'eval':True,'dtype':'bfloat16','attention':'eager'}} for w in ['prefill','decode']],
 'unobserved_paths':['Context lengths beyond five tokens','Padding and multi-batch execution','Operator-level dynamic instrumentation'],
 'unsupported_paths':['Training/backpropagation','Dropout in training','Sliding-window attention','Beam search and speculative decoding'],
 'reference_capture':'reference/reference_capture.json',
 'reference_capture_sha256':hashlib.sha256((ROOT/'reference/reference_capture.json').read_bytes()).hexdigest(),
 'limitations':ref['limitations']}
save('model_trace.json',trace)
weights=Path('/home/shmin/.cache/huggingface/hub/models--Qwen--Qwen2.5-0.5B/snapshots')/ref['model_identity']['revision']/'model.safetensors'
matrices=[]; other=0
with safe_open(str(weights),framework='pt',device='cpu') as f:
 for key in f.keys():
  shape=f.get_slice(key).get_shape()
  count=1
  for d in shape: count*=d
  if len(shape)==2:
   rows,cols=shape
   matrices.append({'name':key,'shape':shape,'elements':count,
    'int4_bytes':rows*((cols+1)//2),
    'bf16_group128_scale_bytes':rows*((cols+127)//128)*2})
  else: other+=count
packed=sum(x['int4_bytes'] for x in matrices)
scales=sum(x['bf16_group128_scale_bytes'] for x in matrices)
hardware=json.loads(Path('config/hardware/zcu104.json').read_text())
onchip=312*36864//8+96*294912//8
save('planning/memory_estimate.json',{'status':'proposal_not_measured_bandwidth_or_synthesis',
 'quantization_candidate':'Symmetric signed INT4 [-7,7], per-output-row K-group=128, BF16 scales; unselected',
 'matrices':matrices,'matrix_elements':sum(x['elements'] for x in matrices),
 'int4_matrix_bytes':packed,'bf16_scale_bytes':scales,'nonmatrix_bf16_bytes':other*2,
 'total_candidate_weight_bytes':packed+scales+other*2,
 'tied_embedding_policy':'Proposed single quantized table for embedding and head; must validate quality',
 'onchip_raw_bram_uram_bytes':onchip,'full_weight_preload_fits':packed+scales+other*2<=onchip,
 'kv_bf16_bytes_per_token_all_layers':24*2*2*64*2,
 'kv_bf16_bytes_at_context':{str(n):24*2*2*64*2*n for n in [2048,32768]},
 'ddr_accelerator_capacity_bytes':hardware['pl_ddr_region']['size_bytes'],
 'limitations':['Raw RAM bits exclude ECC, layout, banking and other resident buffers.',
  'Weight bytes exclude tensor alignment and packaging headers.',
  'DDR address ranges unresolved in hardware profile; resolve from new linker map.',
  'No DDR bandwidth or tokens/s measurement; no full-context capability proven.']})
save('planning/executor_candidates.json',{'status':'awaiting_boundary_discussion',
 'user_decisions':{'weight_precision':'INT4','original_request':'이 프레임워크를 이용해서 Qwen/Qwen2.5-0.5B 를 FPGA로 구현해봐. 단 기존 build는 참고하지 말고'},
 'proposed_hardware':hardware,'operation_candidates':operations,
 'proposed_scope':{'batch':1,'prefill':True,'decode':True,'initial_context_limit':2048,
 'output':'FP32 logits; tokenizer and sampling on PS'},
 'proposed_numeric_policy':{'weights':'INT4 symmetric group128','scales':'BF16','activations':'BF16',
 'kv':'BF16','accumulation':'FP32','bias_and_norm_weights':'BF16',
 'rounding':'round-to-nearest ties-to-even; explicit casts in ISA reference'},
 'unresolved_decisions':['Approve executor fusion/boundaries and W4A16KV16 scope',
 'Quantization calibration/quality gate and embedding treatment',
 'Tile/bank capacity and ownership-port extensions for non-GEMM executors',
 'First executor algorithm, interfaces and verification discussion',
 'DDR linker ranges and actual memory bandwidth'],
 'forbidden_claims':['No implemented ISA','No RTL module PASS','No bitstream','No FPGA execution']})
save('run_ledger.json',{'design_id':'qwen25_05b_zcu104','revision':'r1',
 'status':'awaiting_isa_boundary_discussion','existing_builds_used':False,
 'actions':['Checked three common contracts','Executed original model prefill/decode',
 'Reviewed exact Transformers source and checkpoint identity','Recorded user INT4 choice',
 'Prepared candidate executors and packed-weight/KV capacity calculations'],
 'next_action':'Discuss concrete candidate boundaries, then define ISA and bit-exact interpreter before any RTL dispatch'})
print(json.dumps({'operations':len(operations),'candidate_weight_bytes':packed+scales+other*2,
 'onchip_bytes':onchip,'unique_parameter_count':ref['parameter_count_unique']},indent=2))
