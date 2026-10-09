"""Local checkpoint-only weight error and short-text quality probe."""
import hashlib
import json
import math
import platform
from pathlib import Path
import torch
import transformers
from transformers import AutoModelForCausalLM, AutoTokenizer
from int4 import quantize_int4, dequantize_int4, pack_int4, unpack_int4

CHECKPOINT = Path('/home/shmin/.cache/huggingface/hub/models--Qwen--Qwen2.5-0.5B/snapshots/060db6499f32faf8b98477b0a26969ef7d8b9987')
OUTPUT = Path(__file__).parent / 'quality_probe.json'
TEXTS = [
    'The history of computing includes mechanical calculators, electronic computers, and modern software. A computer executes instructions and stores information in memory. Engineers balance speed, energy, cost, and reliability when designing a new system.',
    'Attention computes a weighted combination of values from queries and keys. A transformer uses attention together with feed-forward layers, normalization, and residual connections. During autoregressive generation, cached keys and values avoid repeating earlier work.',
    '대한민국의 수도는 서울입니다. 인공지능 모델은 학습한 정보를 바탕으로 문장을 생성합니다. 하드웨어 설계에서는 계산 정확도와 메모리 용량, 처리 속도를 함께 고려해야 합니다.',
]


def format_tests():
    generator = torch.Generator().manual_seed(41)
    cases = 0
    for columns in (1, 2, 7, 127, 128, 129, 255, 256, 257):
        w = torch.randn(3, columns, generator=generator).to(torch.bfloat16)
        w[0].zero_()
        q, s = quantize_int4(w)
        assert torch.equal(unpack_int4(pack_int4(q), columns), q)
        assert torch.equal(s[0], torch.ones_like(s[0]))
        assert torch.equal(dequantize_int4(q, s)[0], w[0])
        assert q.min() >= -7 and q.max() <= 7
        cases += 1
    codes = torch.arange(-7, 8, dtype=torch.int8).reshape(1, -1)
    assert torch.equal(codes, unpack_int4(pack_int4(codes), 15))
    assert pack_int4(torch.tensor([[-1, 7]], dtype=torch.int8)).item() == 0x7F
    w = torch.tensor([[7., .5, 1.5, 2.5, -.5, -1.5, -2.5]])
    q, _ = quantize_int4(w)
    assert q.tolist() == [[7, 0, 2, 2, 0, -2, -2]]
    rejected = 0
    for p, k in ((torch.tensor([[8]], dtype=torch.uint8), 2), (torch.tensor([[0x10]], dtype=torch.uint8), 1)):
        try:
            unpack_int4(p, k)
        except ValueError:
            rejected += 1
    assert rejected == 2
    return {'status': 'PASS', 'tail_zero_random_cases': cases, 'all_signed_codes': True, 'round_to_nearest_even_halfway': True, 'reserved_code_and_padding_rejected': True}


