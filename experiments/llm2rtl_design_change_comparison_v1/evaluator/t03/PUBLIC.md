# T03 acceptance criteria

Change only dense GEMM command row-count representation: opcode 3 payload bits [24:19] and opcode 12 GEMM_TILES payload bits [46:41] encode logical M_count minus one. Logical M_count remains 1..32. Raw 0..31 is valid, raw 32..63 must be rejected before output writes, and m_start + logical M_count must not exceed 32. All other fields and non-dense command formats retain their current meaning.

The evaluated candidate must contain matched PS C generation, Python encoding/decoding and semantic execution, dispatcher validation/descriptor expansion, wide GEMM executor validation/decoding, and documentation declaring the changed command ABI. No automatic rejection of old ambiguous binary fields is required without a separate version mechanism.

Public evaluation checks logical M_count 1,2,8,16,31,32; exact wire records and semantic roundtrips; direct and descriptor-generated commands; rejection of invalid raw values and row bounds; 30-layer PS/Python program construction; unchanged RMS/ROPE/attention/ADD/SILU count formats; exact dense BF16 diagnostic outputs and untouched banks; legal multiple command chunks; and completion count, tag, banks, error and backpressure. Independent tests compile and execute the changed C/Python/RTL source. Candidate test success reports do not constitute evaluator evidence.

Common full-model numerical, affected attention-mode regression, integration, ABI/manifest review and synthesis gates also apply. Board deployment is a separate endpoint. The participant completes the trial independently after the initial brief; the evaluator does not supply corrective hints during the trial.
