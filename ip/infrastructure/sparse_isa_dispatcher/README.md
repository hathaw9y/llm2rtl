# sparse_isa_dispatcher

Production dispatcher for the frozen sparse-bank inventory. It implements END, MM2S,
S2MM and GEMM opcode routing with strict current-PC issue. MM2S is limited to banks
0/1/2, S2MM to bank 3, and GEMM to ACT/WGT/OUT banks 1/2/3 with ownership roles
3/4/5. Unsupported capability is rejected before request-valid or bank acquire.

MM2S and S2MM reject any command with `local_offset[31:23] != 0` before
request-valid or ownership acquire, so the 32-bit ISA field cannot be silently
truncated at the 23-bit DataMover Engine boundary.

DMA response effects occur only on `valid && ready`. Status code `00` is
success. Descriptor errors `01..06` retire the matching pending command and
release its bank before entering dispatcher error drain. Transport/recovery
faults `10`, `20`, `30`, `40`, and `50` retain both pending state and ownership,
emit no release pulse, and require coordinated reset. Unknown or inconsistent
error/code combinations fail closed with the same retention policy. The
existing response tag remains the completion bank identity.

GEMM shape is decoded from `local_offset[31:3]`. Compute receives bank identity,
not a raw address: GEMM requires the instruction `axi_address` field to be zero,
keeps the compatibility `m_ctrl_sa_out_base_addr` port tied to zero, and uses
native word zero of the output bank as its implicit base.

This module does not instantiate executors, data-bank memories, an ownership table,
AXI BRAM Controller, board wrapper, or bitstream.
