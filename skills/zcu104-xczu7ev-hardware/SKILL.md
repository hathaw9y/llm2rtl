---
name: zcu104-xczu7ev-hardware
description: Use for nl2hdl hardware-specific planning, synthesis, board-wrapper, and signoff work targeting AMD ZCU104 with FPGA part xczu7ev-ffvc1156-2-e, including resource inventory, 200 MHz clock checks, PS/PL/DDR integration expectations, and ZCU104-specific Vivado evidence rules.
---

# ZCU104 XCZU7EV Hardware Profile

Use this with parent decomposition, Vivado timing closure, integration
verification, and board-wrapper signoff when the target board is AMD ZCU104 or
the FPGA part is `xczu7ev-ffvc1156-2-e`.

## Device Identity

Record this identity in every synthesis/signoff evidence claim:

- board: `AMD ZCU104`
- FPGA part: `xczu7ev-ffvc1156-2-e`
- target clock in the project config, commonly `200 MHz` for this framework
- memory data width and selected tuning knobs from the active config

## Resource Inventory

When configured, record the detailed device inventory separately from current
design budgets:

- `device_logic_cells: 504000`
- `device_lut: 230400`
- `device_ff: 460800`
- `device_dsp: 1728`
- `device_bram_36k: 312`
- `device_uram: 96`
- `device_io: 464`
- `device_distributed_ram_mb: 6.2`
- `device_bram_mb: 11.0`
- `device_uram_mb: 27.0`
- `device_ps_gtr: 4`
- `device_gth: 20`

`max_*` fields are design budgets, not device inventory. They may equal full
device capacity for a full-board target or be smaller for per-module budgets.

## Target-Scale Resource Floors

For a W4A4KV4 LLaMA target using a 32x32 weight-stationary systolic array and
`dsp_per_cell_assumption: 1`, target-scale synthesis evidence must preserve a
PE-scoped floor of `32 * 32 = 1024` DSP48-backed product cells before claiming a
real accelerator. A result far below that floor is a fixture, metadata harness,
or incorrectly disconnected datapath unless the packet explicitly sets
`dsp_per_cell_assumption: 0` and proves an alternate LUT-based multiplier
implementation with equivalent true parallel product paths.

Target-scale reports should include PE cell count, PE-scoped DSP count, product
path count, and post-synthesis/post-route utilization floor checks. Do not treat
low utilization as success for a projection-heavy accelerator unless the report
also proves the throughput target, true parallel lanes, and why the selected
architecture intentionally uses fewer active products.

## Weight Residency And Preload Checks

External DDR streaming can avoid storing the full LLaMA checkpoint on-chip, but
it does not remove the need for real on-chip tile storage. ZCU104 evidence for
GPTQ32/BF16-scale weights should record:

- total packed qweight bytes and BF16 scale/zero-point metadata bytes per
  target projection or tile;
- selected tile-buffer depth, bank count, ping-pong policy, BRAM/URAM split,
  metadata FIFO depth, and 128-bit stream width when used;
- whether full or partial preload was considered, with capacity math against
  `device_bram_36k: 312` and `device_uram: 96`;
- why the design chose external streaming, partial preload, or on-chip preload.

Do not reject preload only because the first design picked streaming. Conversely,
do not accept very low BRAM/URAM use for a claimed real accelerator unless the
streaming contract proves tile buffers, metadata buffering, backpressure, and
checkpoint byte coverage.

## Clock And Timing Rules

For a 200 MHz ZCU104 target, require an implemented clock period <= `5.000 ns`.
Do not accept a PS PL clock resolved to `5.625 ns / 177.778 MHz` as 200 MHz
board signoff, even if WNS/WHS/WPWS are positive.
Do not accept a PS PL clock resolved to `5.333 ns / 187.512 MHz` either; this
is a known Board Wrapper Agent failure pattern where the BD requested 200 MHz
but the implemented `clk_pl_0` was slower in `report_clocks` and implemented
XDC.

