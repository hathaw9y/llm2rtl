# T03 independent evaluator

Run from the evaluator checkout (never a candidate checkout):

```sh
python experiments/llm2rtl_design_change_comparison_v1/scripts/t03_evaluate.py \
  --candidate-root /path/to/candidate --out /path/to/fresh/evidence --phase public
python experiments/llm2rtl_design_change_comparison_v1/scripts/t03_evaluate.py \
  --candidate-root /path/to/candidate --out /path/to/fresh/hidden-evidence --phase hidden
```

The default `--phase all` covers both sets. `--baseline-mode` deliberately expects the original logical-count wire encoding and is for evaluator qualification only. It must not be passed for participant acceptance. `--skip-rtl` records NOT_RUN and can never produce overall PASS. Use the configured torch Python for the mandatory numerical interpreter gate; `--python-executable` overrides it. `--vivado-bin` overrides the Vivado 2025.2 tool directory. XSIM requires an execution environment that permits its runtime operations; a sandbox runtime failure is not a design failure and must be logged separately.

The evaluator compiles actual candidate `program.c`, imports candidate semantic/codec definitions without loading a model checkpoint, executes actual candidate `Machine` with BF16 tensors, and compiles actual candidate dispatcher/executor RTL. Candidate fixtures, testbenches, and success reports are not inputs. `SHA256SUMS` freezes evaluator scripts and fixtures; the driver verifies it before evaluating. The experiment runner must keep evaluator files outside participant writable and readable resources, and keep hidden logs inaccessible to participants.

Public cases include the prescribed logical counts. Hidden cases use additional counts and diagnostic row/column patterns; phase selection controls the evaluated valid-count cases. Invalid raw and row-bound cases remain mandatory in both phases. No failure-specific hints should be returned to an active unassisted participant.

Coverage:

- Exact independent 128-bit GEMM wire records and semantic decode roundtrips; all logical counts in the combined phases; invalid raw 32..63, count 0/33/63, and start+count overflow rejected in target mode.
- PS direct and GEMM_TILES build variants, all 30 layers plus final LM head, unchanged RMS/ROPE/attention/ADD/SILU fields, invalid logical descriptor rejection before any DMA emission.
- Candidate BF16 interpreter with distinct powers of two by activation row and weight column, K16/K64, row selection, two N192 chunks, exact numerical output, two legal END partitions, output validity/progress, and untouched source/unrelated banks.
- Dispatcher direct GEMM and two-tile descriptors, independently predicted payloads and DMA address/count, rejected descriptors causing no DMA/compute/write issue, completion metadata from an independent responder, and consecutive END chunks without reset.
- Actual wide executor, valid count and row-tail cases with N17/K16 and N192/K64, exact output BF16 bits, destination address bounds, every expected element written exactly once, BF16 byte strobes, completion tag/count/banks, completion backpressure, no duplicate completion, invalid rejection with no memory reads or output writes.

Limits: this is an ISA/dense diagnostic evaluator, not full-model accuracy qualification, synthesis, routed timing, or board validation. The dispatcher and executor are simulated separately; full bank tracker/DMA/board-shell connectivity is a common integration gate. Attention count wire fields are checked but numerical QK/PV regression belongs to the common affected-mode evaluator. This task changes command ABI; automatic rejection of old binary records is not claimed. Candidate ABI documentation/manifests and matched asset publication are a separate review gate. Baseline PASS proves evaluator compatibility with the original encoding and dense behavior, not correctness of a changed candidate.
