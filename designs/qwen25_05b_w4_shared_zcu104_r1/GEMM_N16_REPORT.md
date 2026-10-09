# Native GEMM N16 확대 — 2026-10-07

사용자 선택으로 내부 계산 폭을 **M1×N8×K16→M1×N16×K16**, 동시에 곱하는 native products128→256개로 확대했다. W4는 BF16×signed INT4, QK/PV는 BF16×BF16이다. Product는 정확한 FP32로 전달하고 FP32 adjacent tree16·순차 K16/group 누산·scale과 최종 별도 BF16 CAST를 유지한다. 행과 dot은 하나씩 완료를 기다린다. PS tensor 연산을 추가하지 않았다.

W4 명령 타일 M≤16/N128/K128, 다른 mode의 지원 shape, ISA, bank23 용량과 layout/native128 read3,200MHz는 유지한다. ACT private cache256B,selected ACT32B 유지; packed W4 cache128→256B. Weight burst/tag/output lane 카운터를16개 출력에 맞게 확장했다. Scale/이전 누산값·결과는 native128 word4개로 전달한다. QK tail은 필요한 word만 쓰고 score padding은0으로 유지한다. PV는 key당 native128 BF16 word2개를 읽어16개 출력을 공급한다.

| 연산 | Native N8 cycles | N16 cycles | 향상 | N16 시간 @200MHz |
|---|---:|---:|---:|---:|
| W4 M1/N128/K128 ACCUM | 7395 | 4619 | 1.601배 | 23.095us |
| W4 M16/N128/K128 INIT | 116784 | 72368 | 1.614배 | 361.840us |
| QK M1/N1024/K64 | 56960 | 45120 | 1.262배 | 225.600us |
| PV M1/N64/K1024 | 56360 | 44580 | 1.264배 | 222.900us |
| QK M2/N2/K64 short tail | 1060 | 1124 | 0.943배 | 5.620us |

W4 ACCUM0.443→0.709GMAC/s. QK/PV의 WGT 읽기는 최대 shape에서8192words로 그대로여서 속도가2배가 되지는 않는다. 짧은 QK N2는 추가 빈 lane skip으로64cycles 증가한다. 시뮬레이션 command 응답 사이클을200MHz로 환산한 값이며 DDR 이동·PS 제어를 포함한 실물/전체 모델 처리량은 아니다. 전체10case 값은 [comparison](evidence/native_n16_comparison_run001.json).

검증:

- 기본 [GEMM XSIM run001](evidence/native_n16_gemm_xsim_run001/simulation.log): 모든10golden case physical word exact. W4 M1/2/16 INIT/ACCUM,QK N2/17/1024,PV K2/17/1024,shape/route/numeric errors,response ID/backpressure,reset/burst refill PASS. 네 번째 output word의 W4/scale/이전 누산값 오류와16word burst의14번째 발행 후 reset/replay를 포함한다.
- [보강 XSIM run002](evidence/native_n16_gemm_xsim_run002/simulation.log): 기존10case/error/reset/backpressure 재검증 및 QK N5/9/13의 부분 출력 word2/3/4와 padded rows, PV 두 번째 native word의 nonfinite 검사 PASS.
- [Actual common XPM/common-DMA integration run001](evidence/native_n16_board_shell_xsim_run001/simulation.log):3872golden beats,1024commands/PC1023 END,retained descriptors,chunk restart/CSR/coordinated reset PASS. Bounded packets/vendor AXI·DDR model이며 전체24layer/보드 실행 증거가 아니다.
- [새 module200MHz OOC](evidence/native_n16_gemm_200mhz_ooc_run001/summary.json) PASS: setup+0.079ns,hold+0.030ns,pulse-width+1.968ns,실패 endpoint0,DRC error0. Vivado2025.2,xczu7ev-ffvc1156-2-e,5ns,input delay min0.300/max1.000ns. [Timing](evidence/native_n16_gemm_200mhz_ooc_run001/timing_summary.rpt),[utilization](evidence/native_n16_gemm_200mhz_ooc_run001/utilization.rpt),[routed DCP](evidence/native_n16_gemm_200mhz_ooc_run001/routed.dcp). DSP pipeline/OOC no-load 경고는 원본 DRC 보고서에 보존했다. 기존 N8 PASS를 N16 증거로 사용하지 않는다.

| GEMM module 자원 | Native N8 | Native N16 | 증분 |
|---|---:|---:|---:|
| LUT | 62528 | 122873 | +60345 |
| FF | 58131 | 115532 | +57401 |
| DSP | 147 | 292 | +145 |
| BRAM / URAM | 0 / 0 | 0 / 0 | 0 / 0 |

N16 GEMM 단독 LUT는 부품 가용230400개의53.33%,DSP는1728개의16.90%다. 외부 bank fabric·나머지 executor·PS/PL wrapper는 포함하지 않는다. Setup margin79ps인 모듈 결과만으로 새 전체-board timing을 보장할 수 없으며 합산 추정 PASS도 주장하지 않는다.
- [Source identity](evidence/native_n16_source_identity_run001.json): current GEMM/dot/native-product source가 보강 golden·통합·OOC snapshots와 일치한다. Native scalar leaf 자체는 변하지 않아 동일SHA의1048576 BF16×INT4/131072 BF16×BF16 전수/추가 검증이 적용된다. N16 instantiation/제어/연결은 새 테스트로 확인한다.

전체-board N16 run009 route/BIT/HWH/XSA 및 별도 audit003 PASS: setup+0.002ns/hold+0.010ns/PW+1.000ns,실패 endpoint0·DRC error0·unrouted nets0. 전체 자원 LUT185248/FF151792/DSP314/BRAM85.5/URAM10. 최초 run008의 setup−0.029ns 실패를 보존하고 RTL·수치·ISA·bank·200MHz를 바꾸지 않은 post-route physical optimization으로 closure했다. setup2ps 여유는 매우 작다. Matching SD BSP005/ELF008/host SD005/N16 patch002와 실제 archive·patch 검증을 완료했다. 상세는 [전체 implementation](IMPLEMENTATION_N16_REPORT.md). 실물 실행은 미검증이다. 기존 board007/host SD003/reset patch001은 공급 개선 전 N4 compute RTL이다. 기존 W4 모델 품질·긴 context 검증의 실패/제한은 유지하며 전체 모델 가속 완료를 주장하지 않는다.

재현(저장소 root, 새 output directory):

```sh
python3 designs/qwen25_05b_w4_shared_zcu104_r1/scripts/run_executor_xsim.py gemm /tmp/qwen_n16_golden_recheck
python3 designs/qwen25_05b_w4_shared_zcu104_r1/scripts/run_core_xsim.py /tmp/qwen_n16_integration_recheck --board
python3 designs/qwen25_05b_w4_shared_zcu104_r1/scripts/run_ooc.py qwen_gemm_executor /tmp/qwen_n16_ooc_recheck
```
