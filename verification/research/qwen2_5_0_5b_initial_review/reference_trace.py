"""Observe pinned original Qwen execution; this is not ISA or RTL validation."""
from __future__ import annotations

from collections import Counter
import hashlib
import inspect
import json
from pathlib import Path
import sys
import time

import torch
import transformers
from safetensors.torch import save_file
from transformers import AutoModelForCausalLM, DynamicCache
from transformers.models.qwen2 import modeling_qwen2


ROOT = Path(__file__).resolve().parents[3]
BASE = Path(__file__).resolve().parent
REVISION = "060db6499f32faf8b98477b0a26969ef7d8b9987"
SNAPSHOT = Path("/tmp/llm2rtl-qwen-hf-cache/models--Qwen--Qwen2.5-0.5B/snapshots") / REVISION
sys.path.insert(0, str(ROOT / "src"))
from frontend.runtime_gemm_trace import trace_model_execution


def digest(path: Path) -> str:
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def tensor_digest(tensor: torch.Tensor) -> str:
    return hashlib.sha256(tensor.detach().cpu().contiguous().view(torch.uint8).numpy().tobytes()).hexdigest()


def main() -> None:
    torch.set_num_threads(4)
    torch.set_num_interop_threads(1)
    output_dir = BASE / "original_reference_trace"
    output_dir.mkdir(exist_ok=True)
    if (output_dir / "summary.json").exists():
        raise RuntimeError("Existing result must be reviewed before rerunning")
    source = Path(inspect.getfile(modeling_qwen2))
    if digest(source) != digest(BASE / "modeling_qwen2.py"):
        raise RuntimeError("Installed Qwen model source differs from inspected snapshot")
    if digest(SNAPSHOT / "config.json") != digest(BASE / "config.json"):
        raise RuntimeError("Downloaded checkpoint config differs from inspected snapshot")
    print("Loading pinned original BF16 checkpoint", flush=True)
    model = AutoModelForCausalLM.from_pretrained(
        str(SNAPSHOT), torch_dtype=torch.bfloat16,
        attn_implementation="eager", local_files_only=True,
    ).eval()
    if model.model.embed_tokens.weight.data_ptr() != model.lm_head.weight.data_ptr():
        raise RuntimeError("Reference embedding and LM-head weights are not tied")
    cache = DynamicCache()
    workloads = []
    for phase, tokens, expected_length in [
        ("prefill", [9707, 11], 2),
        ("decode", [151643], 3),
    ]:
        input_ids = torch.tensor([tokens], dtype=torch.long)
        before_length = cache.get_seq_length()
        start = time.perf_counter()
        result, report = trace_model_execution(
            model,
            kwargs={
                "input_ids": input_ids, "past_key_values": cache,
                "use_cache": True, "num_logits_to_keep": 1,
                "output_attentions": False, "output_hidden_states": False,
                "return_dict": True,
            },
            metadata={
                "model_id": "Qwen/Qwen2.5-0.5B", "revision": REVISION,
                "phase": phase, "input_token_ids": tokens,
                "cache_length_before": before_length,
                "torch_version": torch.__version__,
                "transformers_version": transformers.__version__,
                "dtype": "BF16", "attention": "eager",
                "scope": "original checkpoint reference, no W4 quantization or ISA",
            },
            include_raw_events=True,
        )
        elapsed = time.perf_counter() - start
        if result.logits.shape != (1, 1, 151936):
            raise RuntimeError(f"Unexpected logits shape: {result.logits.shape}")
        if not torch.isfinite(result.logits).all().item():
            raise RuntimeError("Nonfinite reference logits")
        if len(cache.key_cache) != 24 or cache.get_seq_length() != expected_length:
            raise RuntimeError("Unexpected cache layer count or length")
        tensors = {"logits": result.logits.detach().cpu().contiguous().clone()}
        states = []
        for layer, (key, value) in enumerate(zip(cache.key_cache, cache.value_cache)):
            expected_shape = (1, 2, expected_length, 64)
            if key.shape != expected_shape or value.shape != expected_shape:
                raise RuntimeError(f"Unexpected KV shape at layer {layer}")
            if not torch.isfinite(key).all().item() or not torch.isfinite(value).all().item():
                raise RuntimeError(f"Nonfinite KV at layer {layer}")
            tensors[f"layer{layer}.K"] = key.detach().cpu().contiguous().clone()
            tensors[f"layer{layer}.V"] = value.detach().cpu().contiguous().clone()
            states.append({
                "layer": layer, "K_shape": list(key.shape), "V_shape": list(value.shape),
                "dtype": str(key.dtype), "K_sha256": tensor_digest(key),
                "V_sha256": tensor_digest(value),
            })
        trace_path = output_dir / f"{phase}_trace.json"
        trace_path.write_text(json.dumps(report, indent=2) + "\n")
        tensor_path = output_dir / f"{phase}_tensors.safetensors"
        save_file(tensors, str(tensor_path), metadata={"phase": phase, "revision": REVISION})
        counts = Counter(event["operator"] for event in report["raw_events"])
        workload = {
            "phase": phase, "input_token_ids": tokens,
            "cache_length_before": before_length,
            "cache_length_after": cache.get_seq_length(),
            "cache_seen_tokens": cache._seen_tokens,
            "logits_shape": list(result.logits.shape),
            "logits_dtype": str(result.logits.dtype),
            "logits_sha256": tensor_digest(result.logits),
            "gemm_event_count": report["gemm_event_count"],
            "operator_histogram": dict(counts), "KV_state": states,
            "trace_path": str(trace_path.relative_to(ROOT)), "trace_sha256": digest(trace_path),
            "tensor_path": str(tensor_path.relative_to(ROOT)), "tensor_sha256": digest(tensor_path),
            "CPU_traced_elapsed_seconds": elapsed,
            "FPGA_performance_evidence": False,
        }
        workloads.append(workload)
        print(json.dumps({k: workload[k] for k in [
            "phase", "cache_length_before", "cache_length_after", "logits_shape", "gemm_event_count"
        ]}), flush=True)
    summary = {
        "schema": "llm2rtl.reference_execution_observation.v1",
        "status": "observed_original_reference_only",
        "model_id": "Qwen/Qwen2.5-0.5B", "checkpoint_revision": REVISION,
        "checkpoint_file": str(SNAPSHOT / "model.safetensors"),
        "checkpoint_sha256": digest(SNAPSHOT / "model.safetensors"),
        "source_sha256": digest(source), "torch_version": torch.__version__,
        "transformers_version": transformers.__version__,
        "tracer_source_sha256": digest(ROOT / "src/frontend/runtime_gemm_trace.py"),
        "script_sha256": digest(Path(__file__)),
        "tied_embedding_LM_head": True, "workloads": workloads,
        "limitations": [
            "Two-token prefill and one subsequent decode token only; maximum-length cases unobserved.",
            "Original BF16 checkpoint only; no agreed W4 numeric-model comparison yet.",
            "No ISA interpreter execution, RTL, synthesis, integration or board evidence.",
            "CPU reference computation is offline validation, not runtime PS tensor execution.",
        ],
    }
    (output_dir / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print("Reference observation saved:", output_dir / "summary.json", flush=True)


if __name__ == "__main__":
    main()
