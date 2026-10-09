#!/usr/bin/env python3
"""Run a fresh CLI participant with only its workspace and common tools visible.

This script does not supply briefs or decide acceptance. Authentication is mounted
read-only without copying its contents. Supervisor/evaluator trees stay hidden.
"""
import argparse
import json
import subprocess
from pathlib import Path

USER_ROOT = Path("/home/shmin")
CLI = (USER_ROOT / ".local/bin/codex").resolve()
PYTHON_ENV = USER_ROOT / ".conda/envs/shmin"
HF = USER_ROOT / ".cache/huggingface/hub/models--HuggingFaceTB--SmolLM2-135M"
AUTH = USER_ROOT / ".codex/auth.json"
PRIVATE = Path("/media/admin1/backup/shmin")


def argv(workspace):
    return [
        "bwrap", "--die-with-parent", "--new-session", "--unshare-pid",
        "--unshare-ipc", "--unshare-uts", "--ro-bind", "/", "/",
        "--tmpfs", str(USER_ROOT), "--tmpfs", str(PRIVATE),
        "--tmpfs", "/tmp", "--proc", "/proc", "--dev", "/dev",
        "--dir", str(USER_ROOT / ".conda/envs"),
        "--ro-bind", str(PYTHON_ENV), str(PYTHON_ENV),
        "--dir", str(HF.parent), "--ro-bind", str(HF), str(HF),
        "--dir", str(USER_ROOT / ".codex"),
        "--ro-bind", str(AUTH), str(AUTH),
        "--ro-bind", str(CLI.parent), "/home/shmin/study_tools",
        "--bind", str(workspace), "/home/shmin/workspace", "--chdir", "/home/shmin/workspace",
    ]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--workspace", type=Path, required=True)
    parser.add_argument("--check-only", action="store_true")
    parser.add_argument("--brief", type=Path)
    parser.add_argument("--log", type=Path)
    args = parser.parse_args()
    workspace = args.workspace.resolve(strict=True)
    if not workspace.is_dir() or not workspace.is_relative_to(PRIVATE / "llm2rtl_experiments/isa_vs_direct_v1"):
        raise SystemExit("workspace must be a new-study directory on the backup disk")
    command = argv(workspace)
    if args.check_only:
        probe = '''import json,pathlib,subprocess
p=pathlib.Path
checks={
 "original_repository_hidden":not p("/home/shmin/llm2rtl/README.md").exists(),
 "old_trials_hidden":not p("/media/admin1/backup/shmin/llm2rtl_experiments/design_change_v1/baseline_manifest.json").exists(),
 "new_evaluator_hidden":not p("/media/admin1/backup/shmin/llm2rtl_experiments/isa_vs_direct_v1/qualification_001/report.json").exists(),
 "prior_codex_history_hidden":not p("/home/shmin/.codex/sessions").exists(),
 "workspace_visible":p("/home/shmin/workspace").is_dir(),
 "python_available":p("/home/shmin/.conda/envs/shmin/bin/python").exists(),
 "checkpoint_visible":p("/home/shmin/.cache/huggingface/hub/models--HuggingFaceTB--SmolLM2-135M/snapshots/93efa2f097d58c2a74874c7e644dbc9b0cee75a2/config.json").exists(),
 "cli_available":subprocess.run(["/home/shmin/study_tools/codex","--version"],capture_output=True).returncode==0,
}
print(json.dumps(checks))
raise SystemExit(0 if all(checks.values()) else 1)
'''
        result = subprocess.run(command + ["--", "python3", "-c", probe], capture_output=True, text=True)
        print(result.stdout, end="")
        if result.returncode:
            print(result.stderr, end="")
        raise SystemExit(result.returncode)
    if not args.brief or not args.log:
        raise SystemExit("--brief and --log are required for participant execution")
    kernel_root = workspace / "kernels"
    if not kernel_root.is_dir():
        raise SystemExit("participant workspace requires a frozen kernels directory")
    command += ["--ro-bind", str(kernel_root), "/home/shmin/workspace/kernels"]
    for name in ["semantic_reference", "kernel_contracts.json"]:
        resource = workspace / name
        if resource.exists():
            command += ["--ro-bind", str(resource), "/home/shmin/workspace/" + name]
    with args.brief.open("rb") as brief, args.log.open("wb") as log:
        result = subprocess.run(command + ["--", "/home/shmin/study_tools/codex", "exec",
            "--ephemeral", "--ignore-user-config", "--skip-git-repo-check",
            "--approve-for-me", "--json", "-m", "gpt-6.1-sol",
            "-c", 'model_reasoning_effort="medium"', "-C", "/home/shmin/workspace", "-"],
            stdin=brief, stdout=log, stderr=subprocess.STDOUT)
    raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
