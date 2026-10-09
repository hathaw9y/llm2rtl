#!/usr/bin/env python3
# Durable evaluator and evidence live on the separate disk (root filesystem ENOSPC).
import os, runpy
from pathlib import Path
target = Path("/media/admin1/backup/llm2rtl_experiments/verilogeval_v2_reaudit_synth_20261005_r001/run.py")
os.environ["TMPDIR"] = str(target.parent / "tmp")
runpy.run_path(str(target), run_name="__main__")
