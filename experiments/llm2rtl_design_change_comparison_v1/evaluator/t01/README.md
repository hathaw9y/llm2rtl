T01 evaluator assets

Preparation status: original shared wide RTL is frozen as baseline.sv; manifest.json records SHA256 for all evaluator assets after the baseline recording run. Functional checks do not require eight physical rows, so the original 16x16 passes. The optional structural check evaluates eight rows separately.

Run from the study repository with Vivado 2025.2 commands on PATH:

    python3 experiments/llm2rtl_design_change_comparison_v1/scripts/t01_evaluate.py --candidate-root /path/to/candidate/repo --out /path/to/run --suite public
    python3 experiments/llm2rtl_design_change_comparison_v1/scripts/t01_evaluate.py --candidate-root /path/to/candidate/repo --out /path/to/run --suite all --structural

The evaluator always loads this repository's testbench and frozen fixtures. Candidate test changes are ignored. public and hidden are separate suites; hidden files and detailed failures belong only to evaluator preparation/results storage. Do not copy hidden, baseline.sv, manifest.json or the recording mode into participant workspaces. A public standalone package can contain public/, tb_t01.sv, manifest.json and the runner, preserving the scripts/ and evaluator/t01/ directory structure. Public execution hashes only public fixtures and the testbench; it does not need hidden assets. Authoritative scoring executes the frozen evaluator under controlled access. The full evaluator repository must remain outside participant write access. Hash checks detect content changes against the frozen manifest; a writable manifest cannot enforce immutability.

Each suite has 32 cases. Dense covers M=1,7,8,9,16,17,31,32, N=1,7,16,17,191,192, K=16,64,576,1536 and odd K=33, nonzero activation M starts, output N starts 3 and 7, unequal signs/scales/mantissas and subnormal/zero operands. All selected shapes respect real bank capacities. In particular M32/K576 fits the 2304-word activation bank; M32/K1536 is deliberately excluded.

Both attention modes cover rows 8,9,17,32 and one-row cached decode at query32/KV33 and query192/KV193. Fixtures contain distinct head/channel values, covering 9 query heads and grouping into 3 KV heads. Score output includes causal and padding masks in the captured bank; VALUE exercises K tails, transposed V staging, and all 576 channels. It uses synthetic probability input and is not a softmax integration test.

The bank model injects independent periodic ready stalls on activation, weights and destination plus three-cycle read latency. Each completion is held for four cycles and checked for error, tag, bank count and complete bank identity. Destination byte strobes must preserve complete BF16 lanes; every word of the destination bank, including untouched bytes, must match the original. The accepted BF16 element count must match the semantic output shape. Invalid dense M33 and invalid attention query+rows return errors without writes.

Golden outputs are recorded by the original RTL, rather than approximated by float GEMM. This preserves exact K arithmetic order, alignment truncation and BF16 output rounding. --record-baseline is evaluator preparation only and requires the input RTL SHA256 to match baseline.sv. The baseline itself is the equivalence reference; this does not independently prove numerical accuracy against a model reference.

--structural invokes OOC synthesis of the shared executor with hierarchy retained, records utilization/timing, and requires precisely 128 instantiated smollm2_bf16_wide_pe cells at coordinates rows0..7/cols0..15. An alternate naming scheme is reported as unverified and needs evaluator review. Board-wide extra arrays, top-level integration, constrained timing acceptance, full-model lowering, full board synthesis and physical hardware are separate required checks. This runner does not establish those endpoints or baseline model quality. Timing reports are evidence only, not automatically scored by this runner.

Baseline validation evidence is reported in baseline_validation.json and the baseline run logs retained by the evaluator. No comparison participant was run during test preparation.
