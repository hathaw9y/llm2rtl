---
name: fpga-ddr-pingpong-residency
description: Size and verify FPGA on-chip residency, reduced tiles, or DDR ping-pong streaming using packed-byte capacity, measured bandwidth, latency, and overlap constraints. Use when BRAM/URAM pressure is high; weights, quantization scales, activations, KV data, or RoPE tables are resident; DDR streaming or tile buffers are proposed; or buffer duplication, prefetch distance, AXI stream correctness, resource usage, and timing must be compared.
---

# FPGA DDR Ping-Pong Residency

Treat storage policy as a measured architecture decision, not a default optimization.

## Workflow

1. Inventory every tensor and metadata array. Record logical shape, bit width, packing alignment, lifetime, reuse count, producer, consumer, and whether random access is required.
2. Calculate packed bytes before selecting tile dimensions. Run `scripts/capacity_overlap.py --config <json>` and retain its JSON output.
3. Keep roles separate:
   - Compute kernels consume and produce local streams or bank ports.
   - Data movers own DDR addresses, bursts, alignment, retries, and transport errors.
   - The scheduler transfers bank ownership; it must not emulate either datapath.
4. Compare three candidates using measured capacity, sustained bandwidth, transfer latency, compute time, and baseline latency:
   - `resident`: complete working set fits and wins the measured comparison.
   - `reduced`: one-bank tile fits, but duplication or overlap is unsafe or unproven.
   - `pingpong`: two banks fit, sustained bandwidth and prefetch-latency inequalities pass, and predicted latency beats the measured baseline.
5. Specify the two-bank ownership and stream contract from [references/contracts.md](references/contracts.md). Reject designs that can overwrite an active bank or infer packet boundaries from timing.
6. Verify tails, faults, cancellation, retry without reset, held start, backpressure, and invalid-request no-touch behavior.
7. Measure again after implementation. Compare bytes, bandwidth, latency, BRAM/URAM, LUT/FF/DSP, power if available, and timing against the frozen baseline. Revert or reduce the tile when streaming does not win.

## Required inequalities

Use packed bytes including alignment and metadata.

- Capacity: `resident_bytes + 2 * streamed_tile_bytes <= usable_onchip_bytes`.
- Conservative serial-mover steady state: `transfer_latency + streamed_tile_bytes / sustained_bandwidth <= compute_tile_time`.
- Prefetch completion: `transfer_latency + streamed_tile_bytes / sustained_bandwidth <= prefetch_distance * compute_tile_time`.

Treat fixed latency as part of every tile's serial service time by default. Prefetch distance can hide startup latency but cannot repair a serial service rate slower than compute consumption. Use payload-only steady service only when the transport contract and measurements prove multi-outstanding requests overlap fixed latency; record that evidence in `latency_overlap_evidence`.

Predict a two-stage pipeline as `first_transfer_completion + first_compute + (tiles - 1) * max(compute_time, steady_service_time)`. Do not use payload time alone for the cycle unless latency overlap is proven.

Do not substitute peak DDR bandwidth for measured sustained bandwidth. Treat a missing baseline or missing measurement as `measure`, not as approval for ping-pong.

## Evidence gates

Require all of the following before integration approval:

- Calculator input/output and exact packing assumptions.
- Module-level tests for address, stream, bank ownership, tail, backpressure, error, cancel, and retry behavior.
- OOC synthesis showing inferred memories, exact BRAM/URAM counts, and timing at the target clock.
- Integration simulation proving concurrent mover/compute behavior without active-bank overwrite.
- Post-route timing, route, DRC/methodology, clock, and hierarchical utilization evidence.
- Frozen baseline comparison and an explicit decision: resident, reduced, ping-pong, or measure.

Never trade correctness for apparent overlap. Never count inaccessible or reserved device memory as usable capacity.
