#!/usr/bin/env python3
"""Prove the compact PS program expands to the exact prior ISA wire stream."""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import tempfile

D = Path(__file__).resolve().parents[1]
P = D / "full_model_board_probe"


def probe_counter_bit(record: int) -> int:
    opcode, bank = record >> 124, (record >> 120) & 15
    return {4: 1, 6: 8, 7: 16, 8: 32, 9: 64, 10: 128}.get(
        opcode, (2 if bank == 4 else 4) if opcode == 5 else 0)


def check_board_fragments(records: list[int]) -> int:
    chunks = 0
    pending = 0
    seen = 0
    for record in records:
        bit = probe_counter_bit(record)
        if seen & bit:
            assert pending
            chunks += 1
            pending = seen = 0
        assert not (seen & bit)
        seen |= bit
        pending += 1
        assert pending <= 15
        if pending == 15 or (record >> 124 == 9 and (record >> 112) & 15 == 0):
            chunks += 1
            pending = seen = 0
    if pending:
        chunks += 1
    return chunks


def expand(record: int) -> list[int]:
    if record >> 124 != 12:
        return [record]
    src = (record >> 120) & 15
    weight = (record >> 116) & 15
    dst = (record >> 112) & 15
    base = (record >> 80) & 0xffffffff
    n_total = (record >> 64) & 0xffff
    k = (record >> 53) & 0x7ff
    m_start = (record >> 47) & 0x3f
    m_count = (record >> 41) & 0x3f
    n_tile = (record >> 33) & 0xff
    assert record & ((1 << 33) - 1) == 0
    assert weight == 3 and n_total and k and m_count and n_tile
    assert m_start + m_count <= 32 and n_tile <= 192
    output = []
    for n_start in range(0, n_total, n_tile):
        width = min(n_tile, n_total - n_start)
        byte_count = width * k * 2
        address = base + n_start * k * 2
        assert address <= 0xffffffff and byte_count < (1 << 23)
        load = (1 << 124) | (weight << 120) | (byte_count << 57) | (address << 25)
        gemm = ((3 << 124) | (src << 120) | (weight << 116) | (dst << 112) |
                (n_start << 47) | (n_total << 31) | (m_start << 25) |
                (m_count << 19) | (k << 8) | width)
        output.extend((load, gemm))
    return output


def run_program(directory: Path, tiled: bool) -> tuple[dict[str, list[int]], dict[str, int]]:
    executable = directory / ("tiled" if tiled else "original")
    command = ["gcc", "-std=c11", "-Wall", "-Wextra", "-Werror", "-O2"]
    if tiled:
        command.append("-DUSE_GEMM_TILES")
    command += [str(P / "program.c"), str(P / "program_trace.c"), "-o", str(executable)]
    subprocess.run(command, check=True)
    completed = subprocess.run([str(executable)], cwd=directory, check=True,
                               text=True, capture_output=True)
    chunks = {name: int(count) for name, count in re.findall(
        r"(prefill|decode) chunks=(\d+)", completed.stdout)}
    suffix = "_tiled" if tiled else ""
    traces = {name: [int(line, 16) for line in
                     (directory / f"trace_{name}{suffix}.hex").read_text().splitlines()]
              for name in ("prefill", "decode")}
    return traces, chunks


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="smollm2_tiles_verify_") as temp:
        root = Path(temp)
        original_dir, tiled_dir = root / "original", root / "tiled"
        original_dir.mkdir()
        tiled_dir.mkdir()
        original, original_chunks = run_program(original_dir, False)
        tiled, tiled_chunks = run_program(tiled_dir, True)
    results = {}
    for name in ("prefill", "decode"):
        stored = [int(line, 16) for line in (P / f"trace_{name}.hex").read_text().splitlines()]
        assert original[name] == stored, f"{name}: prior verified trace changed"
        expanded = [item for record in tiled[name] for item in expand(record)]
        assert expanded == original[name], f"{name}: compact trace changes ISA semantics"
        macro_count = sum(record >> 124 == 12 for record in tiled[name])
        assert macro_count == 30 * 7 + 1
        assert check_board_fragments(tiled[name]) == tiled_chunks[name], \
            f"{name}: PS fragment policy and trace fragment count disagree"
        results[name] = {
            "original_operations": len(original[name]),
            "compact_operations": len(tiled[name]),
            "gemm_tiles_commands": macro_count,
            "original_chunks": original_chunks[name],
            "compact_chunks": tiled_chunks[name],
            "expanded_wire_records_exact": True,
            "prior_trace_sha256": hashlib.sha256(
                (P / f"trace_{name}.hex").read_bytes()).hexdigest(),
        }
    output = P / "gemm_tiles_verification.json"
    output.write_text(json.dumps(results, indent=2) + "\n")
    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
