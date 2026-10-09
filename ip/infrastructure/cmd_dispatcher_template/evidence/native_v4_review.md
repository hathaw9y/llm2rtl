# Independent review: native bank v3 / controller v4

Read-only independent review under fpga-systemverilog and fpga-vivado evidence rules. Reviewer modified no implementation, test, contract, or shared script. This report is the only repository output for this review wave. Earlier reports remain scoped to their recorded older source identities.

## Result and safety boundary

No blocking finding remains for engines obeying the new engine-completion contract. Bank read-pending tracking and ports are removed from ownership, router, bank generation template, active controller, and generated executor fixture. Controller command pending/issued/completed tracking remains.

A normal completion or clean error completion must certify that every accepted memory read response has been received and processed and every final write has been accepted. No request for that command may follow completion. The controller stores the matched completion, emits release using the saved module-port role, and retires command tracking only when matching release is accepted. An unclean engine fault requires coordinated reset while retaining ownership. This is now explicitly declared in the new engine_completion common contract, native_v3 contract, controller v4 contract, binding documentation, and source comments.

Without read-pending tracking, ownership accepts a legal matching reader release without inspecting in-flight memory reads. Neither bank nor controller can detect an engine that completes prematurely. Safety therefore depends on the engine completion certificate; this report does not claim protection for a violating engine. END checks command tracking and both owner directions; it no longer independently checks memory pipeline occupancy.

## Source review

A diff against the immutable previous controller-v3 source snapshot confirms the router change is exactly removal of the read_pending port and combinational reduction. Its response_valid and captured response_owner pipelines, registered read address/enable, data path, reset behavior, total read latency four and II one are unchanged. Memory response valid is still necessary and remains present.

Ownership retains atomic acquire and atomic release validation across banks and both directions, capability checks, conflict/overlap detection, matching roles, and reset-gated exact-edge accepted outputs. Removal of the prior pending-release guard is intentional. The controller retains acquisition before engine valid, typed payload/valid stability under backpressure and asynchronous error, range/capability legality, same-edge command/status handling, buffered completion, first-error stickiness, reset behavior, and bounded missing-END handling. Saved direction role constants continue to authorize DMA release; current owner is checked, not copied into a fabricated release role.

The marker-only arbitrary-role extension similarly retains saved operand identity, issued/completed state, captured ownership checks, and paired release acknowledgement. Its read-pending conditions are removed while its executor status contract requires all read responses and writes completed before status. No fixed compute engine name is added to shared implementation.

Bank-only tags retain the existing exactly-once transport requirement across same-engine same-bank reuse; a late duplicate indistinguishable from a new command cannot be detected without a generation tag. Native memory collision policies and generated arbitration requirements remain design responsibilities. Existing exclusive-owner contracts/model revisions are not automatically migrated.

## Checks independently executed

In /tmp/native_v4_readonly_review, reviewer materialized the bank package/top and executed the marker-only controller extension generator (exit 0, exact generator PASS). Reviewer ran Verilator --lint-only -Wall -Wno-fatal on the current controller, generated controller extension, and generated bank top plus generic children and existing vendor interface stubs. All three exit 0. Controller warnings are inactive/reserved fields only; bank warnings are filename mismatch and intentionally unused/undriven vendor interface stubs. No width, latch, multiple-driver, or combinational-loop warning. Logs, exit files, and source identity are stored in that unique /tmp directory.

## Completed evidence inspected

Reviewer did not execute XSIM. The following producer evidence was inspected: all bound source hashes match current files at review time, compile/elaboration/simulation exit files are zero, and decoded stdout has exact standalone PASS markers.

