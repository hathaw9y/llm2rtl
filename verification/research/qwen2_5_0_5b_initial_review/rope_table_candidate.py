"""Validate a fixed-position RoPE table candidate against the pinned source."""
from __future__ import annotations

import hashlib
import inspect
import json
from pathlib import Path
import sys

import torch
from safetensors.torch import save_file
from transformers import Qwen2Config
from transformers.models.qwen2 import modeling_qwen2


BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[2]


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    if sys.byteorder != "little":
        raise RuntimeError("DDR image writer expects little-endian host")
    if digest(Path(inspect.getfile(modeling_qwen2))) != digest(BASE / "modeling_qwen2.py"):
        raise RuntimeError("Qwen source identity mismatch")
    torch.set_num_threads(4)
    config = Qwen2Config.from_json_file(str(BASE / "config.json"))
    rotary = modeling_qwen2.Qwen2RotaryEmbedding(config=config)
    x = torch.zeros((1, 1, 896), dtype=torch.bfloat16)
    positions = torch.arange(1024).unsqueeze(0)
    with torch.inference_mode():
        cos, sin = rotary(x, positions)
        table = torch.stack((cos[0], sin[0]), dim=1).contiguous()
        single_mismatches = 0
        block_mismatches = 0
        for position in range(1024):
            c, s = rotary(x, torch.tensor([[position]]))
            actual = torch.stack((c[0], s[0]), dim=1).contiguous()
            single_mismatches += int((actual.view(torch.int16) != table[position:position + 1].view(torch.int16)).sum())
        for start in range(0, 1024, 16):
            c, s = rotary(x, positions[:, start:start + 16])
            actual = torch.stack((c[0], s[0]), dim=1).contiguous()
            block_mismatches += int((actual.view(torch.int16) != table[start:start + 16].view(torch.int16)).sum())
    if single_mismatches or block_mismatches:
        raise RuntimeError(f"Table mismatch: single={single_mismatches}, block={block_mismatches}")
    output_dir = BASE / "rope_table_candidate"
    output_dir.mkdir(exist_ok=True)
    if (output_dir / "validation.json").exists():
        raise RuntimeError("Existing table result must be reviewed before rerunning")
    tensor_path = output_dir / "table.safetensors"
    binary_path = output_dir / "table_bf16_le.bin"
    save_file({"cos_sin": table}, str(tensor_path))
    binary_path.write_bytes(table.view(torch.uint8).numpy().tobytes())
    report = {
        "schema": "llm2rtl.rope_table_candidate_validation.v1",
        "status": "candidate_table_matches_pinned_rotary_reference_only",
        "user_approval_status": "not_agreed",
        "positions": [0, 1023], "shape": list(table.shape), "dtype": "BF16",
        "layout": "position-major; cos[64] followed by sin[64]; little-endian BF16",
        "row_bytes": 256, "table_bytes": binary_path.stat().st_size,
        "max_query_tile_rows": 16, "max_query_tile_bytes": 4096,
        "single_position_decode_checks": 1024, "query_block_16_checks": 64,
        "bit_mismatches": {"decode": single_mismatches, "query_block_16": block_mismatches},
        "source_sha256": digest(BASE / "modeling_qwen2.py"),
        "config_sha256": digest(BASE / "config.json"),
        "script_sha256": digest(Path(__file__)),
        "tensor_path": str(tensor_path.relative_to(ROOT)), "tensor_sha256": digest(tensor_path),
        "binary_path": str(binary_path.relative_to(ROOT)), "binary_sha256": digest(binary_path),
        "limitations": [
            "Only fixed default-RoPE positions in the agreed context range; no dynamic RoPE or custom position IDs.",
            "Offline table generation and lookup reference comparison only; no PL RoPE multiplication/addition verification.",
            "No ISA interpreter, RTL or board evidence.",
        ],
    }
    (output_dir / "validation.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
