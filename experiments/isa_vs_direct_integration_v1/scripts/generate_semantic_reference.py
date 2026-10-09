#!/usr/bin/env python3
"""Generate layer-0 HF fixtures without importing any ISA/compiler/controller.

These fixtures measure model approximation error. They are NOT the bit-exact
fixed-kernel arithmetic oracle required before participant launch.
"""
import argparse
import datetime as dt
import hashlib
import inspect
import json
from pathlib import Path
import time


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--checkpoint', type=Path, default=Path(
        '/home/shmin/.cache/huggingface/hub/models--HuggingFaceTB--SmolLM2-135M/snapshots/'
        '93efa2f097d58c2a74874c7e644dbc9b0cee75a2'))
    a = p.parse_args()
    import torch
    import transformers
    from transformers import AutoModelForCausalLM, DynamicCache
    from transformers.models.llama.modeling_llama import apply_rotary_pos_emb, repeat_kv
    a.out.mkdir(parents=True, exist_ok=False)
    torch.set_num_threads(4)
    start = time.monotonic()
    model = AutoModelForCausalLM.from_pretrained(
        str(a.checkpoint), local_files_only=True, dtype=torch.bfloat16,
        attn_implementation='eager').eval()
    layer = model.model.layers[0]
    captured = {}
    handles = []

    def output_hook(name):
        def hook(module, args, value):
            value = value[0] if isinstance(value, tuple) else value
            captured[name] = value.detach().clone()
        return hook

    def input_hook(name):
        def hook(module, args):
            captured[name] = args[0].detach().clone()
        return hook

    for name, module in [('input_norm', layer.input_layernorm),
                         ('q_proj', layer.self_attn.q_proj), ('k_proj', layer.self_attn.k_proj),
                         ('v_proj', layer.self_attn.v_proj), ('o_proj', layer.self_attn.o_proj),
                         ('post_norm', layer.post_attention_layernorm),
                         ('gate', layer.mlp.gate_proj), ('up', layer.mlp.up_proj),
                         ('down', layer.mlp.down_proj)]:
        handles.append(module.register_forward_hook(output_hook(name)))
    handles.append(layer.self_attn.o_proj.register_forward_pre_hook(input_hook('context')))
    handles.append(layer.post_attention_layernorm.register_forward_pre_hook(input_hook('attention_residual')))
    handles.append(layer.mlp.down_proj.register_forward_pre_hook(input_hook('silu_mul')))
    source = Path(inspect.getsourcefile(type(layer)))
    report = {'scope': 'HF BF16 semantic reference only; not an RTL arithmetic golden or integration PASS.',
              'checkpoint': a.checkpoint.name, 'transformers': transformers.__version__,
              'torch': torch.__version__, 'model_source_sha256': digest(source),
              'config_sha256': digest(a.checkpoint / 'config.json'), 'cases': [],
              'started_utc': dt.datetime.now(dt.timezone.utc).isoformat()}
    torch.save({name: tensor.detach().cpu().contiguous() for name, tensor in layer.state_dict().items()},
               a.out / 'layer0_weights.pt')
    report['weights_sha256'] = digest(a.out / 'layer0_weights.pt')
    # Each case uses identical predeclared tokens for both conditions, never
    # condition-specific argmax. Long case ends exactly at context length 1024.
    cases = [('m1', 0, 1), ('m7', 0, 7), ('m16', 0, 16),
             ('m31', 0, 31), ('m32', 0, 32), ('context1024', 992, 28)]
    try:
        with torch.inference_mode():
            for case_index, (name, prefix, count) in enumerate(cases):
                cache = DynamicCache(config=model.config)
                generator = torch.Generator().manual_seed(317 + case_index)
                tokens = torch.randint(0, model.config.vocab_size, (prefix + count + 4,), generator=generator)
                position = 0
                previous = None
                steps = []

                def execute(n, save):
                    nonlocal position, previous
                    captured.clear()
                    ids = tokens[position:position+n].unsqueeze(0)
                    x = model.model.embed_tokens(ids)
                    positions = torch.arange(position, position+n).unsqueeze(0)
                    cos, sin = model.model.rotary_emb(x, positions)
                    keys = torch.arange(position+n)
                    blocked = keys.unsqueeze(0) > positions.squeeze(0).unsqueeze(1)
                    mask = torch.zeros((n, position+n), dtype=x.dtype)
                    mask.masked_fill_(blocked, torch.finfo(x.dtype).min)
                    result = layer(x, attention_mask=mask[None, None], past_key_values=cache,
                                   position_embeddings=(cos, sin), use_cache=True)
                    current_key, current_value = cache.layers[0].keys, cache.layers[0].values
                    if previous is not None:
                        assert torch.equal(current_key[:, :, :position], previous[0])
                        assert torch.equal(current_value[:, :, :position], previous[1])
                    assert current_key.shape == (1, 3, position+n, 64)
                    if save:
                        q = captured['q_proj'].view(1, n, 9, 64).transpose(1, 2)
                        k = captured['k_proj'].view(1, n, 3, 64).transpose(1, 2)
                        q, k = apply_rotary_pos_emb(q, k, cos, sin)
                        assert torch.equal(k, current_key[:, :, position:])
                        score = torch.matmul(q, repeat_kv(current_key, 3).transpose(2, 3)) * layer.self_attn.scaling
                        masked_score = score + mask[None, None]
                        prob = torch.softmax(masked_score, dim=-1, dtype=torch.float32).to(x.dtype)
                        context = torch.matmul(prob, repeat_kv(current_value, 3)).transpose(1, 2).reshape(1, n, 576)
                        assert torch.equal(context, captured['context'])
                        file = a.out / f'{name}_step{len(steps)}.pt'
                        torch.save({'input_ids': ids, 'hidden': x, 'position': position,
                                    'cos': cos, 'sin': sin, 'intermediates': dict(captured),
                                    'q_rope': q, 'k_rope': k, 'score': score, 'prob': prob,
                                    'kv_key': current_key.clone(), 'kv_value': current_value.clone(),
                                    'output': result}, file)
                        steps.append({'file': file.name, 'sha256': digest(file),
                                      'phase': 'prefill' if not steps else 'decode',
                                      'start_position': position, 'rows': n,
                                      'kv_length': position+n, 'kv_prefix_preserved': True})
                    previous = (current_key.clone(), current_value.clone())
                    position += n

                while position < prefix:
                    execute(min(32, prefix-position), False)
                execute(count, True)
                for _ in range(4):
                    execute(1, True)
                report['cases'].append({'name': name, 'prefix_tokens': prefix,
                                        'token_ids': tokens.tolist(), 'steps': steps})
                print(f'{name}: prefill + 4 decode; final context={position}', flush=True)
        report['status'] = 'PASS'
    except Exception as exc:
        report['status'] = 'FAIL'
        report['error'] = repr(exc)
        raise
    finally:
        for handle in handles:
            handle.remove()
        report['elapsed_seconds'] = time.monotonic() - start
        (a.out / 'semantic_reference.json').write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    main()
