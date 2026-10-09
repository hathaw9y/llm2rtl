# SmolLM2-135M BF16 RoPE executor

This stage implements ISA opcode 5 for in-place Q (B4) or K (B5) rotation,
using the coefficient window in B7. The command payload's low six bits contain
the number of rows, 1..32; all remaining payload bits are zero. Q has nine
64-wide heads per row, K has three. Each B7 row holds 32 BF16 cos values
followed by 32 BF16 sin values. The table is generated offline and DMA-loaded;
the PS does not calculate Q/K RoPE during inference.

The executor reads both half-head words before writing either word. It rounds
each BF16 multiply to nearest-even and then rounds each BF16 add to
nearest-even, matching the installed Transformers eager operation order.
It rejects nonfinite operands and malformed commands. Subnormal outputs are
flushed to signed zero. A sweep over all 30 layers in the selected
prefill32/decode1 trace found no nonfinite or subnormal Q/K or coefficient
inputs or outputs.

Run the local checks from the repository root:

```sh
/home/shmin/.conda/envs/shmin/bin/python designs/smollm2_135m_bf16_zcu104_r1/scripts/generate_rope_checkpoint_vectors.py
bash designs/smollm2_135m_bf16_zcu104_r1/scripts/run_rope_golden.sh
vivado -mode batch -source designs/smollm2_135m_bf16_zcu104_r1/scripts/run_rope_ooc.tcl
python3 designs/smollm2_135m_bf16_zcu104_r1/scripts/verify_rope_module.py
```

Standalone RTL matches 49,920 first-layer Q/K BF16 outputs exactly for
prefill positions 0..31, decode position 32, and the 1024-token boundary
positions 992..1023. Four malformed-command/data tests pass. ZCU104 150 MHz
out-of-context synthesis meets timing with setup WNS +1.235 ns, 3,073 LUTs,
1,140 FFs and zero DSPs. The RoPE-enabled common fabric elaborates, and the
existing RMSNorm+GEMM and dispatcher XSIM regressions pass.

This evidence covers the executor and source-level fabric integration. A new
BIT/ELF pair, routed timing and physical ZCU104 test for RoPE are still
pending. The previous board PASS belongs to the older RMSNorm+GEMM package.
