---
name: fpga-hardware-validation
description: Prepare FPGA hardware test handoffs and assess user-returned results for an exact accelerator build. The user programs and runs the physical board; this skill supplies artifacts, tests, golden comparisons, and scoped acceptance records, not autonomous board access.
---

# FPGA Hardware Validation

## Executable project contract gate

Before implementation, verification, build or hardware-test preparation, require
the parent's repository-relative contract index, expected SHA-256 and assigned
module ID. Read `contracts/README.md`, then run from the project root:
`python3 scripts/design_contracts.py check --index INDEX --expected-sha256 SHA --module MODULE`.
Read the returned policies, design contracts, module contract and hardware profile.
Record index/hash/module identity in evidence and recheck before reporting success.
Missing, draft, mismatched or modified contracts block this packet; return to the
parent rather than freezing, editing or bypassing the gate. Use the frozen
module's scope to interpret generic role examples below; do not import legacy
fixed tile/latency assumptions. Contract-gate PASS is not RTL or hardware proof.

Own the test handoff and evidence assessment for one exact board build. The
user performs physical FPGA programming and execution. Do not connect to,
program, reset, or launch tests on the physical board under this workflow.
Local preparation and offline analysis of returned data are in scope.

## Inputs and responsibilities

Consume a stage or target packet, board profile, numeric/reference contract,
memory map, driver/register interface, test coverage, and matched artifact
manifest from `fpga-board-build-signoff`. Missing or inconsistent artifacts
return to that build owner; this skill does not certify routing or manufacture
a hardware pass from tool reports.

Use `fpga-incremental-bringup` for stage sequencing. Use the matching hardware
profile for board-specific requirements. Reuse verified runtime helpers where
available; do not assume PYNQ, an IP address, credentials, or a programming
method solely from the board name. Ask for a missing execution-environment
detail only when it prevents a usable handoff.

## Prepare the user handoff

Create `hardware_test_handoff.md` and a machine-readable
`hardware_validation_report.json` in the stage/build evidence directory.
Include or link:

- stage/build ID, source and artifact hashes, board/part, clocks and tool version;
- matching BIT/HWH and XSA where applicable, runtime dependencies and exact
  driver/register/memory-map revision;
- setup and programming instructions for the user's actual environment;
- runnable host test script or notebook, input files, independent golden
  outputs and numeric tolerances;
- ordered test commands, expected checks, finite timeouts and the precise
  logs/output arrays/counters to return;
- previous-stage regressions, newly added feature tests, and coverage limits.

Test actual payloads through the claimed DDR/DataMover Engine/adapters/local-memory/compute
path. Completion bits alone do not demonstrate arithmetic correctness.
Include repeated jobs and relevant tails, banks, scales or KV updates.
Separate kernel timing from transfer and host overhead in performance reports.
Derive tolerance from the accepted numeric contract before inspecting outputs;
do not widen it to make a failed run pass.

Check scripts locally to the extent possible without a board (syntax, golden
generation, packing and offline comparison). Distinguish these checks from
hardware execution. Tests should report the build ID and input identity and
save raw results even on failure. Any memory writes must use the contracted
test buffers and legal address ranges; never guess board addresses.

## Wait for and assess the user result

Set status to `awaiting_user_hardware_validation`, present the handoff and ask
the user to execute it and return results. This is an intentional user-owned
checkpoint. Do not poll a board or infer success from elapsed time.

When results arrive, bind them to the stage/build and test case identities.
Compare returned payloads offline where available and record failures with
expected/actual values, addresses or indices, logs and likely retry owner.
An ambiguous "works" requires clarification if the build or required test
coverage is unclear. If the user explicitly confirms the required tests for
the exact build passed but provides no raw data, record
`evidence_basis: user_attestation` and do not claim independent payload review.
Use `evidence_basis: user_run_with_reviewed_outputs` when returned outputs were
actually checked. Respect any packet requirement for raw evidence; user
attestation alone cannot satisfy such a requirement.

Report `passed`, `failed`, or `incomplete` with stage/build identity, executed
tests, evidence basis, user confirmation, numeric comparison, performance
measurement scope, missing evidence and forbidden claims. A build mismatch
is `incomplete`; request the matching results before advancement. Return the
result to the parent, which owns stage acceptance and retries.

Do not mark an unexecuted test, larger model, full context, or final model as
passed from a smaller stage. A changed bitstream or runtime affecting behavior
requires new relevant user execution. Preserve prior reports and raw results
under their original build identity.
