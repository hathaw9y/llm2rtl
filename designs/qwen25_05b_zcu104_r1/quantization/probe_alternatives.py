"""Compare unadopted weight-format candidates, preserving the original probe."""
import gc
import json
import math
from pathlib import Path
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer
from int4 import quantize_int4, dequantize_int4
from probe import CHECKPOINT, TEXTS


@torch.inference_mode()
def main():
    torch.set_num_threads(8)
    previous = json.loads((Path(__file__).parent / 'quality_probe.json').read_text())
    tokenizer = AutoTokenizer.from_pretrained(CHECKPOINT, local_files_only=True)
    inputs = [tokenizer(t, return_tensors='pt')['input_ids'] for t in TEXTS]
    # Fresh baseline avoids quantizing a previously quantized tensor.
    model = AutoModelForCausalLM.from_pretrained(CHECKPOINT, local_files_only=True,
                                                torch_dtype=torch.bfloat16, attn_implementation='eager').eval()
    original_full_bf16_bytes = sum(p.numel() * 2 for p in model.parameters())
    baseline = []
    for ids in inputs:
        logits = model(ids, use_cache=False).logits.float()
        loss = torch.nn.functional.cross_entropy(logits[:, :-1].reshape(-1, logits.shape[-1]), ids[:, 1:].reshape(-1)).item()
        baseline.append((logits, loss))
    del model
    gc.collect()
    variants = []
    for group, keep_embedding in ((32, False), (128, True)):
        model = AutoModelForCausalLM.from_pretrained(CHECKPOINT, local_files_only=True,
                                                    torch_dtype=torch.bfloat16, attn_implementation='eager').eval()
        tied_parameter = model.model.embed_tokens.weight
        seen = set()
        packed_bytes = scale_bytes = quantized_values = 0
        for name, module in model.named_modules():
            if not isinstance(module, (torch.nn.Linear, torch.nn.Embedding)):
                continue
            weight = module.weight
            if id(weight) in seen or (keep_embedding and weight is tied_parameter):
                continue
            seen.add(id(weight))
            rows, columns = weight.shape
            packed_bytes += rows * ((columns + 1)//2)
            scale_bytes += rows * ((columns + group - 1)//group) * 2
            quantized_values += weight.numel()
            for start in range(0, rows, 512):
                chunk = weight[start:start+512]
                q, s = quantize_int4(chunk, group)
                chunk.copy_(dequantize_int4(q, s, group))
        assert model.lm_head.weight is model.model.embed_tokens.weight
        retained_bf16_bytes = sum(p.numel()*2 for p in model.parameters() if id(p) not in seen)
        total_bytes = packed_bytes + scale_bytes + retained_bf16_bytes
        probes = []
        for text, ids, (original_logits, original_nll) in zip(TEXTS, inputs, baseline):
            logits = model(ids, use_cache=False).logits.float()
            nll = torch.nn.functional.cross_entropy(logits[:, :-1].reshape(-1, logits.shape[-1]), ids[:, 1:].reshape(-1)).item()
            probes.append({'text': text, 'token_ids': ids[0].tolist(), 'tokens': ids.numel(),
                           'bf16_nll': original_nll, 'candidate_nll': nll,
                           'bf16_perplexity': math.exp(original_nll), 'candidate_perplexity': math.exp(nll),
                           'nll_delta': nll-original_nll,
                           'logits_rmse': (logits-original_logits).square().mean().sqrt().item(),
                           'argmax_agreement_all_positions': (logits.argmax(-1)==original_logits.argmax(-1)).float().mean().item()})
        variants.append({'name': f'int4_group{group}' + ('_bf16_tied_embedding_head' if keep_embedding else '_all_matrix_weights'),
                         'status': 'UNAPPROVED_QUALITY_CANDIDATE', 'group_size': group,
                         'keep_tied_embedding_head_bf16': keep_embedding,
                         'quantized_values': quantized_values, 'packed_int4_bytes': packed_bytes,
                         'bf16_scale_bytes': scale_bytes, 'retained_bf16_bytes': retained_bf16_bytes,
                         'retained_embedding_head_bf16_bytes': tied_parameter.numel()*2 if keep_embedding else 0,
                         'total_model_parameter_storage_bytes': total_bytes,
                         'total_model_parameter_storage_MiB': total_bytes / 2**20,
                         'quality_probes': probes})
        print(variants[-1]['name'], total_bytes/2**20, [q['candidate_perplexity'] for q in probes], flush=True)
        del model, tied_parameter, module, weight, chunk, q, s
        gc.collect()
    # Existing all-matrix group128 analysis is preserved, not rerun or overwritten.
    original_quantized_values = sum(w['elements'] for w in previous['weights'])
    baseline_retained_bytes = original_full_bf16_bytes-original_quantized_values*2
    report = {'status': 'QUALITY_CANDIDATES_ONLY_NO_FORMAT_ADOPTION',
              'checkpoint': str(CHECKPOINT), 'revision': CHECKPOINT.name,
              'source_pins': previous['source_pins'], 'runtime': previous['runtime'],
              'original_full_bf16_parameter_bytes': original_full_bf16_bytes,
              'shared_quantization_semantics': {k: v for k, v in previous['format'].items()
                                                 if k not in ('group_size', 'embedding_and_lm_head')},
              'prior_int4_group128': {'report': 'quality_probe.json',
                  'total_model_parameter_storage_bytes': previous['stored_weight_and_scale_bytes']+baseline_retained_bytes,
                  'total_model_parameter_storage_MiB': (previous['stored_weight_and_scale_bytes']+baseline_retained_bytes)/2**20,
                  'retained_bf16_bytes': baseline_retained_bytes,
                  'quality_probes': previous['quality_probes']},
              'variants': variants,
              'limitations': ['Candidates are not adopted formats; no quality acceptance threshold was specified.',
                              'Same three fixed short texts only; not representative multilingual/domain benchmarks.',
                              'Naive maxabs, no AWQ/GPTQ/calibration.',
                              'Storage includes every distinct model parameter and BF16 norm/bias exceptions, but excludes alignment, activation/KV buffers, descriptors and deployment packaging.',
                              'Dequantized BF16 eager CPU reference, not bit-exact FPGA arithmetic.']}
    (Path(__file__).parent / 'alternatives_probe.json').write_text(json.dumps(report, indent=2, ensure_ascii=False)+'\n')


if __name__ == '__main__':
    main()
