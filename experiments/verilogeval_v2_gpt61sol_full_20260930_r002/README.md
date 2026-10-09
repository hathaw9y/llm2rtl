# VerilogEval v2 paired rerun with working self-debug checks

Completed: **312/312 jobs**. Both arms pass **142/156 (91.03%)** initial
candidates and **146/156 (93.59%)** final candidates. Development checks were
executed and ultimately passed for every job. See [RESULTS.md](RESULTS.md) for
the measured debugging changes, reference failures, timing and limitations.

This is a fresh 156-task × two-condition GPT-6.1 Sol experiment (312 jobs).
No generated candidate or model transcript from the earlier run is reused.
The pinned dataset, official test/reference files, Icarus 12, single-Agent
architecture, zero-shot setting, and one session per task per arm are retained.

Both arms use the same fixed development helper with
`-g2012 -Wall -Wno-timescale -s dev_tb`, actual-environment smoke checks,
mandatory self-checking testbenches, and a requirement to investigate failed
checks. Three RTL revisions maximum and a 600-second external deadline apply
equally to both. The previous run used 300 seconds and optional development
checks; before/after score changes are not a controlled ablation of one factor.
Common harness requirements specify the `TopModule` name and compatible enum
if/else assignments without supplying any benchmark answer or reference.

| Arm | Procedure |
| --- | --- |
| single_agent | Original specification → RTL → own development TB/checks → debugging |
| contract_based | Original specification → frozen structured contract/gate → RTL → own development TB/checks → debugging |

Both are one Agent. Both read the same SystemVerilog skill. The contract arm
additionally reads the contract-verification skill, so this compares entire
workflows rather than isolating a JSON document. The contract gate checks
structure/identity and ordering, not semantic correctness.

## Generation and debugging evidence

`smoke_environment.py` runs a correct sequential fixture, an injected faulty
fixture, and its repair through the fixed helper inside every worker's actual
environment. A separate GPT-6.1 Sol tooling preflight tests that the Agent can
read a deliberately failed development check and revise a synthetic fixture;
this is not part of the benchmark score.

`dev_check.py` captures source/testbench snapshots, real commands, exit codes,
stdout/stderr and hashes in append-only `dev_checks.jsonl` and `development/`.
It requires a successful v12 compile, successful simulation and a PASS marker
for development success. On a v12 crash it supplies v11 diagnostics only;
primary development and official scoring remain v12. Failed evidence remains
available. No official test, reference, prior candidate or evaluation feedback
is available during generation by policy. Filesystem read separation is
instruction-based, not a hard security boundary; transcripts are preserved.

Workers must debug failed development checks until development PASS or three
RTL revisions. Justified TB fixes must preserve old TBs and explain the reason.
TB edits alone are not RTL revisions. Workers cannot change expected values
merely to obtain PASS. Both reported revision counts and observed distinct RTL
versions in helper checks are recorded; this does not count every transient
unobserved edit. A session that ends unverified remains explicitly flagged.

## Scores

The initial candidate is frozen before all development checks. Both initial
and final candidates are evaluated externally using the unchanged pinned
official analyzer from the start. Report **initial-candidate functional pass
rate** and **final functional success after self-debugging** separately.
This is a tool-using Agent experiment, not a no-tool one-shot baseline.
Functional score, development-check status, and workflow compliance are separate.
Generation failures/timeouts remain in the 156-task denominator.

All 156 tasks run in both arms. The primary score includes four reference
failures identified in the preserved controls: Prob099_m2014_q6c (port mismatch),
Prob082_lfsr32, Prob141_count_clock and Prob156_review2015_fancytimer (official
TIMEOUT rejection). A supplemental score uses the 152 reference-passing tasks.
No official source is repaired and exclusions are not based on model outcomes.

Time is real subprocess wall time including model calls, tooling, contract and
debugging, excluding external official evaluation. Actual CLI token usage is
recorded. No token counts are converted into monetary cost. Decoding uses CLI
defaults and is not independently controlled. One sample per task per arm does
not establish repeated-generation variability.

## Reproduction and artifacts

```sh
python3 experiments/verilogeval_v2_gpt61sol_full_20260930_r002/run.py --workers 3
python3 experiments/verilogeval_v2_gpt61sol_full_20260930_r002/finalize.py
python3 experiments/verilogeval_v2_gpt61sol_full_20260930_r002/run.py --summary-only
```

The launcher needs the authenticated Codex runtime/network. Completed jobs are
preserved on resume. An interrupted generation must be audited before retry;
it cannot silently receive another sample. Four initial benchmark jobs are
checked before dispatching the remainder and remain part of this fresh run.

See `run_manifest.json`, `provenance/`, per-task `generation/` and `evaluation/`,
`results.csv`, `summary.json`, `final_comparison.json`, and final `RESULTS.md`.
This experiment does not measure VerilogEval v1/CVDP, MAGE, FPGA synthesis,
ZCU104 hardware, TOPS/W, multi-Agent designs, or accelerator ISA/bank contracts.
