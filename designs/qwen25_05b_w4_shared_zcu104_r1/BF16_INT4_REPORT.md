# Native BF16×INT4 GEMM — 2026-10-07

Historical native N8 implementation. User subsequently selected N16; fresh N16 evidence is in GEMM_N16_REPORT.md. This N8 report is preserved with its original source/timing/resource scope.

W4 GEMM은 BF16 activation과 signed INT4 code를 직접 곱한다. FP32 weight/activation operand 변환과 generic24×24-bit 가수 곱셈을 제거했다. BF16의8-bit 유효숫자와 INT4의3-bit 크기를 계산하고 부호와 지수를 별도로 처리한다. QK/PV는 BF16×BF16이므로8×8-bit 유효숫자 곱셈을 수행한다. 한 mode-selected8×8 DSP multiplier를 공유하며 W4 mode에서는 두 번째 입력의 상위 bit를0으로 제한한다. INT4−8은 기존대로 invalid다.

최대 유효 product는 W4에서11bits, BF16×BF16에서16bits로 FP32 가수에 정확히 들어간다. FP32 product output을 기존 adjacent tree16·K16 sequential accumulation·group128 scale에 전달한다. **곱셈 결과를 BF16으로 반올림하지 않으며 누산과 scale은 FP32**다. FTZ/signed zero/nonfinite/overflow/error 규칙, FP32 RNE/연산 순서, 최종 별도 BF16 CAST는 유지한다.

ISA·bank23·native128 read3·M1/N8/K16·200MHz와 PS/PL 책임 경계도 유지한다. 실제 원시 INT4/BF16 operand만 GEMM dot 포트에 전달한다. Pipeline은6stage를 유지해 명령 사이클은 이전 N8과 같다: W4 M1/N128/K128 ACCUM7395cycles(36.975us@200MHz,0.443GMAC/s), QK L1024 56960cycles, PV L1024 56360cycles. 이는 module simulation의 환산이며 실물 DDR/PS overhead를 포함한 처리량은 아니다. 이번 변경은 자원 절감을 우선 검증한 것으로 처리량 향상을 주장하지 않는다.

검증:

- [Native product XSIM](evidence/bf16_product_xsim_run002/simulation.log): BF16 전체65536패턴×INT4 전체16코드=1048576 products, BF16×BF16 추가131072 products 모두 scalar FP32 reference와 exact. Reserved−8, nonfinite, signed zero, subnormal/FTZ, overflow 포함. Streaming ID/backpressure/reset flush PASS.
- [GEMM XSIM](evidence/bf16_int4_gemm_xsim_run001/simulation.log): 기존10golden case의 모든 physical payload word exact. M1/2/16,W4 INIT/ACCUM,QK N2/17/1024,PV K2/17/1024,shape/route/numeric errors,upper-half faults,backpressure/reset/refill PASS.
- [Actual XPM integration](evidence/bf16_int4_board_shell_xsim_run001/simulation.log): common DMA/adapters,3872golden beats,1024commands/PC1023 END,chunk state retention/CSR/coordinated reset PASS. Vendor AXI/DDR model이며 전체24layer RTL/보드 실행 증거는 아니다.
- [Module200MHz OOC](evidence/bf16_int4_gemm_200mhz_ooc_run001/summary.json) PASS: setup+0.300ns,hold+0.030ns,pulse-width+1.968ns,실패 endpoint0,DRC error0. Vivado2025.2,xczu7ev-ffvc1156-2-e,5ns,input delay min0.300/max1.000ns. [Timing](evidence/bf16_int4_gemm_200mhz_ooc_run001/timing_summary.rpt),[utilization](evidence/bf16_int4_gemm_200mhz_ooc_run001/utilization.rpt),[routed DCP](evidence/bf16_int4_gemm_200mhz_ooc_run001/routed.dcp). DSP pipeline/OOC no-load 경고는 원본 DRC 보고서에 보존했다.

| GEMM module 자원 | 이전 generic FP32 N8 | Native BF16/INT4 N8 | 절감 |
|---|---:|---:|---:|
| LUT | 104716 | 62528 | 40.3% |
| FF | 87614 | 58131 | 33.7% |
| DSP | 275 | 147 | 46.5% |
| BRAM / URAM | 0 / 0 | 0 / 0 | 동일 |

외부 bank fabric을 제외한 module 단독 자원이며 전체-board 자원으로 합산해 추정한 PASS를 주장하지 않는다.
- [Source identity](evidence/bf16_int4_source_identity_run001.json): scalar/GEMM/integration/OOC는 별도 source snapshots와 SHA를 보존한다. 현재 GEMM/dot/native-product RTL과 해당 GEMM/integration/OOC source가 일치한다.

실패한 초기 검사도 보존한다: Iverilog run001에서는 ID output이X로 관찰됐고 PASS로 집계하지 않는다. Native XSIM run001은 timescale 옵션 누락으로 elaborate 실패했고 run002에서 명시해 통과했다. 동작 증거는 XSIM run002와 exact command golden이다.

이전 generic-FP32 N8 자원은 LUT104716/FF87614/DSP275/BRAM0/URAM0이며 해당 timing PASS를 현재 native source의 증거로 쓰지 않는다. 기존 board007/host SD003/reset patch001은 공급 개선 전 N4 compute RTL이다. Native BF16×INT4 전체-board route/BIT/XSA/firmware/host package와 실물 실행은 미검증이다. 기존 모델 양자화 품질·긴 context 검증의 실패/제한도 유지한다.

저장소 root에서 새 output directory로 재현:

```sh
python3 designs/qwen25_05b_w4_shared_zcu104_r1/scripts/run_bf16_product_xsim.py /tmp/qwen_native_product_recheck
python3 designs/qwen25_05b_w4_shared_zcu104_r1/scripts/run_executor_xsim.py gemm /tmp/qwen_native_gemm_recheck
python3 designs/qwen25_05b_w4_shared_zcu104_r1/scripts/run_core_xsim.py /tmp/qwen_native_integration_recheck --board
python3 designs/qwen25_05b_w4_shared_zcu104_r1/scripts/run_ooc.py qwen_gemm_executor /tmp/qwen_native_ooc_recheck
```
