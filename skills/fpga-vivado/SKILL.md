---
name: fpga-vivado
description: Run, automate, inspect, and troubleshoot AMD/Xilinx Vivado 2024.1 FPGA verification and implementation flows. Use for XSIM compilation/elaboration/simulation, Vivado Tcl, project or non-project synthesis, out-of-context synthesis, implementation, timing and utilization reports, DRC and methodology checks, DSP48 or BRAM inference evidence, DSP Macro and Block Memory Generator IP, and claims about Vivado results. Pair with fpga-systemverilog when RTL or testbench code must be written or reviewed.
---

# FPGA Vivado Verification And Implementation

## Responsibility Boundary

Own Vivado execution, XSIM, Tcl automation, synthesis, implementation, timing,
resource/IP evidence, and tool-backed claims. Do not define general
SystemVerilog style here; load `fpga-systemverilog` when writing or reviewing
RTL or testbenches.

Use a hardware profile for board/part-specific inventory, clocks, interfaces,
and signoff limits. Use `fpga-board-build-signoff` for matched board artifacts,
post-route acceptance, BIT/HWH/XSA publication, and deployability claims.

## Environment Preflight

Assume Xilinx Vivado and prefer version 2024.1 unless the task specifies another
version. Record the actual version:

```bash
vivado -version
# Expected baseline: Vivado v2024.1 (64-bit)
```

Before running a flow, resolve:

- Vivado executable and version;
- FPGA part and optional board part;
- exact top module and source closure;
- constraints and target clocks;
- generated IP and simulation libraries;
- output/report directory;
- whether the request requires simulation, OOC synthesis, full implementation,
  or board signoff.

Do not silently reuse reports from a different source hash, part, top, clock,
tool version, or run.

Give concurrent Vivado processes distinct working directories as well as
distinct report/log paths. Vivado also writes relative `.Xil` scratch data;
separate report directories alone do not isolate it. In PID-isolated execution
environments, two processes can see the same PID and collide in the same
`.Xil/Vivado-<pid>-<host>` directory. If synthesis cannot open an intermediate
`incrSyn/*.gnd` file, preserve the failed log and check working-directory
overlap before changing RTL. Retry in a fresh per-process working directory;
do not delete a shared `.Xil` directory while another process may use it.

## Evidence Ladder

Keep these claims separate:

| Stage | Evidence | Does not prove |
|---|---|---|
| Compile | `xvlog` succeeds | elaboration or function |
| Elaborate | `xelab` succeeds | test correctness or synthesis |
| Simulate | self-checking `xsim` log says PASS | synthesis or timing |
| Synthesize | completed run and synth reports | routed timing |
| Implement | completed placement/routing and post-route reports | board runtime |
| Board runtime | measured deployed behavior | untested workloads |

Never promote a lower stage into a higher-stage claim.

## XSIM Flow

Use the CLI for self-contained RTL:

```bash
xvlog -sv rtl/*.sv tb/*.sv
xelab tb_top -s tb_top_sim
xsim tb_top_sim -runall
```

Use batch Vivado when IP, block designs, generated sources, or project settings
are required:

```bash
vivado -mode batch -source scripts/run_sim.tcl
```

Inspect compile, elaboration, and simulation logs separately. Claim simulation
PASS only when XSIM actually ran to completion and a self-checking test emitted
an unambiguous PASS. Treat timeouts, unresolved modules, unexpected warnings,
and a missing PASS marker as failures or incomplete evidence.

## Synthesis And Implementation

Prefer reproducible batch Tcl:

```bash
vivado -mode batch -source scripts/run_synth.tcl
```

At minimum inspect:

```text
vivado.log
reports/utilization_synth.rpt
reports/timing_synth.rpt
```

When implementation is required, also inspect run status, placement, routing,
post-route timing, DRC, methodology, congestion, and implementation utilization.
Do not describe OOC synthesis as board signoff.

## Tcl Baseline

Generate a Tcl flow with explicit project, part, top, source sets, compile order,
constraints, run completion checks, and report paths:

```tcl
set project_name "fpga_auto_project"
set project_dir  "./vivado_proj"
set part_name    "<FPGA_PART_NAME>"
set top_name     "<TOP_MODULE_NAME>"

file mkdir reports
create_project $project_name $project_dir -part $part_name -force
add_files [glob ./rtl/*.sv]
add_files -fileset sim_1 [glob ./tb/*.sv]
set_property top $top_name [current_fileset]
update_compile_order -fileset sources_1

launch_runs synth_1
wait_on_run synth_1
open_run synth_1
report_utilization -file reports/utilization_synth.rpt
report_timing_summary -file reports/timing_synth.rpt
exit
```

Add and verify a real clock constraint. Replace all placeholders before calling
the script runnable. Check run status after `wait_on_run`; do not assume that
waiting implies success.

For implementation, launch and wait for `impl_1`, open the implemented run, and
write distinct implementation utilization and timing reports.

## Timing Gate

Record every analyzed clock, requested period, actual timing stage, WNS/TNS,
WHS/THS, pulse-width slack, and failing endpoint counts. Treat these as invalid
timing evidence:

- no user-specified timing constraints;
- no path on the intended clock;
- setup, hold, or pulse-width shown as `NA`;
- a report generated for the wrong top or part;
- a stale report whose source/run identity does not match the RTL.

