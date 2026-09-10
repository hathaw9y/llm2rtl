---
name: fpga-systemverilog
description: Write, review, and revise synthesizable FPGA RTL and self-checking testbenches in SystemVerilog. Use for RTL coding style, clock/reset contracts, port and signal naming, always_ff/always_comb correctness, valid/ready protocols, explicit widths and signedness, parameterized datapaths, pipeline and latency contracts, FSMs, memories, arithmetic, and static RTL review independent of a specific FPGA tool. Pair with fpga-vivado when XSIM, synthesis, implementation, timing, IP generation, or Xilinx resource evidence is required.
---

# FPGA SystemVerilog RTL

## Responsibility Boundary

Own SystemVerilog language, RTL structure, interface semantics, cycle behavior,
and testbench quality. Do not claim simulator, synthesis, timing, DSP, BRAM, or
board results from code inspection alone.

Load `fpga-vivado` as well when the task requires XSIM, Vivado Tcl, synthesis,
implementation, timing, DSP/BRAM mapping, or Xilinx IP. Load the relevant
numeric or architecture skill before coding quantization, adder trees, DSP
packing, Softmax, LayerNorm, or memory schedules.

## Default HDL

Use SystemVerilog by default. Prefer:

```systemverilog
logic
always_ff
always_comb
parameter
localparam
typedef enum logic
```

Use legacy `reg`, `wire`, `always @(posedge clk)`, or `always @(*)` only when
an explicit compatibility requirement demands it. Record the exception.

## Clock And Reset Contract

Name the primary clock and reset:

```systemverilog
input logic aclk;
input logic aresetn;
```

Treat `aresetn` as an active-low synchronous reset by default:

```systemverilog
always_ff @(posedge aclk) begin
    if (!aresetn) begin
        state_r <= IDLE;
        count_r <= '0;
    end else begin
        state_r <= state_n;
        count_r <= count_n;
    end
end
```

Use asynchronous reset only when a protocol, IP, CDC, or board contract
explicitly requires it. Do not silently mix synchronous and asynchronous reset
semantics.

## Naming Convention

Do not append `_i` or `_o` to public ports. Direction is already explicit in
the declaration. Preserve protocol-role prefixes such as `m_axi_`, `s_axi_`,
`m_axis_`, and `s_axis_`.

Use lowercase snake case for modules and signals. Use uppercase snake case for
parameters and local parameters.

| Signal role | Suffix | Example |
|---|---|---|
| Register | `_r` | `acc_r` |
| Next value/state | `_n` | `state_n` |
| Combinational signal | `_w` | `sum_w` |
| Pipeline register | `_s0_r`, `_s1_r` | `product_s1_r` |
| Handshake | `_valid`, `_ready` | `out_valid` |

Avoid vague names such as `tmp`, `sig`, `data2`, or `aaa`.

## Sequential And Combinational Logic

Use `always_ff @(posedge aclk)` for sequential logic. Use only nonblocking
assignment (`<=`) inside `always_ff`. Reset all architecturally important
registers.

Use `always_comb` for combinational logic. Use blocking assignment (`=`),
assign defaults first, cover every case branch, and include `default`:

```systemverilog
always_comb begin
    state_n = state_r;
    count_n = count_r;

    case (state_r)
        IDLE: begin
            if (start) begin
                state_n = RUN;
                count_n = '0;
            end
        end
        RUN: begin
            if (done_w) begin
                state_n = DONE;
            end
        end
        DONE: begin
            state_n = IDLE;
        end
        default: begin
            state_n = IDLE;
            count_n = '0;
        end
    endcase
end
```

Reject inferred-latch risk, mixed blocking/nonblocking misuse, incomplete state
recovery, and multiple procedural drivers.

## Synthesizable RTL Boundary

Keep non-synthesizable constructs out of DUT RTL. Allow the following only in
testbenches or explicitly simulation-only files:

```systemverilog
#10
initial
fork/join
randomize
class
queue
dynamic array
$display
$finish
```

Treat vendor primitives and IP wrappers as explicit dependencies. Keep portable
RTL separate from simulation-only code and generated wrappers.

