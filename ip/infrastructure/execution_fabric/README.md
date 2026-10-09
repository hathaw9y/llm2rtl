# execution_fabric v1

Structural integration of the frozen sparse ISA dispatcher, DataMover engine,
three fixed-bank MM2S adapters, one bank-3 S2MM adapter, and the XPM-backed
sparse bank subsystem. Vendor DataMover AXI-Stream and GEMM control/memory
interfaces remain external boundaries.

The fabric uses bank identity only for dispatcher ownership and completion;
DataMover sequence tags are exposed as diagnostics and never release banks.
MM2S grants are limited to owner-1 banks 0..2 and S2MM to owner-2 bank 3.

Run `scripts/run_xsim.sh`, `scripts/run_lint.sh`, and `scripts/run_ooc.sh`.
These prove bounded integration simulation/lint/synthesized-OOC behavior, not
vendor DataMover IP, GEMM arithmetic, routed timing, board integration, or a
bitstream.
