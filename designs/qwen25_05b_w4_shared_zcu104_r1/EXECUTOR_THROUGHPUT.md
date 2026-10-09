# Executor implementation and throughput at200MHz

Current N16 update verified at module scope: native M1/N16/K16,256 products, WGT cache256B, four result words, two BF16 PV input words per key. ISA/banks/read3/200MHz/numeric order unchanged. W4 M1 ACCUM4619cycles vs N8 7395; Enhanced golden/tail/error/reset/backpressure and actual-XPM integration PASS. Module200MHz OOC PASS setup+0.079ns/hold+0.030ns/PW+1.968ns,0failed endpoints; LUT122873/FF115532/DSP292/BRAM0/URAM0. QK L1024 45120cycles/PV L1024 44580cycles (~1.26x); short QK N2 regresses1060→1124cycles. Fresh N16 full-board run009 route/BIT and separate audit003 PASS: setup+0.002ns/hold+0.010ns/PW+1.000ns,zero failing endpoints; LUT185248/FF151792/DSP314/BRAM85.5/URAM10. Matching SD host005 is prepared. Physical throughput remains unverified. GEMM_N16_REPORT.md records current measured results. Below N8 timing/resources are historical.

Historical native N8 arithmetic update: W4 native BF16×signed INT4, QK/PV native BF16×BF16, exact FP32 products feeding the unchanged FP32 reduction/accumulation/scale. Scalar exhaustive and all10 GEMM golden/protocol cases and actual-XPM integration PASS. Six-stage products retained, so N8 command cycles below are unchanged. Fresh200MHz native OOC PASS: setup+0.300ns/hold+0.030ns/PW+1.968ns,0failed endpoints. LUT62528/FF58131/DSP147/BRAM0/URAM0; previous genericFP32 N8 resource/timing evidence below is historical. No current full-board route/BIT or physical performance proof. See BF16_INT4_REPORT.md.

Historical generic N8 experiment: internal M1/N8/K16 (128 products), command M≤16/N128/K128 unchanged. BF16 ACT cache256B, packed W4 cache128B and selected ACT32B. Eight independent FP32 outputs retain the prior tree16/group accumulation order; results occupy two native128 words. No bank capacity or ISA change, and still one dot in flight.

| Work | Supplied N4 cycles | N8 cycles | Speedup | N8 time at200MHz (us) | N8 GMAC/s |
|---|---:|---:|---:|---:|---:|
| W4 M1/N128/K128 ACCUM | 12947 | 7395 | 1.751× | 36.975 | 0.443 |
| W4 M16/N128/K128 INIT | 205616 | 116784 | 1.761× | 583.920 | 0.449 |
| QK M1/N1024/K64 | 80640 | 56960 | 1.416× | 284.800 | 0.230 |
| PV M1/N64/K1024 | 112688 | 56360 | 1.999× | 281.800 | 0.233 |
| QK M2/N2/K64 short tail | 1028 | 1060 | 0.970× | 5.300 | 0.048 |

The short QK tail regresses32cycles because additional unused output lanes still traverse the skip states. It has exact golden payload and padding. These are module simulation measurements converted at200MHz, not observed board or complete-model throughput. All10 golden cases and enhanced upper-half error/reset/backpressure tests PASS in gemm_n8_xsim_run003. Actual-XPM/common-DMA bounded integration PASS in gemm_n8_board_shell_xsim_run001 (3872beats,1024records,END/chunk/reset; vendor AXI/DDR model). Fresh200MHz module OOC PASS: setup+0.145ns/hold+0.039ns/PW+1.968ns; all failing endpoints0. Resource LUT104716/FF87614/DSP275/BRAM0/URAM0 versus supplied N4 LUT52993/FF44274/DSP139. New full-board route/BIT and physical throughput are unverified. Evidence: gemm_n8_200mhz_ooc_run001. Source identities match across these runs. Evidence: gemm_n8_comparison_run001.json and gemm_n8_source_identity_run001.json.

Previous N4 supply update (historical module evidence):  ACT256B per row and WGT64B per K32/output group, tagged consecutive native read3. M1/N128/K128 ACCUM now12947cycles/64.735us/0.253093GMAC/s versus16640cycles/83.2us/0.196923GMAC/s (1.285x). M16 INIT264704→205616cycles. ACT words per row512→16; WGT1024→512. Golden10cases/error/reset/backpressure and actual XPM/common-DMA board-shell integration PASS. Module200MHz OOC setup+0.430ns/hold+0.039ns/PW+1.968ns PASS; LUT+682/FF+293, no DSP/BRAM/URAM increase. QK/PV unchanged. No updated full-board routed timing/BIT or physical throughput claim. Evidence: gemm_supply_comparison_run001.json, gemm_supply_xsim_run001, gemm_supply_board_shell_xsim_run001 and gemm_supply_200mhz_ooc_run001.

The following detailed table and dense estimate record the **pre-supply-optimization baseline**, not current W4 performance.

