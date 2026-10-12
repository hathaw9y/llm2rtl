#!/usr/bin/env python3
"""Compile, elaborate and run the exact cmd_dispatcher_template XSIM snapshot."""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import subprocess


PASS_MARKER = "PASS: cmd_dispatcher_template fixed infrastructure verification"
VIVADO_BIN = Path("/media/admin1/backup/tools/Xilinx/2025.2/Vivado/bin")


def run_logged(command: list[str], cwd: Path, log: Path) -> None:
    result = subprocess.run(command, cwd=cwd, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    log.write_text(result.stdout, encoding="utf-8")
    if result.returncode:
        raise RuntimeError(f"command failed ({result.returncode}): {' '.join(command)}")


def run_snapshot(snapshot: Path, log: Path) -> None:
    environment = os.environ.copy()
    environment["LD_LIBRARY_PATH"] = \
        "/media/admin1/backup/tools/Xilinx/2025.2/Vivado/lib/lnx64.o"
    process = subprocess.Popen([str(snapshot)], stdin=subprocess.PIPE,
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                               text=True, bufsize=1, env=environment)
    assert process.stdin is not None
    assert process.stdout is not None
    lines: list[str] = []

    def read_until(marker: str) -> None:
        while True:
            line = process.stdout.readline()
            if not line:
                raise RuntimeError(f"XSIM ended before {marker}")
            lines.append(line)
            if marker in line:
                return

    read_until("=elaboration-done")
    process.stdin.write("-exec-run\n")
    process.stdin.flush()
    read_until('reason="run-complete"')
    process.stdin.write("-exec-continue\n")
    process.stdin.flush()
    read_until('reason="finish"')
    process.stdin.write("-gdb-exit\n")
    process.stdin.flush()
    tail = process.communicate(timeout=10)[0]
    lines.append(tail)
    transcript = "".join(lines)
    log.write_text(transcript, encoding="utf-8")
    exact_line = f'@"{PASS_MARKER}\\n"'
    if transcript.count(exact_line) != 1:
        raise RuntimeError("exact standalone PASS marker missing or duplicated")
    if process.returncode:
        raise RuntimeError(f"XSIM snapshot exit code {process.returncode}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--work-dir", required=True, type=Path)
    parser.add_argument("--evidence-dir", required=True, type=Path)
    args = parser.parse_args()

    template_dir = Path(__file__).resolve().parents[1]
    rtl = template_dir / "rtl" / "cmd_dispatcher_template.sv"
    tb = template_dir / "tb" / "tb_cmd_dispatcher_template.sv"
    work_dir = args.work_dir.resolve()
    evidence_dir = args.evidence_dir.resolve()
    if work_dir.exists():
        raise RuntimeError(f"fresh work directory required: {work_dir}")
    work_dir.mkdir(parents=True)
    evidence_dir.mkdir(parents=True, exist_ok=True)
    logs = [evidence_dir / name for name in
            ("xvlog.log", "xelab.log", "xsim_direct.log")]
    if any(path.exists() for path in logs):
        raise RuntimeError("refusing to overwrite immutable XSIM evidence")

    run_logged([str(VIVADO_BIN / "xvlog"), "--sv", str(rtl), str(tb)],
               work_dir, logs[0])
    snapshot_name = "cmd_dispatcher_template_sim"
    run_logged([str(VIVADO_BIN / "xelab"), "tb_cmd_dispatcher_template",
                "-s", snapshot_name], work_dir, logs[1])
    run_snapshot(work_dir / "xsim.dir" / snapshot_name / "xsimk", logs[2])
    print(PASS_MARKER)


if __name__ == "__main__":
    main()