Evidence-only agents must compare the configured target clock against raw
`report_clocks`, `report_timing_summary`, and implemented XDC/BD clock data.
Positive timing slack at the wrong clock frequency is partial evidence only.
Board-wrapper implementation agents must not trust
`CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ`, `ACT_FREQMHZ`, divisor settings,
or pre-route BD properties alone. The post-route clock report and implemented
XDC are the source of truth for the gate.

## PYNQ Runtime Clock Gate

Build-time 5 ns timing and HWH metadata do not prove the clock actually running
after `Overlay.download()`. PYNQ clock requests can quantize to a different
frequency and can round upward; one observed request for 200 MHz produced about
214.284 MHz. Therefore, before starting DMA or the accelerator:

- hash-pin the matched BIT/HWH pair and program the overlay;
- request a realizable clock no faster than the routed maximum and read the
  actual `Clocks.fclk0_mhz` value back;
- reject an actual frequency above 200.1 MHz for a 5.000 ns design;
- if exact 200 MHz is unavailable, use a lower verified value such as 187.5 MHz
  and label measurements with that actual value;
- convert hardware cycles using the actual readback and compare it with the
  cycles/wall-time implied frequency. Wall time includes software overhead, so
  a gross inconsistency is an execution failure.

Running below 200 MHz can be a safe diagnostic execution, but it is not evidence
of 200 MHz production performance. Likewise, acknowledging a diagnostic
bitstream permits testing a nonqualified artifact; it does not weaken or bypass
the implemented arithmetic.

## PS/PL/DDR Board Wrapper Rules

Board signoff requires the routed top to be the generated PS/PL/DDR wrapper, or
an equivalent top where:

- PS FCLK/reset drive the accelerator internally;
- PS AXI or equivalent control reaches the accelerator control path;
- DDR/address-map evidence is present when DDR is claimed;
- packed-weight and KV-cache movement claims are tied to the implemented memory
  path;
- the Vivado hierarchy preserves enough evidence to inspect the wrapper,
  accelerator child, control path, and memory path.

A direct PL shell with package-level `aclk`/`aresetn` plus a side-generated
PS/PL/DDR block design is not board signoff.

## ZCU104 DRC And Evidence Rules

Do not clear board signoff when `report_drc` still flags NSTD-1 or UCIO-1
critical warnings for unconstrained/default `aclk`, `aresetn`, or other
board-visible ports.

Board evidence must include paths to:

- Vivado log;
- timing summary;
- utilization report;
- DRC report;
- methodology/constraints report;
- clock report;
- implemented checkpoint or equivalent routed artifact.

## Retry Guidance

If the board wrapper misses the target clock or routes the wrong clock:

- route retry to a board-wrapper implementation agent, not an evidence-only
  signoff agent;
- require post-route clock period <= `5.000 ns` for a 200 MHz target;
- when `report_clocks` shows `clk_pl_0` at `5.333 ns / 187.512 MHz`, treat the
  implementation as failed even if route completed, timing slack is positive,
  DRC passes, and utilization is within budget;
- for Vivado 2024.1 ZCU104 PS PL0 clocking, do not reuse an IOPLL PL0
  configuration that resolves to 187.5 MHz; use the verified RPLL PL0 source
  path for the 200 MHz board-wrapper attempt and prove the result from
  `report_clocks` plus implemented XDC;
- retry the Zynq UltraScale+ PS PL clocking setup and board-automation order,
  then prove the fix from generated routed reports rather than from requested
  BD properties;
- preserve PS/PL/DDR hierarchy evidence;
- keep setup, hold, pulse-width, DRC, methodology, and resource gates active;
- return a `skill_update_candidate` when the failure pattern is reusable.

Apply accepted updates to `skills/zcu104-xczu7ev-hardware/SKILL.md` first and
sync the runtime copy with `scripts/sync_project_skills.py`.
