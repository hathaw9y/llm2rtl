# GEMM executor implementation contract

This is the next compute module for this design revision. It consumes the
existing 128-bit GEMM command through compute channel 0. The dispatcher owns
the PC, tensor validity and bank locks; GEMM owns the arithmetic and local
bank addresses. No PS tensor calculation is involved.

## Command and bank data

The accepted command supplies activation bank `bank[0]`, weight bank
`bank[1]`, destination bank `bank[2]`, and the existing payload fields:
`n_start[62:47]`, `n_total[46:31]`, `m_start[30:25]`, `m_count[24:19]`,
`k[18:8]`, `n_tile[7:0]`. This module must reject zero dimensions,
`m_start + m_count > 32`, `n_start + n_tile > n_total`, and any address beyond
the selected bank's physical capacity before issuing a bank access.

Each 128-bit local word contains eight little-endian BF16 elements. The
activation tensor is row-major `[M,K]`; the loaded weight tile is row-major
`[n_tile,K]`, where weight row 0 represents logical output column `n_start`.
The destination is row-major `[m_count,n_total]`. For local output row `r`,
column `n_start+c`, the output element index is `r*n_total+n_start+c`.
The activation element index is `(m_start+r)*k+t`; the weight element index
is `c*k+t`. The word address is element index divided by eight, and the lane
is the remainder. A destination element write uses the corresponding two
byte strobes. `n_start` changes the destination offset; it does not cause
partial-sum accumulation with the previous GEMM command.

The executor uses role 3 to read the activation bank, role 4 to read the
weight bank, and role 5 to write the destination bank. It may issue a read
only when the role's `read_ready` is high, and it must pair responses by
the accepted command and requested element position. A write must remain
stable until `write_ready`. The existing router supplies three-cycle bank
read responses.

## Arithmetic and completion

The first RTL is a scalar functional baseline: it multiplies BF16 operands
exactly, processes K in ascending order, and accumulates in a signed 64-bit
mantissa with a shared binary exponent. Each new product contributes a
16-bit exact significand followed by 32 guard bits. The shared exponent
tracks the largest product scale seen so far; alignment right shifts
truncate magnitudes toward zero. The final result rounds to BF16 using
round to nearest, ties to even. BF16 zero and subnormal inputs are accepted;
NaN and infinity inputs return an executor error before the next output
write. Finite overflow produces BF16 infinity. This rule is deterministic
but differs from the earlier Python candidate's FP32 `F.linear` reduction.
The existing end-to-end error thresholds remain provisional until this
arithmetic is compared across model prefill and decode traces.

After the **last destination write handshake**, the executor returns
`done_valid`, `done_tag=bank[0]`, `done_bank_count=3`,
`done_bank={bank[0],bank[1],bank[2]}`, and an error bit. These values remain
stable until `done_ready`. The dispatcher verifies the returned bank IDs
against the accepted command and releases those returned IDs only on a
matching completion. A failed matched completion invalidates the destination;
a mismatched response retains all bank locks and requests coherent recovery.

## Verification boundary

The current module test covers exact integer dots, deterministic random
BF16 values compared to an exact-rational golden, odd K crossing a 128-bit
word boundary, nonzero M and N offsets, byte strobes, halfway rounding,
subnormal input, nonfinite-input error, destination backpressure, and held
completion with the returned bank IDs. It also covers a full 32-row by
192-column output tile, `m_start=31,m_count=1` at the final 192 columns of
49,152-wide logits, and a full K=1,536 dot product. Integration through
the XPM bank subsystem, model-wide prefill/decode numerical acceptance, and
board timing remain separate gates. A pinned-checkpoint test additionally
captures layer-0 Q-projection BF16 activation and weight values from a
32-token prefill and one-token decode, then compares the first four output
columns against exact-rational and PyTorch BF16 results. The sampled eight
prefill and four decode outputs match bit-for-bit. This scalar baseline may have high
execution latency; its throughput is not yet a model performance claim.
