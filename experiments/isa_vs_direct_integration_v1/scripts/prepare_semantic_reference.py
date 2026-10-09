#!/usr/bin/env python3
"""Neutral HF layer reference: no ISA compiler, interpreter or controller."""
import argparse
import hashlib
import inspect
import json
import time
from pathlib import Path

import torch
import transformers
from transformers import AutoModelForCausalLM
from transformers.cache_utils import DynamicCache
from transformers.models.llama import modeling_llama

REVISION = "93efa2f097d58c2a74874c7e644dbc9b0cee75a2"
CHECKPOINT = Path("/home/shmin/.cache/huggingface/hub/models--HuggingFaceTB--SmolLM2-135M/snapshots") / REVISION


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=False)
    started = time.monotonic()
    torch.set_num_threads(4)
    torch.manual_seed(601006)
    model = AutoModelForCausalLM.from_pretrained(
        str(CHECKPOINT), local_files_only=True, dtype=torch.bfloat16,
        attn_implementation="eager",
    ).eval()
    layer = model.model.layers[0]
    captures = {}
    handles = []

    def record(name):
        def hook(module, inputs, output):
            captures[name] = output.detach().clone()
        return hook

    for name, module in [
        ("input_norm", layer.input_layernorm),
        ("q_proj", layer.self_attn.q_proj), ("k_proj", layer.self_attn.k_proj),
        ("v_proj", layer.self_attn.v_proj), ("o_proj", layer.self_attn.o_proj),
        ("post_norm", layer.post_attention_layernorm),
        ("gate", layer.mlp.gate_proj), ("up", layer.mlp.up_proj),
        ("down", layer.mlp.down_proj),
    ]:
        handles.append(module.register_forward_hook(record(name)))

    def context_hook(module, inputs):
        captures["context"] = inputs[0].detach().clone()

    handles.append(layer.self_attn.o_proj.register_forward_pre_hook(context_hook))
    report = {
        "checkpoint": REVISION, "torch": torch.__version__,
        "transformers": transformers.__version__,
        "scope": "HF semantic reference only; not fixed-kernel arithmetic golden or RTL PASS",
        "cases": [],
    }
    source_file = Path(inspect.getfile(modeling_llama))
    report["execution_source"] = {"file": str(source_file), "sha256": hashlib.sha256(source_file.read_bytes()).hexdigest()}
    torch.save({k: v.detach().clone() for k, v in layer.state_dict().items()}, args.out / "layer0_weights.pt")
    (args.out / "config.json").write_text(model.config.to_json_string())

    def execute(ids, position, cache):
        captures.clear()
        x = model.model.embed_tokens(ids)
        rows = ids.shape[1]
        positions = torch.arange(position, position + rows).unsqueeze(0)
        cos, sin = model.model.rotary_emb(x, positions)
        key_positions = torch.arange(position + rows)
        allowed = key_positions[None, :] <= positions[0, :, None]
        mask = torch.zeros((1, 1, rows, position + rows), dtype=torch.bfloat16)
        mask.masked_fill_(~allowed[None, None], torch.finfo(torch.bfloat16).min)
        before = None
        if position:
            before = {"key": cache.layers[0].keys.clone(), "value": cache.layers[0].values.clone()}
        output = layer(x, attention_mask=mask, position_ids=positions,
                       past_key_values=cache, use_cache=True, position_embeddings=(cos, sin))
        q = captures["q_proj"].reshape(1, rows, 9, 64).transpose(1, 2)
        k = captures["k_proj"].reshape(1, rows, 3, 64).transpose(1, 2)
        v = captures["v_proj"].reshape(1, rows, 3, 64).transpose(1, 2)
        q_rope, k_rope = modeling_llama.apply_rotary_pos_emb(q, k, cos, sin)
        actual_k, actual_v = cache.layers[0].keys, cache.layers[0].values
        assert torch.equal(actual_k[:, :, position:], k_rope)
        assert torch.equal(actual_v[:, :, position:], v)
        if before:
            assert torch.equal(actual_k[:, :, :position], before["key"])
            assert torch.equal(actual_v[:, :, :position], before["value"])
        keys = modeling_llama.repeat_kv(actual_k, 3)
        values = modeling_llama.repeat_kv(actual_v, 3)
        score = (q_rope @ keys.transpose(-1, -2)) * layer.self_attn.scaling
        probability = torch.softmax(score + mask, dim=-1, dtype=torch.float32).to(torch.bfloat16)
        context = (probability @ values).transpose(1, 2).reshape(1, rows, 576).contiguous()
        assert torch.equal(context, captures["context"]), "attention context source mismatch"
        attention_residual = x + captures["o_proj"]
        swiglu = layer.mlp.act_fn(captures["gate"]) * captures["up"]
        assert torch.equal(output, attention_residual + captures["down"])
        return {
            "input_ids": ids.clone(), "position": position, "hidden": x.clone(),
            "cos": cos.clone(), "sin": sin.clone(), "mask": mask.clone(),
            **captures, "q_rope": q_rope.clone(), "k_rope": k_rope.clone(),
            "score": score, "probability": probability,
            "attention_residual": attention_residual, "swiglu": swiglu,
            "output": output.clone(), "kv_before": before,
            "kv_after": {"key": actual_k.clone(), "value": actual_v.clone()},
        }

    try:
        with torch.inference_mode():
            for name, prefix, initial_rows, decodes in [
                ("single", 0, 1, 0), ("short", 0, 7, 3),
                ("prefill32", 0, 32, 3), ("context1024", 1023, 1, 0),
            ]:
                cache = DynamicCache(config=model.config)
                stream = torch.randint(3, model.config.vocab_size, (1, prefix + initial_rows + decodes))
                for position in range(0, prefix, 32):
                    execute(stream[:, position:min(prefix, position + 32)], position, cache)
                position = prefix
                traces = []
                for step in range(decodes + 1):
                    rows = initial_rows if step == 0 else 1
                    traces.append(execute(stream[:, position:position + rows], position, cache))
                    position += rows
                path = args.out / (name + ".pt")
                torch.save(traces, path)
                report["cases"].append({"name": name, "prefix": prefix,
                    "rows": initial_rows, "decodes": decodes, "full_channels": True,
                    "kv_prefix_preserved": True, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
                print(name, "SEMANTIC_REFERENCE_READY", flush=True)
    finally:
        for handle in handles:
            handle.remove()
        report["elapsed_seconds"] = time.monotonic() - started
        report["weights_sha256"] = hashlib.sha256((args.out / "layer0_weights.pt").read_bytes()).hexdigest()
        (args.out / "report.json").write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