- `ip/infrastructure/bank_subsystem_template/evidence/native_v3_final002`: 13 DMA bank cases, 25 responses / 26 accepted reads (one cancelled by reset), plus custom asymmetric role extension PASS. Tests retain latency/payload/II/owner/error/reset/prefix coverage and issue reader release after memory responses are consumed on a later sink clock edge.
- `ip/infrastructure/cmd_dispatcher_template/evidence/run_004/native_controller_final001`: 17 cases each at command BRAM latency 1 and 2, plus disabled DMA capability case. The connected XPM memory roundtrip explicitly waits for all four checked responses and a sink consumption edge before engine completion and asserts no prior release. Command and ownership errors, stalled valid, same-edge command/status, exactly-once release, reset and terminal drain regressions remain.
- `ip/infrastructure/cmd_dispatcher_template/evidence/run_004/native_extension_final001`: 6 custom two-bank executor cases. The fixture consumes the XPM read payload, waits for final result-write acceptance, then emits engine completion; the generated result is subsequently checked under a new DMA read owner. Atomic blocked operands, role-isolated ready/response, wrong operands, duplicate completion, clean error, and alias legality are checked.

Actual tool is Vivado 2025.2. These are task-driven DMA/executor transport fixtures with real native children and XPM memories, not a full model or physical board run. Earlier native_v2/controller_v3 evidence is historical and is not reused as a PASS for current sources.

## Limitations

No reviewer-run synthesis, placement/routing, board execution, full DataMover/controller model integration, or physical timing claim. Parent-produced OOC evidence is separate. Invalid premature engine completion is expressly outside the new protocol and is not dynamically blocked by the removed pending guard. Generated engines require their own proof that completion follows all required responses and accepted writes.

## Reviewed identity

- `ip/infrastructure/bank_subsystem/rtl/bank_native_ownership.sv`: `ef51179c257fc526e6baf84733fc9abc7598197fba1b085b618472ea07a5085f`
- `ip/infrastructure/bank_subsystem/rtl/bank_native_router.sv`: `a88e90da2826110bee28c8d3bddfab87adee774eb2f40cfb85ecad6daccee4bc`
- `ip/infrastructure/bank_subsystem_template/rtl/bank_subsystem.sv.tpl`: `c656addf5ee41dd8b0636332a2df00bc73860808b1f677b812fc94fbcff4dfa7`
- `ip/infrastructure/cmd_dispatcher_template/rtl/cmd_dispatcher_template.sv`: `867cc4d6b17383043d63444af202f637712a9e6391cf563a3c7d601585934223`
- `ip/infrastructure/cmd_dispatcher_template/scripts/generate_extension_probe.py`: `cbb6f89d5aceea8e57d979ac0478c8855b1d0266c2de322bc1c209c8810fe908`
- `ip/infrastructure/bank_subsystem/contracts/native_v3.json`: `631c393c53cd56a9c916c91fe5b685be572569fa8c19bb3bb22aebd802e70d1f`
- `ip/infrastructure/cmd_dispatcher_template/template_contract.json`: `7657697438b595e983de27eb0fb03b046cbb493d0304548d2e1926ea1a66becc`
- `contracts/common/engine_completion_contract.json`: `f66d131fa5c5dab54ab637633d395772ee4b73c4374c51308e05143939bf3446`
- `ip/infrastructure/bank_subsystem_template/tb/tb_bank_native.sv`: `793af7a8b08345d15b0f57416d49962e9866b79e83a1a5341d2a830f503f4f82`
- `ip/infrastructure/cmd_dispatcher_template/tb/tb_cmd_dispatcher_template.sv`: `f7aa5b94b94142dbf328dc927fc864fb32205ef69990e7fe55f6a30e60cd4a47`
- `ip/infrastructure/cmd_dispatcher_template/tb/tb_cmd_dispatcher_extension_probe.sv`: `cc77d3085872de9d7baa3100ea2760090c20b63290d1241878a33f0d884baa09`
- `ip/infrastructure/bank_subsystem_template/tb/tb_bank_extension.sv`: `98bdf68c37f892c559407739ecf20ba7ad8aad050e1b84f275d1c3a546ab5995`
