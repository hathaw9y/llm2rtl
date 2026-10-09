# Bank port router

`bank_port_router` maps the five fixed module-port roles onto physical local-bank
Port A writes and Port B reads. A request is accepted only when its logical bank
is in range, busy, and owned by that exact module-port role. Invalid requests do
not enable memory and record the first fault until reset.

Read responses have fixed `READ_LATENCY` and no response backpressure. The
router contains no memory, ownership state, DMA arbitration, GEMM arithmetic,
AXI interface, or board-specific logic.