Positive slack at an unintended clock period is not evidence that the requested
frequency was met. Small positive hold margin may pass a bounded gate but must
remain a scaling risk.

For OOC clocks driven by buffers outside the analyzed module, specify a
validated buffer location with `HD.CLK_SRC` after defining the clock and before
placement/routing, or include an explicitly constrained buffer in the timing
harness. Do not ignore `Timing 38-242` on the analyzed clock and report the
result as fully contextualized timing. External-buffer OOC context uses clock
routing estimates, not a physically routed board clock; identify that model
and require fresh in-context evidence when integrating the module. AMD's
[OOC context constraints](https://docs.amd.com/r/2021.2-English/ug905-vivado-hierarchical-design/Context-Constraints)
and [global-clock routing limitations](https://docs.amd.com/r/en-US/ug905-vivado-hierarchical-design/Known-Issues)
describe this distinction.

For a registered-source/registered-sink OOC harness, distinguish the kernel
timing boundary from unlocated external stimulus stubs. A hold failure from
an external test port to its first harness input register is not automatically
a kernel-internal failure, but it must not be silently ignored. If module-only
analysis excludes that harness ingress, inventory the exact external-port to
top-level input-register D-pin exceptions and verify they exclude no DUT
endpoint or register-to-DUT path. Keep all source-register to DUT to sink-register
paths timed, audit exception coverage, preserve the original failure, and
explicitly withhold external-I/O and board timing claims. Otherwise provide a
physically meaningful external timing context; do not raise minimum input
delays merely to make the hold summary pass.

If timing fails, preserve the reports and isolate the critical paths. Change
only approved pipeline, fanout, placement, memory, or arithmetic knobs. Use
`hdl-vivado-timing-closure` when available for a structured retry loop.

## Utilization And Resource Evidence

Inspect LUT, FF, DSP, BRAM, URAM, and I/O use. Compare resource changes against
the RTL knob that was changed. If PE count, lane count, or buffer depth changes
but utilization does not, report that the knob is not connected to real
structure rather than repeating the same tuning.

Do not infer board fit from low utilization alone. Verify that the synthesized
design contains the intended datapath rather than a fixture, checksum harness,
metadata-only path, or optimized-away logic.

## DSP48 Evidence

Use DSP48 resources for multiplication, MAC, dot product, matrix multiplication,
convolution, and low-bit accelerator datapaths when appropriate. Plain RTL
multiplication may infer DSPs, but source syntax does not prove mapping.

Inspect the utilization hierarchy and relevant entries such as `DSP`,
`DSP48E1`, or `DSP48E2`. Claim DSP use only from the active run report.

Use DSP Macro IP when deterministic DSP structure, controlled pipelining, clock
enable, reset, or timing behavior is required. Define input/output/accumulator
widths, signedness, pipeline stages, latency, and truncation/saturation before
creating the IP.

```tcl
create_ip -name dsp_macro \
    -vendor xilinx.com \
    -library ip \
    -module_name dsp_mac_0
generate_target all [get_ips dsp_mac_0]
```

Do not invent unverified Vivado 2024.1 `CONFIG.*` fields. Configure the IP in
Vivado and export its Tcl when exact properties are unknown.

## BRAM Evidence

For inferred memory, inspect whether Vivado mapped the array to BRAM, URAM,
LUTRAM, or FF. Reset style, asynchronous reads, write mode, port conflicts, and
small depth can change mapping.

Use Block Memory Generator when exact single/dual-port behavior, initialization,
fixed read latency, byte enable, write mode, or independent clocks are required.
Define memory type, width, depth, address width, read latency, write mode,
initialization, clocks, resets, and enables before generation.

```tcl
create_ip -name blk_mem_gen \
    -vendor xilinx.com \
    -library ip \
    -module_name bram_0
generate_target all [get_ips bram_0]
```

Do not invent unverified Block Memory Generator `CONFIG.*` fields. Inspect
`Block RAM Tile`, `RAMB18`, `RAMB36`, BRAM, and URAM report entries before
making a mapping claim.

## IP And Source Closure

For generated IP or block designs:

- record the `.xci`, block design, wrapper, generated target, and repository path;
- regenerate output products when source/tool identity changes;
- include required simulation models and libraries;
- update compile order;
- reject unresolved black boxes unless the current stage explicitly allows them;
- keep testbench and stub sources out of the synthesis source set;
- record source paths and hashes for reproducibility.

## Failure Handling

Preserve the first failing log and report. Identify the exact failing command,
stage, top, part, clock, and source set. Do not overwrite failure evidence with
an unrelated retry. Stop broad tuning when repeated changes do not affect the
failing metric.

Distinguish tool failure, design failure, missing dependency, invalid evidence,
and an unmet board constraint.

## Verification Output

At the end of every Vivado task, report:

```text
RTL files changed:
Testbench files changed:
Vivado version:
FPGA part / top / target clocks:
Vivado simulation command:
Simulation result:
Vivado synthesis command:
Synthesis result:
Implementation result:
Timing stage and result:
DSP usage:
BRAM / URAM usage:
DRC / methodology / congestion:
Important warnings:
Known limitations:
Evidence paths and source/run identity:
```

If Vivado was not run, say exactly:

```text
Vivado was not run. No Vivado verification is claimed.
```

If simulation or synthesis ran but timing was not fully checked, say exactly:

```text
Simulation/synthesis was run, but timing was not fully verified.
```
