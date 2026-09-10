---
name: hdl-generation-verification
description: Generate, revise, and verify reusable synthesizable Verilog/SystemVerilog modules before board integration. Use for RTL implementation, interface and cycle contracts, quantized datapaths, memories, FSMs, testbenches, source-closure checks, simulation, elaboration, lint, and module-level synthesis evidence. Do not use this skill as proof that a board bitstream is routed, timed, or deployable; hand that work to fpga-board-build-signoff.
---

# HDL Generation and Verification

## Purpose

Produce RTL whose functionality, interface, cycle behavior, and synthesizable source closure are proven independently of a particular FPGA board. Stop at a reusable integration packet; never equate simulation or OOC synthesis success with board signoff.

## Inputs to establish

Before editing RTL, record:

- functional equation, tensor dimensions, numeric types, rounding, saturation, and overflow rules;
- clock/reset polarity and synchronous/asynchronous semantics;
- request, ready, valid, busy, done, error, cancel, and retry behavior;
- accepted-input snapshot point and whether input mutation after acceptance is allowed;
- memory port, latency, read-during-write, initialization, byte-enable, and banking contracts;
- target throughput/latency and resource ceilings;
- integration top and all synthesizable source roots.

If one of these changes architectural behavior and cannot be inferred safely, ask before implementation.

## Workflow

### 1. Freeze the contract

Write a compact contract before RTL changes. Define legal and illegal transactions, exact cycle-visible behavior, reset recovery, cancellation semantics, and diagnostic codes. Treat dimensions and packed-byte capacity separately; never infer storage from element count without the data width.

For composable kernels, require one transaction owner and unambiguous handshakes. A pulse and a held level are different contracts. Derive cancel from the held operation state, not from a one-cycle command-valid pulse.

### 2. Reuse proven modules by contract

Search for an existing implementation first. Reuse it only after comparing ports, widths, signedness, latency, reset behavior, parameter defaults, and acceptance/done semantics. A prior GEMM or memory test does not prove a new wrapper, scheduler, address map, or dataflow.

Keep compatibility changes in adapters when possible. Do not silently alter a verified module's default behavior for one integration. Make optional optimized behavior default-off and enable it only at the exact intended instance.

### 3. Implement bounded RTL

Keep each change attributable to one contract. Use parameters for dimensions and tuning, but validate illegal combinations. Make signed casts and intermediate widths explicit. Preserve cycle alignment across parallel data, valid, tag, and control paths.

Avoid placeholder arithmetic, unreachable stubs, fixture modules, and simulation-only constructs in the synthesizable closure.

### 4. Prove transitive source closure

Starting from the integration top, prove that every instantiated synthesizable module has exactly one definition. Fail on missing or duplicate definitions, testbench/OOC/stub leakage, ambiguous generated modules, or source paths outside the approved roots.

Do not approve a hard-coded file count by itself. Bind the sorted source paths and hashes, then run elaboration against both repository sources and any packaged/copy source set used downstream.

### 5. Verify behavior in increasing scope

Run the smallest useful tests first:

1. syntax/lint and exact-top elaboration;
2. focused unit simulation for the changed behavior;
3. boundary and protocol tests;
4. numeric reference comparison, including extremes and invalid inputs;
5. reset during idle and active work, retry, cancel, backpressure, and timeout cases;
6. integration simulation with real neighboring modules rather than stubs;
7. module-level OOC synthesis for real datapath modules when the toolchain is available.

For banked memories, test every bank/matrix, first and last address, exact read latency, disabled hold, write isolation, and cross-bank isolation. For parameterized dimensions, include minimum, representative, and maximum legal cases.

### Linked numeric and persistent-state verification

Feed the exact same activation, weights, scales, cache image, and token metadata
to RTL and the CPU oracle. The oracle must consume the RTL dumps or returned host
buffers from that run; a standalone NumPy calculation does not prove linkage.
For attention, include `valid_tokens > 1`, nonuniform logits/probabilities, and
first/last token boundaries.

Use comparison semantics appropriate to each field:

- compare protocol identity, addresses, byte enables, `KEEP`, `TLAST`, tags,
  statuses, packed codes, and untouched cache entries exactly;
- compare accumulated fixed-point/FP16 values using declared per-stage error
  budgets, not blanket array equality;
- report appended K-code mismatch count/rate and maximum code delta, K-scale
  MAE/maximum error, and V MAE/maximum error separately;
- prove that every prior cache token is unchanged and that K codes, K scales,
  and V for the new token are committed together at the advertised interface.

If in-place DDR writeback can fail after one cache component succeeds, classify
that host snapshot as invalid unless a ping-pong destination and atomic pointer
swap provide real transactional publication. Test error, wrong-tag, timeout,
and resetless retry at each retirement boundary.

For DMA-fed kernels, validate every stream word or 128-bit quarter, address,
write enable, command order, and reserved metadata bit. Record CPU oracle time
separately from random generation, packing, allocation, and transfer time. A
fast vectorized CPU result is not evidence that computation was skipped; bind
the workload with dimensions, operation counts, seeds, hashes/checksums, and
coverage.

### 6. Review synthesized semantics

Use OOC synthesis to catch unsupported constructs, inferred latches, unintended RAM mapping, black boxes, and resource explosions. Classify unplaced timing only as an estimate. Never call OOC timing board signoff or claim an I/O-boundary exception unless the actual failing endpoints prove it.

### 7. Emit an integration packet

Provide:

- contract and interface summary;
- exact source manifest and hashes;
- test commands, tool versions, logs, and pass markers;
- numeric/cycle coverage summary;
- elaboration and OOC synthesis results;
- resource observations and remaining board-level risks;
- explicit statement that a new RTL/source hash invalidates older packaged IP, BIT, HWH, XSA, and routed checkpoints.

Hand the packet to `$fpga-board-build-signoff` for board integration.

## Fail-closed rules

- Do not use an old BIT/HWH after any reachable RTL, constraint, IP, address-map, or packaging change.
- Do not treat a testbench-only pass as proof of the packaged source set.
- Do not waive a failing test by weakening the expected result without explaining the changed contract.
- Do not use scalar counts where exact identity or set equality matters.
- Guard collection cardinality before indexing or querying object properties.
- Preserve failed evidence; create a fresh recovery namespace instead of rewriting history.

## References

Read [references/verification-matrix.md](references/verification-matrix.md) when designing tests or deciding whether an HDL packet is complete.