## Width And Signedness

Declare operand and intermediate signedness explicitly:

```systemverilog
logic signed [DATA_WIDTH-1:0] a;
logic signed [DATA_WIDTH-1:0] b;
logic signed [(2*DATA_WIDTH)-1:0] product_w;
```

Size constants where expression width matters. Prefer a cast such as
`ACC_WIDTH'(1)` or an explicit extension over an unsized literal. Size every
product, partial sum, accumulator, address, counter, shift, and requantization
boundary deliberately.

Define these numeric behaviors before implementation:

- rounding mode;
- truncation location;
- saturation or wraparound;
- accumulator width and overflow policy;
- signed cast and extension points;
- packed element order.

For packed vectors, use little element order unless the project contract says
otherwise: `element[idx] == vector[idx*WIDTH +: WIDTH]`.

## Interface And Cycle Contract

Prefer valid/ready for streaming datapaths:

```systemverilog
input  logic        in_valid;
output logic        in_ready;
input  logic [31:0] in_data;

output logic        out_valid;
input  logic        out_ready;
output logic [31:0] out_data;
```

Define and review:

- the exact input acceptance condition;
- latency from accepted input to corresponding output;
- pipeline depth and initiation interval;
- sustained throughput;
- whether backpressure is supported;
- output/data/sideband stability while stalled;
- reset and post-reset behavior;
- tail and partial-vector semantics;
- `start`, `busy`, `done`, `error`, cancel, and retry semantics when present.

Move data, valid, tags, scale/exponent metadata, masks, and addresses through the
same logical transaction. Do not pipeline the payload without its sidebands.

## Timing-Aware RTL Structure

Assume timing matters even though this skill does not run a timing tool.
Pipeline multipliers, adder trees, comparisons, reductions, wide muxes, address
generation, and memory-output decode when the target clock requires it.

Prefer registered balanced reductions over long combinational chains. After a
pipeline change, update latency, initiation interval, valid alignment, stall
behavior, and output ordering. Do not claim timing closure until `fpga-vivado`
or another implementation/signoff skill inspects a real timing report.

## Memory RTL

Use compact memories for weights, activations, lookup tables, FIFOs, and tile
buffers rather than large resettable register arrays. Define:

- word width, depth, address units, and bank count;
- read latency and enable behavior;
- write mask/byte enable;
- read-during-write semantics;
- initialization policy;
- single-clock or multi-clock behavior;
- producer, consumer, ownership, and ping-pong state.

Write portable inferred memory when behavior is simple. Defer deterministic
Xilinx BRAM mapping and Block Memory Generator configuration to `fpga-vivado`.

## Testbench Rules

Keep testbench-only syntax out of RTL. Make testbenches self-checking and include:

- clock generation and reset sequence;
- directed normal cases;
- minimum, maximum, signed, overflow, tail, and boundary cases;
- stalls and bursty valid when supported;
- reset during activity and repeated transactions;
- timeout protection;
- automatic expected-versus-actual comparison;
- an unambiguous final PASS or FAIL marker.

Printing values or generating a waveform without checking the DUT is not a
self-checking test.

## Review Checklist

- Check `logic`, `always_ff`, and `always_comb` usage.
- Check `aclk` and synchronous active-low `aresetn` semantics.
- Check public port names and protocol-role prefixes.
- Check blocking/nonblocking assignments and inferred latches.
- Check width, signedness, casts, shifts, and overflow behavior.
- Check reset, illegal-state recovery, and repeated invocation.
- Check valid/ready stability and sideband alignment.
- Check latency, initiation interval, throughput, and tails.
- Check memory latency, address units, and read-during-write behavior.
- Check testbench coverage and that it observes real DUT outputs.

Prefer minimal, surgical fixes over unrelated rewrites.

## Output Contract

At the end of an RTL-only task, report:

```text
RTL files changed:
Testbench files changed:
Interface/cycle contract:
Numeric-width decisions:
Pipeline latency and II:
Static review result:
Tests or simulators actually run:
Known limitations:
Vivado evidence: not produced by this skill unless fpga-vivado was also used
```

