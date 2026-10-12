#!/usr/bin/env python3
"""Generate, compile and run the marker-only opcode-3 GEMM extension probe."""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import subprocess

PASS_MARKER = "PASS: marker-only GEMM port-role extension probe"
VIVADO_BIN = Path("/media/admin1/backup/tools/Xilinx/2025.2/Vivado/bin")


def logged(command: list[str], cwd: Path, log: Path) -> None:
    result = subprocess.run(command, cwd=cwd, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    log.write_text(result.stdout, encoding="utf-8")
    if result.returncode:
        raise RuntimeError(f"command failed ({result.returncode}): {' '.join(command)}")


def snapshot_run(snapshot: Path, log: Path) -> None:
    env = os.environ.copy()
    env["LD_LIBRARY_PATH"] = \
        "/media/admin1/backup/tools/Xilinx/2025.2/Vivado/lib/lnx64.o"
    p = subprocess.Popen([str(snapshot)], stdin=subprocess.PIPE,
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                         text=True, bufsize=1, env=env)
    assert p.stdin is not None and p.stdout is not None
    lines: list[str] = []

    def until(marker: str) -> None:
        while True:
            line = p.stdout.readline()
            if not line:
                raise RuntimeError(f"XSIM ended before {marker}")
            lines.append(line)
            if marker in line:
                return

    until("=elaboration-done")
    p.stdin.write("-exec-run\n"); p.stdin.flush()
    until('reason="run-complete"')
    p.stdin.write("-exec-continue\n"); p.stdin.flush()
    until('reason="finish"')
    p.stdin.write("-gdb-exit\n"); p.stdin.flush()
    lines.append(p.communicate(timeout=10)[0])
    transcript = "".join(lines)
    log.write_text(transcript, encoding="utf-8")
    if transcript.count(f'@"{PASS_MARKER}\\n"') != 1 or p.returncode:
        raise RuntimeError("extension XSIM did not produce one exact PASS marker")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--work-dir", required=True, type=Path)
    parser.add_argument("--evidence-dir", required=True, type=Path)
    args = parser.parse_args()
    template = Path(__file__).resolve().parents[1]
    work = args.work_dir.resolve(); evidence = args.evidence_dir.resolve()
    if work.exists():
        raise RuntimeError(f"fresh work directory required: {work}")
    work.mkdir(parents=True); evidence.mkdir(parents=True, exist_ok=True)
    extended = work / "cmd_dispatcher_template_extended.sv"
    logged(["python3", str(Path(__file__).with_name("generate_extension_probe.py")),
            "--source", str(args.source.resolve()), "--output", str(extended)],
           work, evidence / "extension_generate.log")
    tb = template / "tb" / "tb_cmd_dispatcher_extension_probe.sv"
    logged([str(VIVADO_BIN / "xvlog"), "--sv", str(extended), str(tb)],
           work, evidence / "extension_xvlog.log")
    logged([str(VIVADO_BIN / "xelab"), "tb_cmd_dispatcher_extension_probe",
            "-s", "cmd_dispatcher_extension_probe_sim"],
           work, evidence / "extension_xelab.log")
    snapshot_run(work / "xsim.dir" / "cmd_dispatcher_extension_probe_sim" / "xsimk",
                 evidence / "extension_xsim_direct.log")
    print(PASS_MARKER)


if __name__ == "__main__":
    main()