Compute RTL was unchanged by the board reset fix. The corrected full routed build007 and independent audit002 meet200MHz setup+0.009ns/hold+0.010ns/PW+1.000ns. This report converts module simulation cycles to time at that frequency; it is not a board performance result.

All five executors accept one active command, with cmd_valid/cmd_ready and identified, backpressured completion/error. Native bank reads are128bits with fixed3-cycle latency. Fabric owns routing and byte-masked writes; integrated completion waits for queued writes to drain. END preserves banks/KV and is not a reset.

GEMM: shared projections/QK/PV. One row, four outputs, K16;64 parallel custom FP32 multipliers plus four adjacent16-term trees. W4 codes are converted to FP32 constants and BF16 operands expanded to FP32. Eight dot steps form group128, followed by FP32 scale and output partial-sum accumulation. This is W4 storage with FP32 arithmetic, without integer DSP packing. Four outputs are parallel, rows are serial. Full W4 K16 step takes62 cycles: ACT8 + WGT16 + dot31 + accumulator7. There is no one-dot-per-cycle stream; dot's busy flag and executor FSM wait for the result. QK and PV additionally traverse different BF16 memory layouts.

RMSNorm: sequential square calculation,16-value adjacent reduction using15 serial FP32 additions, block accumulation, mean+epsilon, rsqrt and second pass of normalization/gamma. Only one element advances at a time. BF16 conversion points preserve the numerical contract.

RoPE: one output dimension at a time, read x/rotated-x/cos/sin, two unfused products and one add; BF16 rounding after products and output. Cos/sin rows are precomputed in DDR and loaded to PARAM, with no runtime PS trig. Q14 and K2 heads run as separate commands.

Softmax: three score traversals for scaled causal max, exp sum and normalized probability. exp is recomputed in the third pass.16-term reduction uses serial FP32 arithmetic. exp uses a257-entry exp2 ROM with linear interpolation; reciprocal uses256-entry initialization and two Newton steps. rsqrt in RMS uses256-entry initialization and three Newton steps. FP32 add/multiply cores have six stages, but the executor FSM serializes dependent operations.

Vector: one-element FSM for bias/add, SiLU times up, W4 dequant, FP32-to-BF16 cast and layout insert/extract. Addresses are registered before enables; output collects eight BF16 elements per128-bit word. SiLU uses stable exp(-abs(x)), reciprocal and unfused multiplies with specified BF16 boundaries. Packing eight outputs does not mean eight arithmetic lanes.

| Case | Work | Module cycles | Time at200MHz (us) | Effective work/s |
|---|---:|---:|---:|---:|
| W4 GEMM ACCUM | 16384 MAC | 16640 | 83.200 | 196.923 million MAC/s |
| QK GEMM L1024 | 65536 MAC | 80640 | 403.200 | 162.540 million MAC/s |
| PV GEMM L1024 | 65536 MAC | 112688 | 563.440 | 116.314 million MAC/s |
| RMSNorm H896 | 896 element | 36192 | 180.960 | 4.951 million element/s |
| RoPE Q14 | 896 element | 33264 | 166.320 | 5.387 million element/s |
| RoPE K2 | 128 element | 4752 | 23.760 | 5.387 million element/s |
| Softmax L1024 | 1024 element | 168364 | 841.820 | 1.216 million element/s |
| Vector ADD M2 N896 | 1792 element | 34497 | 172.485 | 10.389 million element/s |
| Vector DEQUANT M2 N896 | 1792 element | 34497 | 172.485 | 10.389 million element/s |
| Vector CAST M2 N64 | 128 element | 929 | 4.645 | 27.557 million element/s |
| Vector LAYOUT M2 N128 | 256 element | 1857 | 9.285 | 27.571 million element/s |
| Vector SILU_MUL M2 N128 | 256 element | 33911 | 169.555 | 1.510 million element/s |

GEMM/Softmax counts come from existing exact-source golden simulations. Fresh RoPE/RMSNorm/Vector runs added only cycle printing to existing testbenches, retaining all golden/error/backpressure checks. Source hashes and logs are preserved here. Golden paths and numeric datapaths were not changed. Vector cases differ in initialization and values; SiLU latency depends on sign and exp underflow. Quoted rate is the workload average, not a universal constant.

For batch1 decode, dense projections plus full-vocabulary LM head require493,961,216 MAC/token. Counting INIT/ACCUM128x128 command groups gives an analytical dense-GEMM-only estimate of501,337,312 cycles, 2.507s/token at200MHz, or a ceiling near0.399token/s. This excludes QK/PV, all other executors, DDR, ISA refill and PS control. It is not achieved or measured token/s. Prefill rows are also computed serially; there is no M-dimensional array.

Common DataMover uses64-bit streams and128-bit native bank adapters.64bits*200MHz=1.6GB/s is only an interface ceiling in either direction, not measured DDR bandwidth. Current bank/controller wait cycles and external backpressure reduce sustained transfer. PS performs ISA generation/control, file/byte movement and checksums; no model tensor arithmetic.
