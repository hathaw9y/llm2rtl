# T02 evaluator preparation

This directory is evaluator-owned and must not be copied into participant workspaces. Public requirements are in `adapter_contract.md`; hidden seeds, oracle implementation and calibration artifacts stay with the evaluator.

Entry points:

* `scripts/t02_evaluate.py --candidate-root ROOT --out OUT --rtl` checks software adapter plus dense production wide RTL using target physical fixtures. `--baseline-mode` selects baseline physical fixtures. `--split public|hidden|all` defaults to all.
* `scripts/t02_audit_assets.py --candidate-root ROOT --out OUT --reference-image IMAGE --reference-map MAP` checks actual image bits, allocation, full region coverage, layout/hash, and untouched embedding/norm/RoPE assets; it needs a frozen evaluator-owned full baseline map.
* `--oracle-self-test` in the first entry point is strictly calibration: it bypasses candidate software and permits the evaluator-owned minimal target-address positive control. It cannot count as candidate completion.

Calibration outcome is recorded in `calibration/summary.json`: 25 baseline and 25 target RTL cases pass, sharing identical expected BF16 hashes across different packed weight hashes for nondegenerate shapes. The unchanged-address and double-packing negative controls both fail K=64 N=7 with a BF16 output mismatch. The real image audit script passes a synthetic correct image and rejects synthetic old-order and double-packed images. Arbitrary-bit inverse checks include NaN payloads and subnormals.

Confirmed production source is `designs/smollm2_135m_bf16_zcu104_r1/rtl/smollm2_gemm_systolic_wide_executor.sv`; its dense opcode3 path is exercised using paired 128-bit bank words. No original design files were changed. Calibration copied the original source into external authorized scratch and changed only the copied weight base expression for the target positive control. XSIM compile, elaborate, and runtime logs plus exact copied RTL are retained under `calibration/t02-wide-*`.

The earlier `/tmp` sandbox runtime failed before simulation with an XSIM Tcl exception. All reported RTL calibration results come from successful escalated execution in `/media/admin1/backup/shmin/llm2rtl_experiments/design_change_v1`. No tool/environment exception is counted as a detected design mutation.

Remaining before a full T02 task gate can be claimed: actual candidate software adapter execution against production functions; full immutable baseline map/image and generated candidate image audit; changed PS C build and command trace validation; unchanged attention score/value runtime tests and board-fabric integration; full-model interpreter equivalence and required synthesis. Calibration does not claim any of those, or routed/board success. One-hot arithmetic vectors deliberately isolate physical weight addressing and do not replace general BF16 arithmetic tests.
