"""Example factory for one cache-free Llama 3.2 1B prefill path."""

from __future__ import annotations

import hashlib
from pathlib import Path

import torch
import transformers
from transformers import AutoModelForCausalLM
from transformers.models.llama import modeling_llama


MODEL_ROOT = Path(
    "/home/shmin/.cache/huggingface/hub/"
    "models--meta-llama--Llama-3.2-1B"
)


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def build_case():
    revision = (MODEL_ROOT / "refs/main").read_text().strip()
    snapshot = MODEL_ROOT / "snapshots" / revision
    model = AutoModelForCausalLM.from_pretrained(
        snapshot,
        local_files_only=True,
        dtype=torch.bfloat16,
        attn_implementation="eager",
    ).eval()
    model.config.use_cache = False
    token_count = 4
    input_ids = torch.arange(1, token_count + 1, dtype=torch.long).unsqueeze(0)
    attention_mask = torch.ones((1, token_count), dtype=torch.long)
    position_ids = torch.arange(token_count, dtype=torch.long).unsqueeze(0)
    return {
        "model": model,
        "args": (),
        "kwargs": {
            "input_ids": input_ids,
            "attention_mask": attention_mask,
            "position_ids": position_ids,
            "use_cache": False,
            "return_dict": False,
        },
        "metadata": {
            "model_id": "meta-llama/Llama-3.2-1B",
            "model_revision": revision,
            "snapshot": str(snapshot),
            "model_file_sha256": _sha256(snapshot / "model.safetensors"),
            "config_file_sha256": _sha256(snapshot / "config.json"),
            "torch_version": torch.__version__,
            "transformers_version": transformers.__version__,
            "modeling_source": str(Path(modeling_llama.__file__).resolve()),
            "modeling_source_sha256": _sha256(Path(modeling_llama.__file__)),
            "execution_path": "cache_free_prefill",
            "batch_size": 1,
            "token_count": token_count,
            "attention_implementation": "eager",
        },
    }
