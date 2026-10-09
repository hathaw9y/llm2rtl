"""Fresh checkpoint reference capture; never reads previous accelerator designs."""
import hashlib
import inspect
import json
from pathlib import Path
import torch
import transformers
from transformers import AutoModelForCausalLM
import transformers.models.qwen2.modeling_qwen2 as modeling

ROOT = Path(__file__).resolve().parents[1]
CHECKPOINT = Path('/home/shmin/.cache/huggingface/hub/models--Qwen--Qwen2.5-0.5B/snapshots/060db6499f32faf8b98477b0a26969ef7d8b9987')
def sha(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(8*1024*1024), b''): h.update(chunk)
    return h.hexdigest()
def save(name, data):
    (ROOT/name).write_text(json.dumps(data, indent=2)+'\n')

torch.set_num_threads(8)
torch.manual_seed(0)
model = AutoModelForCausalLM.from_pretrained(CHECKPOINT, local_files_only=True,
    torch_dtype=torch.bfloat16, attn_implementation='eager').eval()
source = Path(inspect.getfile(modeling))
config = json.loads((CHECKPOINT/'config.json').read_text())
save('reference/config.json', config)
(ROOT/'reference/modeling_qwen2.py').write_bytes(source.read_bytes())
records = []
handles = []
phase = ['prefill']
def hook(name):
    def capture(module, inputs, output):
        x = output[0] if isinstance(output, tuple) else output
        if torch.is_tensor(x):
            records.append({'workload': phase[0], 'module': name,
                'input_shapes': [list(t.shape) for t in inputs if torch.is_tensor(t)],
                'output_shape': list(x.shape), 'dtype': str(x.dtype)})
    return capture
for name, module in model.named_modules():
    if isinstance(module, (torch.nn.Linear, torch.nn.Embedding, modeling.Qwen2RMSNorm,
                           modeling.Qwen2Attention, modeling.Qwen2MLP, modeling.Qwen2DecoderLayer)):
        handles.append(module.register_forward_hook(hook(name)))
with torch.inference_mode():
    prefill = model(input_ids=torch.tensor([[1,2,3,4]]), use_cache=True,
                    output_attentions=True)
    cache_before = prefill.past_key_values.get_seq_length() if hasattr(prefill.past_key_values, 'get_seq_length') else prefill.past_key_values[0][0].shape[-2]
    phase[0] = 'decode'
    decode = model(input_ids=torch.tensor([[5]]), past_key_values=prefill.past_key_values,
                   use_cache=True, output_attentions=True)
for handle in handles: handle.remove()
for name, result in [('prefill',prefill),('decode',decode)]:
    torch.save({'logits':result.logits.cpu(),
        'attentions':tuple(x.cpu() for x in result.attentions),
        'past_key_values':tuple((k.cpu(),v.cpu()) for k,v in result.past_key_values)},
        ROOT/'reference'/f'{name}.pt')
identity = {'model_id':'Qwen/Qwen2.5-0.5B', 'revision':CHECKPOINT.name,
    'transformers_version':transformers.__version__, 'torch_version':torch.__version__,
    'source_path':str(source), 'source_sha256':sha(source),
    'config_sha256':sha(CHECKPOINT/'config.json'),
    'weights_sha256':sha(CHECKPOINT/'model.safetensors')}
save('reference/reference_capture.json', {'status':'executed_checkpoint_reference_only',
    'model_identity':identity, 'seed':0, 'attention_implementation':'eager',
    'input_ids':{'prefill':[[1,2,3,4]],'decode':[[5]]},
    'prefill_cache_length':int(cache_before),
    'decode_cache_length':int(decode.past_key_values[0][0].shape[-2]),
    'parameter_count_unique':sum(p.numel() for p in model.parameters()),
    'embedding_lm_head_shared':model.lm_head.weight is model.model.embed_tokens.weight,
    'module_calls':records,
    'limitations':['Only batch=1, four-token prefill plus one cached decode executed.',
        'Module hooks do not observe functional tensor operations; source review is also required.',
        'Not ISA interpreter, RTL, synthesis, board, or model-quality evidence.']})
print(json.dumps({'status':'captured','model_identity':identity,'module_calls':len(records)},indent=2))