@torch.inference_mode()
def main():
    torch.set_num_threads(8)
    tests = format_tests()
    tokenizer = AutoTokenizer.from_pretrained(CHECKPOINT, local_files_only=True)
    model = AutoModelForCausalLM.from_pretrained(CHECKPOINT, local_files_only=True, torch_dtype=torch.bfloat16, attn_implementation='eager').eval()
    inputs = [tokenizer(t, return_tensors='pt')['input_ids'] for t in TEXTS]
    baseline = []
    for ids in inputs:
        logits = model(ids, use_cache=False).logits.float()
        loss = torch.nn.functional.cross_entropy(logits[:, :-1].reshape(-1, logits.shape[-1]), ids[:, 1:].reshape(-1))
        baseline.append((logits, loss.item()))
    print('BF16 baseline complete', flush=True)
    records = []
    seen = set()
    for name, module in model.named_modules():
        if not isinstance(module, (torch.nn.Linear, torch.nn.Embedding)):
            continue
        weight = module.weight
        if id(weight) in seen:
            continue
        seen.add(id(weight))
        err2 = signal2 = abs_err = maximum = clipping_err2 = stored_scale_err2 = bf16_round_err2 = 0.0
        count = weight.numel()
        for start in range(0, weight.shape[0], 512):
            chunk = weight[start:start + 512]
            q, scales = quantize_int4(chunk)
            assert torch.equal(unpack_int4(pack_int4(q), chunk.shape[1]), q)
            reconstructed = dequantize_int4(q, scales)
            original = chunk.float()
            error = reconstructed.float() - original
            err2 += error.square().sum().item()
            signal2 += original.square().sum().item()
            abs_err += error.abs().sum().item()
            maximum = max(maximum, error.abs().max().item())
            # Report BF16 reconstruction rounding separately from quantizer error.
            float_dq = dequantize_int4(q, scales, dtype=torch.float32)
            bf16_round_err2 += (reconstructed.float() - float_dq).square().sum().item()
            groups = scales.shape[1]
            grouped = torch.nn.functional.pad(original, (0, groups * 128 - original.shape[1])).reshape(original.shape[0], groups, 128)
            ideal_scales = grouped.abs().amax(-1) / 7
            ideal_scales = torch.where(ideal_scales == 0, torch.ones_like(ideal_scales), ideal_scales)
            ideal_q = torch.round(grouped / ideal_scales.unsqueeze(-1)).clamp(-7,7)
            ideal_dq = (ideal_q * ideal_scales.unsqueeze(-1)).reshape(original.shape[0], -1)[:, :original.shape[1]]
            stored_scale_err2 += (float_dq - ideal_dq).square().sum().item()
            excess = (grouped.abs() - 7 * scales.float().unsqueeze(-1)).clamp_min(0)
            clipping_err2 += excess.square().sum().item()
            chunk.copy_(reconstructed)
        rows, columns = weight.shape
        records.append({'name': name + '.weight', 'shape': list(weight.shape), 'elements': count,
                        'packed_bytes': rows * ((columns + 1)//2), 'scale_bytes': rows * ((columns + 127)//128) * 2,
                        'mae': abs_err/count, 'rmse': math.sqrt(err2/count), 'max_abs_error': maximum,
                        'relative_l2_error': math.sqrt(err2/signal2) if signal2 else 0,
                        'bf16_reconstruction_rounding_rmse': math.sqrt(bf16_round_err2/count),
                        'stored_scale_and_code_change_rmse_vs_fp32_scale_quantizer': math.sqrt(stored_scale_err2/count),
                        'excess_above_stored_scale_range_rmse': math.sqrt(clipping_err2/count)})
        print(name, 'quantized', flush=True)
    assert model.lm_head.weight is model.model.embed_tokens.weight
    quality = []
    for text, ids, (base_logits, base_loss) in zip(TEXTS, inputs, baseline):
        logits = model(ids, use_cache=False).logits.float()
        loss = torch.nn.functional.cross_entropy(logits[:, :-1].reshape(-1, logits.shape[-1]), ids[:, 1:].reshape(-1)).item()
        difference = logits - base_logits
        log_p = base_logits.log_softmax(-1)
        log_q = logits.log_softmax(-1)
        quality.append({'text': text, 'token_ids': ids[0].tolist(), 'tokens': ids.numel(),
                        'bf16_nll': base_loss, 'int4_dequant_bf16_nll': loss,
                        'bf16_perplexity': math.exp(base_loss), 'int4_dequant_bf16_perplexity': math.exp(loss),
                        'nll_delta': loss-base_loss, 'logits_rmse': difference.square().mean().sqrt().item(),
                        'logits_max_abs_delta': difference.abs().max().item(),
                        'argmax_agreement_all_positions': (logits.argmax(-1)==base_logits.argmax(-1)).float().mean().item(),
                        'mean_kl_baseline_to_quantized': (log_p.exp()*(log_p-log_q)).sum(-1).mean().item()})
    pins = {}
    for filename in ('config.json', 'model.safetensors', 'tokenizer.json', 'tokenizer_config.json'):
        h = hashlib.sha256()
        with (CHECKPOINT/filename).open('rb') as f:
            for block in iter(lambda: f.read(8*1024*1024), b''):
                h.update(block)
        pins[filename] = {'sha256': h.hexdigest(), 'bytes': (CHECKPOINT/filename).stat().st_size}
    report = {'status': 'QUALITY_PROBE_COMPLETE_NO_ACCEPTANCE_THRESHOLD',
              'checkpoint': str(CHECKPOINT), 'revision': CHECKPOINT.name, 'source_pins': pins,
              'runtime': {'python': platform.python_version(), 'torch': torch.__version__, 'transformers': transformers.__version__, 'threads': torch.get_num_threads()},
              'format': {'weight_codes': 'signed two-complement [-7,7], -8 reserved', 'group_axis': 'per row along K', 'group_size': 128,
                         'scale_storage': 'BF16', 'scale_rule': 'BF16(max(abs(w))/7), zero or underflow -> 1',
                         'quantize': 'RNE(FP32(w)/FP32(stored_scale)), clamp [-7,7]', 'packing': 'even K low nibble, odd K high nibble, zero odd-K padding',
                         'embedding_and_lm_head': 'quantized once; original Parameter tie preserved', 'bias_and_norm': 'original BF16'},
              'format_tests': tests, 'weights': records, 'total_packed_weight_bytes': sum(r['packed_bytes'] for r in records),
              'total_scale_bytes': sum(r['scale_bytes'] for r in records), 'quality_probes': quality,
              'limitations': ['Three short fixed texts are quality probes, not a representative perplexity benchmark or calibration corpus.',
                              'No calibration, AWQ, GPTQ, or activation-aware optimization.',
                              'BF16 eager Transformers CPU reference; no bit-exact FPGA MAC, accumulator, nonlinear, or KV proof.',
                              'Weights are dequantized to BF16 before linear and embedding execution; this measures weight-format drift only.',
                              'No acceptance threshold or hardware performance claim.']}
    elements = sum(r['elements'] for r in records)
    report['aggregate_weight_error'] = {
        'elements': elements,
        'mae': sum(r['mae'] * r['elements'] for r in records) / elements,
        'rmse': math.sqrt(sum(r['rmse'] ** 2 * r['elements'] for r in records) / elements),
        'max_abs_error': max(r['max_abs_error'] for r in records),
    }
    report['stored_weight_and_scale_bytes'] = report['total_packed_weight_bytes'] + report['total_scale_bytes']
    report['stored_weight_and_scale_MiB'] = report['stored_weight_and_scale_bytes'] / 2**20
    OUTPUT.write_text(json.dumps(report, indent=2, ensure_ascii=False)+'\n')
    print(OUTPUT, flush=True)


if __name__ == '__main__':
    main()
