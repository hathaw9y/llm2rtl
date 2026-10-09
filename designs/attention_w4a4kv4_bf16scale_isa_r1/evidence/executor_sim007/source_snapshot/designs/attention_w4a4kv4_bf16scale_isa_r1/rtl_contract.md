# Attention tensor ISA RTL wave 1

This is a standalone operator RTL implementation, not board bring-up or a full
model. Existing program v1 artifacts and all old revision evidence are immutable.
Four `contracts/common` identities are pinned in each module packet. Current
`contracts/README.md` minimal project contracts replace the deleted historical
contract CLI/mapping approval machinery in installed skill text.

## Supported hardware profile

Tokens and selected query count: 1..32. Inputs/outputs: 1..256. Heads: 1..4.
Head dimension: 1..64. Total head width: <=256. Group size32. All tensor packing,
scales, mask and operation order match program v1 README. The unchanged verified
MAX256 quantizer child is reused as a row kernel; row boundaries never independently
pad the destination tensor. Arbitrary larger Python programs remain program-only.

A build compiles a chosen `descriptor_table.json` into immutable descriptor/context
ROM using a design-local generator. Changing shapes/query selection requires
regenerating that ROM and revalidating the build. No claim of runtime writable
descriptors or model-scale tiled execution. Default examples are prefill and
last-token. Instruction words themselves are still preloaded by PS into separate
command BRAM before start. Compute receives logical bank IDs and tensor metadata,
not external address/raw-offset command operands.

## Shared descriptor ABI

`attention_tensor_pkg::tensor_desc_t` is a 256-bit packed struct in this MSB-to-LSB
order: `valid`(1), `format`(3), `rank`(2), `reserved`(26), `dim0`, `dim1`, `dim2`,
`data_bytes`, `scale_offset`, `scale_count`, `capacity_bytes` (each32).
Rank2 dim2=1; rank1 dim1=dim2=1. Format codes F32=0, BF16=1, U8=2, I4_ROW=3,
I4_HEAD=4, I4_GROUP32=5. BF16 scale_offset is a byte layout offset within the
selected tensor, not a raw address supplied by a compute command.

## Executor boundary

`attention_tensor_executor` uses synchronous `aclk/aresetn` and one outstanding
command. `cmd_valid/ready`, `cmd_id[15:0]`, `cmd_opcode[7:0]`, `cmd_src0/src1/dst[4:0]`,
`cmd_src0_desc/cmd_src1_desc/cmd_dst_desc[255:0]`; `resp_valid/ready`, `resp_id[15:0]`,
`resp_error`, `resp_error_code[7:0]`. No raw ISA word port bypass.

Immutable context inputs: `ctx_tokens[5:0]`, `ctx_heads[2:0]`,
`ctx_head_dim[6:0]`, `ctx_query_count[5:0]`, `ctx_causal`, `ctx_qk_factor[31:0]`.
Query ROM: executor output `query_lookup_index[4:0]`, input
`query_lookup_value[4:0]`. Context must remain stable throughout a program.

Read role0 ports: `src0_read_valid/ready`, `src0_read_bank[4:0]`,
`src0_read_addr[31:0]` (128-bit word index), `src0_resp_valid`,
`src0_resp_bank[4:0]`, `src0_resp_data[127:0]`.
Read role1 ports use the corresponding `src1_` names. Memory responses are pulses;
engine issues only when it can consume the response, with at most one outstanding
read per role. It explicitly receives each response rather than assuming latency.
Write role ports: `dst_write_valid/ready`, `dst_write_bank[4:0]`,
`dst_write_addr[31:0]`, `dst_write_data[127:0]`, `dst_write_strb[15:0]`.
All request fields stable while stalled. Memory word addresses are generated only
inside the engine from tensor layout. Completion requires every read processed and
every tensor data/scale/padding write accepted. No request after completion.
Destination bank is invalid until successful completion; error never commits it.

## Controller and bank boundary

Design-local `attention_tensor_controller` implements new128-bit program v1 fields;
it does not claim to be a model scheduler. Strict sequential issue/completion,
no overlapping commands, one saved command identity and exact owner role map.
Roles: MM2S1, S2MM2, SRC0=3, SRC1=4, DST=5. Reuse immutable exclusive
`bank_ownership_table`, `bank_port_router`, `bram_bank` where practical. Internal
legacy GEMM router port names are adapters to these generated tensor roles.
Read response valid/role routing is retained. No bank read-pending scoreboard.
Acquisition is atomic on engine request handshake, release only after matching
completion; all roles/free checks and full8-bit instruction bank checks occur
before narrowing to5-bit IDs. Ready-gating illegal commands cannot hide errors.

DMA bank ID is5-bit and is not a4-bit DataMover tag. Current DMA integration
adapter uses32-bit DDR and23-bit byte count; v1 immediate[63:32]!=0, unaligned
address, excessive transfer capacity are rejected before acquisition. Controller
matches DMA status bank/opcode independently of any vendor-internal tag. External
MM2S/S2MM peers terminate at native local memory ports as in prior validation;
new controller/compute tests use BFMs, not a vendor DataMover/PS board claim.

Instruction format/range/alias, expected descriptors/shape relationships,
initialized source banks, reserved fields and END drain are validated.
Command BRAM capacity is bounded and reaching its end without END is an error.
Error response with quiescent memory invalidates destination and halts. An
identity/protocol fault that cannot establish quiescence retains ownership until
coordinated reset. Reset drops in-flight work and invalidates all banks.

## Numerical policy

New ALU must support finite FP32 exact RNE including gradual underflow for unfused
ADD/MUL/DIV and signed integer conversion; nonfinite input/overflow/div0 are errors.
The quantizer alone retains its existing FTZ-input policy. INT4 range[-7,7],
BF16 positive normal scales, INT32 dot/group partials, exact agreed operation order.
BF16 probability storage must retain RNE behavior including subnormals.

Hardware exp uses negative-domain257-entry exp2 interpolation with FP32 range
reduction. x<-80 may flush to0; otherwise relative error<=1e-5, exp0=1.
Softmax follows mathematical program order with this single explicit approximation.
Approximate hardware golden reproduces its exact operation order; separately
compare probabilities against mathematical Attention within one BF16 step
(abs<=0.00390625). No arbitrary end-to-end accuracy or model quality claim.
All-masked rows remain zero without reciprocal/div0. PV remains FP32 math with
BF16 probabilities/dequantized V. Bias/RoPE/GQA/persistentKV cache are excluded.

## Required evidence

Each bounded child: self-checking exact arithmetic/data test, stall/reset/error,
source/contract hashes, strict lint and 5ns OOC utilization/timing (unplaced only).
Integration: decoded command BRAM through MM2S/native banks/real executor/S2MM,
exact comparison against approximation-aware byte golden and separate mathematical
reference error measurement, final completion/release assertions, unsupported
shape/opcode/range/alias/uninitialized/end errors and coordinated reset.
Existing verified child identities are preserved and integration waits for child
implementation plus independent review. Full Attention RTL completion is reported
only after this complete path passes. No board/routed or physical DDR claim.
