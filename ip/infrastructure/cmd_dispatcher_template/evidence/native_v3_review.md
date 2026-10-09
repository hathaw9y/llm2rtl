# Independent controller-template v3 review

Read-only review under fpga-systemverilog and fpga-vivado evidence rules. Reviewer changed no RTL, tests, generator, contracts, or scripts; this report is the only repository output. The supplied controller reference, native bank binding documentation, v3 template contract, generic extension generator, base and extension tests were inspected.

## Result

No blocking finding remains in the reviewed native-controller DMA base and arbitrary-role marker-only extension smoke scope. Version 3 is an explicit opt-in split read/write ownership boundary; old exclusive-owner common contracts, model fabric, v2 history, and historical evidence are not promoted into v3 evidence.

The command BRAM remains separate from data bank IDs. The FSM fetches and validates one current-PC command, waits for bank eligibility, submits the atomic directional acquire masks, samples exact-edge accepted masks, and enters EXECUTE only after acquisition. DMA eligibility requires both owner directions and read pending to be free; bank capability masks are checked before acquisition. Native engine valid and typed command payload depend on the held command/EXECUTE state, not ready or asynchronous fault signals, preserving valid/payload under backpressure.

Each DMA bank tracks reserved/pending, engine-issued, and completed phases. Status matching checks range, pending and incomplete state, matching directional owner, and either prior issued state or the same-edge command handshake. This avoids the command/status same-edge race. Completion is retained independently of current PC; S2MM release waits until native read pending clears, and matching saved DMA-role release acceptance alone retires its tracking entry. Zero-cycle matching command/status is supported. Invalid, duplicate, wrong-direction/owner, or out-of-range status cannot manufacture a release. Ownership/ack protocol faults fail-stop with retained tracking and require coordinated reset. Matching executor errors drain correctly while a previously presented stalled command remains valid. The first error code is sticky.

END checks every fixed/user pending entry plus both owner directions and all read pending. Missing END is bounded by MAX_COMMANDS. Successful DONE supports a repeated start; error recovery requires coordinated controller/bank reset. Illegal FSM recovery reports an error and retains fail-stop behavior.

The marker-only extension demonstrates arbitrary opcode 3 with read role 3 and write role 4, atomic two-bank acquisition before engine valid, saved source/destination identity, issued/completed tracking, matching-role ownership checks, deferred completion release after read drain, and both directional release acknowledgements. Base shared code has only MM2S/S2MM fixed executor interfaces. USER hooks are usable without editing outside the markers; generated designs still own eligibility, role capabilities, arbitration, completion identity, and verification.

## Findings resolved

- Soft-error redirection initially overrode ERROR_DRAIN's terminal transition. The override now excludes drain/error terminal states; tests assert busy clears after soft-error drain.
- Illegal FSM default initially entered an error state without setting the error code. It now records ERR_OPCODE when no earlier/current fault has priority.
- DMA capability masks were added with range-first validation so unsupported mapped banks fault before acquisition and engine issue.
- Tests now cover matching asynchronous executor error while another command is stalled, including stable command valid/payload and terminal drain.

## Checks actually performed by reviewer

Reviewer executed the extension generator in /tmp/controller_native_v3_review. It reported exact marker-only body replacement PASS. Reviewer ran Verilator --lint-only -Wall -Wno-fatal separately on current base and generated extension; both exit 0. Only unused reserved command bits and inactive extension operands/hooks were warned. No width, latch, multiple-driver, or combinational-loop warnings. Local logs and source identity are recorded in /tmp/controller_native_v3_review/{base,extension}.lint.log, *.lint.exit and identity.json. These structural checks are not physical timing or memory evidence.

## Tool evidence independently inspected

Reviewer did not execute XSIM; the following completed producer runs were read and all manifest hashes compared against current files, with no mismatch:

- `evidence/run_003/native_controller_final001`: compile exit 0; elaboration and simulation exit 0 for command BRAM latency 1 and 2, with 17 directed cases each; a separate disabled DMA bank-capability profile also passes. Every decoded stdout contains the exact standalone controller PASS marker. Actual tool is Vivado 2025.2.
- `evidence/run_003/native_extension_final001`: generation, compile, elaboration and simulation exit 0; 6 directed cases and exact standalone arbitrary-role extension PASS marker. Current manifest identity matches.

The base tests connect actual native ownership/router/memory children and XPM-backed BRAM/URAM wrappers, drive typed DMA transport, check acquisition before valid, native memory payload/latency, bank-zero reuse, same-bank stall without lookahead, distinct-bank outstanding operations, valid/payload stalls, same-edge command/status, deferred reader completion, duplicate/wrong-direction/out-of-range responses, matching error drain, all-owner END drain, reset, missing END and injected acquire/release acknowledgement failure. The custom tests exercise real XPM payload movement with role-isolated native ports, atomic blocked operands, buffered onepulse completion, and mismatch/duplicate/error/alias handling. These are task-driven transport fixtures, not full DataMover or model simulations.

## Limits

Bank-only DMA tags cannot distinguish a delayed duplicate from a legitimate new completion after the same bank is reused by the same engine. The transport must provide exactly-once, correctly associated completion across reuse, or the design must add a generation/sequence tag. Wrong-engine and tracked-state mismatches are detected; arbitrary stale-completion immunity is not claimed.

Generated compute hooks require their own resource/dependency policies, sideband identity, error handling, and tests. Neither the supplied complete controller/config/engines nor an existing model revision was compiled here. The native memory collision and scheduler limitations from the bank review still apply. No reviewer-run synthesis, implementation, routed timing, board execution, or deployment claim; parent-produced OOC synthesis has separate identity and scope.

## Reviewed identity

- `ip/infrastructure/cmd_dispatcher_template/rtl/cmd_dispatcher_template.sv`: `f1082b1bb413c53bec9f6295de395db72fb00d2917e86415bb293e7feba0cd08`
- `ip/infrastructure/cmd_dispatcher_template/scripts/generate_extension_probe.py`: `2304f470363ed6aec1fa836a9b551ffa2c559ddb2f67fb29fbb848b25e67df44`
- `ip/infrastructure/cmd_dispatcher_template/template_contract.json`: `028c96d11efe01cb5fd2f23b480ae9764af8f492f9588a2d5fd5a317cafa0dd4`
- `ip/infrastructure/cmd_dispatcher_template/template_index.json`: `876f571ab44bccab52eecbc5c7b1e95203c12b82e3d9c960911348f5f431189f`
