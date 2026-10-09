# Full VerilogEval v2 paired experiment

The full official 156-problem `spec-to-rtl` dataset is evaluated in two arms,
with one fresh GPT-6.1 Sol Codex session per problem per arm (312 jobs).
The earlier 12-problem pilot is preserved and is not reused in this score.

Completed: **312/312 jobs**. Final official success is **140/156 (89.74%)**
for `single_agent` and **138/156 (88.46%)** for `contract_based`.
Mean generation time is 74.32 seconds versus 116.17 seconds.
Post-run diagnosis found extensive development compiler failures associated
with the timescale warning path; official evaluation already disabled that
warning. See [ANALYSIS.md](ANALYSIS.md) for causes and limits on interpreting
the workflow comparison. The benchmark scores remain unchanged.
See [RESULTS.md](RESULTS.md) for the final comparison, reference-control
limitations, paired outcomes, and completion audit.

| Arm | Generation workflow |
| --- | --- |
| `single_agent` | Original specification, RTL generation and development checks in one Agent; no explicit contract |
| `contract_based` | One Agent writes and freezes a structured contract, passes its structural gate, then implements RTL and development checks |

Both arms use the same permitted SystemVerilog skill, original interface,
tool access, three-revision limit and 300-second generation deadline.
The contract arm additionally reads the contract-verification skill.
Agent count is held constant to isolate the contract-first workflow;
this is not a single-versus-multi-Agent experiment. The contract gate checks
document structure and identity, not mathematical correctness. Accelerator
ISA/bank ownership/board contracts are inapplicable to these standalone tasks.

## Reproducible conditions

- Dataset: <https://github.com/NVlabs/verilog-eval>, pinned commit
  `c498220d0a52248f8e3fdffe279075215bde2da6`.
- All 156 tasks, zero few-shot examples, one sample per task per arm.
- Explicit `codex exec --model gpt-6.1-sol`; no model fallback.
- Fresh ephemeral sessions; multi-Agent feature and web search disabled.
- Seed `20260930` randomizes problem order and paired arm order.
- Three concurrent jobs maximum.
- Official testbench, reference RTL, previous results and other task directories
  are forbidden during generation. This access separation is instructed rather
  than enforced by read restrictions; full CLI event logs are retained for audit.
- Icarus Verilog 12.0; official compile flags
  `-Wall -Winfloop -Wno-timescale -g2012 -s tb`.
- Official compilation and simulation each have a 30-second timeout.
- No official-evaluation-driven retries or RTL repairs.
- Decoding parameters use CLI defaults and are not independently controlled.

## Measurement

The runner measures generation subprocess wall time, including contract work,
development tools and model calls. Official evaluation time is separate.
CLI completion events supply actual input, cached-input, output and reasoning
token counts when available. Token counts are not converted to monetary cost.

Both initial and final candidates are evaluated. Initial-candidate pass@1 and
final workflow functional success are reported separately, each divided by all
156 tasks in the arm. The final candidate permits development-driven revisions
and must not be described as a no-tool, one-shot baseline. Workflow success
additionally requires compliance with the arm's generation protocol (artifacts,
deadline, revision limit and contract gate where applicable). Both metrics are
reported so protocol failures cannot silently change a functional score.
Timeout and missing-output jobs remain in the denominator. Infrastructure
failure without a generated candidate stops dispatch instead of turning a
model-access outage into 156 RTL failures.

Reference-control validation found an official dataset inconsistency:
`Prob099_m2014_q6c` declares `Y1/Y3` in its prompt/reference but connects `Y2/Y4`
in its testbench. The unchanged official reference fails compilation too.
`benchmark_validity.json` records the defect and a diagnostic compiler log.
Three more reference controls (`Prob082_lfsr32`, `Prob141_count_clock`,
`Prob156_review2015_fancytimer`) reach the testbench `TIMEOUT` marker, which the
pinned official analyzer rejects despite zero mismatches. Both arms still
generate and evaluate all 156 problems. The primary score follows the official
analyzer over all 156; an additional score uses the 152 reference-passing tasks
and excludes the four reference failures from paired comparisons. No benchmark
source is repaired.

`official_verdict.py` executes the pinned analyzer's unchanged `ResultRecord`
and `analyze_result` AST nodes, without loading its unrelated SDK imports or
CLI/report renderer. Finalization applies these judgments to saved compile and
simulation logs without rerunning generation or changing RTL. Provisional
runner judgments use zero-mismatch checking; the final official judgment also
honors the analyzer's timeout and compiler-warning rejection rules. Original
judgments and any changes are preserved in `official_verdict_audit.json`.

## Execution and artifacts

```sh
python3 experiments/verilogeval_v2_gpt61sol_full_20260930_r001/run.py --workers 3
python3 experiments/verilogeval_v2_gpt61sol_full_20260930_r001/finalize.py
python3 experiments/verilogeval_v2_gpt61sol_full_20260930_r001/run.py --summary-only
```

The CLI launcher requires its normal authenticated runtime and network access.
`run.py` preserves completed generations/evaluations and resumes only unfinished
jobs. An interrupted generation requires audit before retry rather than silently
getting another sample. Existing frozen candidate changes are rejected.

- `run_manifest.json`: provenance, exact arm policies, schedule and status.
- `generation/<arm>/<problem>/`: specification, policy, CLI transcript, contract
  where applicable, initial/final RTL, development checks and measured run record.
- `evaluation/<arm>/<problem>/`: exact official reference/test files, compile and
  simulation logs, hashes and initial/final judgments.
- `results.csv`: per-task paired results, seconds, revisions and token counts.
- `summary.json`: arm totals and paired disagreement task IDs.

This experiment does not measure MAGE, Vivado implementation, board performance,
or repeated-run uncertainty. The result assesses a benchmark-adapted module
contract workflow rather than the entire accelerator-generation system.
