---
name: hdl-board-wrapper-signoff
description: Implement or independently audit a hardware-specific FPGA board wrapper and Block Design composition before production artifact publication. Use for PS/PL control, AXI and address maps, DDR movers, local-memory routing, clocks, resets, XDC, Vivado Tcl, wrapper hierarchy, and routed integration evidence; pair with the target hardware profile and hand final BIT/HWH/XSA packaging to fpga-board-build-signoff.
---

# HDL Board Wrapper Signoff

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

Own the boundary between a verified accelerator hierarchy and the selected FPGA
board. This skill may implement the scoped wrapper/Block Design artifacts or
audit them, but keep implementation and independent audit evidence distinct.

Also apply the matching hardware profile, `fpga-systemverilog`, `fpga-vivado`,
and `hdl-vivado-timing-closure`. Use `fpga-board-build-signoff` afterward for
the final reproducible build and matched BIT/HWH/XSA publication.

## Required Inputs

Do not start from a generic board assumption. Require:

- verified integration top, source manifest/hashes, configuration, and coverage;
- exact board, FPGA part, Vivado version, clock targets, reset polarity, and
  hardware resource inventory;
- PS/PL, host control, AXI, interrupt, DDR, local-memory, and address-map policy;
- `contracts/block_design_layout.json` and the active hardware profile;
- pin, I/O standard, clock, generated-clock, and exception constraints;
- blocked dependencies, deployment policy, and forbidden claims.

## Composition Boundary

The Vivado Block Design is the visible system-composition boundary. Preserve
separate roles for the model scheduler, AXI control, bundled DataMover Engine,
vendor AXI DataMover, local-memory adapters, compute modules, native-memory routing, and BMG
banks. The generated BD wrapper is the FPGA top.

Do not package the entire accelerator and infrastructure as one opaque custom
RTL block. Create the BD in its intended canonical directory, including an
explicit `create_bd_design -dir` policy when applicable; do not treat transient
`.srcs` or `.gen` output as the sole source of truth.

## Implementation and Audit Checklist

- Connect the board clock/reset fabric internally and prove every generated
  clock, reset synchronizer, and clock-domain boundary.
- Expose a coherent control path with exact AXI widths, protocol converters,
  interrupts/status, and a collision-free address map.
- Keep external-memory loaders/drainers separate from compute kernels and prove
  the packed-weight, activation, KV-cache, or result movement paths that are
  actually claimed.
- Instantiate the verified accelerator top with matching source hashes and
  parameters. Reject stubs, disconnected shells, black boxes, or optimized-away
  datapaths.
- Check BD cell inventory, hierarchy, interfaces, clocks, resets, address
  assignments, local bank/router connections, and wrapper port closure.
- Constrain all required external ports and clocks. Treat default or
  unconstrained board I/O as blocking when the hardware profile says so.
- Run the packet-required Vivado synthesis/implementation flow and inspect
  timing, utilization, DRC, methodology, constraints, clock interaction,
  congestion, checkpoint, and log evidence.
- Tie every claim to one exact routed wrapper build. A fixture or disconnected
  board shell cannot establish full-model, DDR, or deployable-board readiness.

## Evidence and Handoff

Write `board_wrapper_report.json`, or the packet-specified equivalent, with:

- board, part, tool version, target clocks, resource budgets, and exact top;
- source/BD/Tcl/XDC manifests and hashes plus verified child identity;
- BD cell and connection summary, clock/reset/control/address-map status;
- DDR and local-memory integration status at the claimed coverage level;
- commands, logs, checkpoints, report paths, timing/utilization/DRC/methodology
  summaries, and any black-box or unconstrained-path count;
- `status`, evidence scope, remaining risks, forbidden claims, and any complete
  `skill_update_candidate`.

For a routed wrapper signoff result, require non-negative setup, hold, and
pulse-width slack with zero failing endpoints and no hardware-profile-blocking
DRC or methodology issue. If proof is missing, write a gap report instead of
clearing the gate.

A passing wrapper report proves board composition for the recorded build. It
does not by itself publish or certify matched deployment artifacts. Transfer
the exact sources, constraints, Tcl, hashes, reports, and checkpoint to
`fpga-board-build-signoff`, which owns the reproducible production build,
artifact validation, and final BIT/HWH/XSA claims.
