# Ping-Pong Contracts

## Bank ownership

Represent each bank with an explicit state: `FREE`, `FILLING`, `READY`, `ACTIVE`, `DRAINING`, or `FAULT`.

- The mover may write only `FREE` or its own `FILLING` bank.
- Compute may read only the single `ACTIVE` bank.
- Publish `READY` only after the final accepted write and all transport status is successful.
- Transfer `READY -> ACTIVE` atomically at a scheduler barrier.
- Release `ACTIVE -> FREE` only after the final accepted compute read.
- On fault, cancel outstanding work, quarantine the affected bank, preserve the other bank, and support retry without global reset.
- Reject a bank transition whose epoch, tile ID, byte count, or owner does not match.

## Address and stream fields

Freeze these per tensor before RTL work:

- Base address, tile stride, row stride, byte count, burst limits, alignment, and legal address interval.
- Element order and packed-nibble order for sub-byte data.
- `TKEEP` for every beat, especially the tail.
- `TLAST` on exactly the final accepted beat of the declared tile; never derive it from idle cycles.
- Stable `TDATA`, `TKEEP`, `TLAST`, tile ID, and error metadata while `TVALID && !TREADY`.
- Counters and ownership advance only on accepted handshakes.

For memory-mapped paths, prove no arithmetic wraparound and no read or write outside the declared interval. For split status/data channels, wait for both endpoint completion and transport status before publishing a bank.

## Scheduling and prefetch

Assign monotonically increasing tile epochs. Prefetch tile `i + d` while computing tile `i`, where `d` is the validated prefetch distance. Enforce both steady-state bandwidth and latency-distance inequalities. Include turnaround, arbitration, and measured contention in sustained bandwidth.

Assume one serial outstanding transfer unless the contract proves otherwise. Under that default, charge command/fixed latency plus payload time to every tile's service interval; additional prefetch distance does not improve the serial service rate. To claim latency overlap, freeze the maximum outstanding count, request IDs or ordering rule, response/status association, bank capacity for the lookahead, and measured service interval under the intended contention. Reject a payload-only model when any of these are missing.

## Tail, fault, and retry tests

Test zero/invalid requests, one element, one beat, non-aligned tails, maximum tile, final short tile, held start, randomized backpressure, mover error before/mid/after payload, compute error, cancellation during fill and drain, stale completion, duplicate completion, retry on the same bank, and retry on the alternate bank. Snapshot protected DDR regions to prove invalid requests are no-touch.
