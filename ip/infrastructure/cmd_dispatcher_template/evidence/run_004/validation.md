# Native completion revision validation

Bank native_v3 and controller v4 remove bank read-pending tracking and its release guard.
The engine receives and processes every required memory response and finishes accepted
writes before it emits the completion response authorizing controller release. Controller
command pending/issued/completed and exact-edge matching-role acknowledgement remain.

Fresh source-identified XSIM results (Vivado 2025.2):

- [Bank](../../../bank_subsystem_template/evidence/native_v3_final002/manifest.json): 13 cases, 25 responses, one reset-cancelled read, plus asymmetric custom-role extension PASS.
- [Controller](native_controller_final001/source_manifest.json): 17 cases each at command latency 1 and 2, plus DMA capability rejection PASS.
- [Generated compute](native_extension_final001/source_manifest.json): 6 cases, including read response consumption and final write acceptance before completion PASS.
- [Lint](native_lint_final/lint.log): strict controller lint PASS.
- Framework: 52 tests, 50 passed, 2 skipped. Common/template identity gates PASS.

Simulation compile/elaboration/kernel exit codes are zero, exact standalone PASS
markers were checked, and all final manifest hashes match current source. Earlier
try001 packets are intermediate evidence and are not current-source results.
[Independent review](../native_v4_review.md) found no blocker under the engine
completion contract. Exact source identities and evidence paths are in
[validation_summary.json](validation_summary.json).

Fresh OOC synthesis at 5ns on xczu7ev-ffvc1156-2-e (bank `native_v3_ooc002`, controller `native_ooc001`, compute controller `native_extension_ooc001`; all actual exit0/exact PASS/current source identity):

- Bank: LUT123, FF416, RAMB36=2, URAM288=2, DSP0. Unplaced WNS3.394ns/WHS0.065ns/WPWS1.800ns.
- Controller: LUT552, FF212, BRAM/URAM/DSP0. Unplaced WNS1.646ns/WHS0.079ns/WPWS2.225ns. This controller hierarchy excludes bank memories.

- Generated compute controller: LUT788, FF227, BRAM/URAM/DSP0. Unplaced WNS1.542ns/WHS0.079ns/WPWS2.225ns; same controller OOC constraints. Fresh exit0, exact PASS and source hashes verified.

These are synthesis results and unplaced timing estimates. Bank constraints lack
external I/O delays and HD.CLK_SRC context; controller excludes external boundary
hold only. No routed timing, bitstream, full model or physical board claim.
Each generated engine requires its own completion-contract verification.
