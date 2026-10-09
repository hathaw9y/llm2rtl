# VerilogEval v2 GPT-6.1 Sol pilot

This is a 12-problem pilot of benchmark-adapted contract-first RTL generation,
not a full-dataset score or a comparison against MAGE.

## Observed pilot result

Final and initial candidates each passed **11/12 (91.67%)** official functional
evaluations. All 12 compiled successfully; all workers reported zero RTL
revisions, and initial/final source hashes match for all tasks.
`Prob104_mt2015_muxdff` failed with **1 mismatch in 199 samples**, first at
5 ps. The candidate has no initial assignment to `Q`; the official reference
initializes `Q=0`, while the prompt does not explicitly require initialization.
The official failure is retained and no post-evaluation RTL repair was made.

Evaluator controls accepted all 12 official reference implementations after
renaming only their module declaration to `TopModule`, and rejected a deliberately
incorrect OR implementation of the NOR problem. Run `validate_evaluator.py` to
repeat these controls. `integrity_report.json` confirms prompt, policy,
contract and candidate hashes for all tasks.

## Fixed protocol

- Official dataset: https://github.com/NVlabs/verilog-eval,
  commit `c498220d0a52248f8e3fdffe279075215bde2da6`.
- Task: `dataset_spec-to-rtl` (VerilogEval v2), 156 available problems.
- Selection: sort prompt filenames, `random.Random(20260930).sample(..., 12)`,
  then sort the selected filenames. Selection was fixed before generation.
- One fresh no-history implementation Agent per problem, requested model
  `gpt-6.1-sol` through the collaboration model override. No model fallback.
- No few-shot examples. Workers receive the official prompt, identical policy,
  and the named RTL/verification skills. Public module names, ports, widths,
  reset and timing semantics override accelerator conventions.
- Workers write `contract.json` before RTL, preserve `candidate_initial.sv`,
  and may make at most three RTL revisions using their own development checks.
- Official testbenches, reference RTL and official results are forbidden during
  generation. Workers share a filesystem, so this is instruction-based access
  separation, not enforced filesystem isolation. Raw generation artifacts and
  the policy are saved; complete Agent tool transcripts are not exported here.
- The Parent evaluates frozen candidates without sending official feedback to
  workers. No official-evaluation-driven repairs are allowed.

## Evaluation

`evaluate.py` copies unchanged official test/reference files into the separate
`evaluation/` directory, freezes candidate hashes and compiles with the official
Makefile's flags: `-Wall -Winfloop -Wno-timescale -g2012 -s tb`.
The installed Icarus Verilog 12.0 compiler and corresponding `vvp` are used.
Compilation and simulation each have a 30-second timeout. A passing run must
exit normally and print `Mismatches: 0 in N samples` with `N > 0`; all result
lines must have zero mismatches. Missing results, compile errors and timeouts
are failures. Initial and final candidates are evaluated separately.

Run from the repository root:

```sh
python3 experiments/verilogeval_v2_gpt61sol_pilot_20260930_r001/evaluate.py
```

Evaluation requires the pinned dataset checkout at
`/tmp/llm2rtl_verilogeval_20260930`; already evaluated tasks retain their exact
test/reference files under `evaluation/`. Existing results are reused only
when the final candidate source hash still matches.

## Outputs and limits

- `run_manifest.json`: task selection, settings, provenance and limitations.
- `generation/<problem>/`: prompt, policy, contract, initial/final RTL,
  development testbench/logs and worker report.
- `evaluation/<problem>/`: exact official files, compilation/simulation logs,
  source hashes and initial/final judgments.
- `results.csv` and `summary.json`: aggregate and per-problem results.

The primary pilot metric is passing final workflows divided by all 12 selected
tasks, with one sample per task. Initial-candidate success is also reported.
This is not best-of-many selection. Worker-reported elapsed times may be
approximate; they are diagnostic and not a controlled design-time comparison.
Temperature, top-p, exact reasoning settings and token/API cost are unavailable
through this Agent execution interface and are recorded as unavailable.

This pilot uses structured module specifications and self-verification. It
does not execute accelerator ISA/bank gates, measure contract ablations, run a
separate pre-final verification Agent, synthesize in Vivado or establish FPGA
performance. Official simulation supplies the independent final evaluation.
