# GEMM N8 확대 결과 — 2026-10-07

Historical N8 generic-FP32 product implementation. Current source uses native BF16×INT4/BF16×BF16 products; see BF16_INT4_REPORT.md for its separate evidence. Timing/resources below apply only to this preserved earlier source.

공유 GEMM의 내부 계산 단위를 M1×N4×K16에서 **M1×N8×K16**으로 확대했다. 동시에 계산하는 FP32 product는64→128개다. 명령 타일 M≤16/N128/K128, ISA,23개 bank와 용량, native128 read3,200MHz는 유지한다. 행은 순차 처리하고 dot은 하나씩 완료를 기다린다. PS의 tensor 연산은 추가하지 않았다.

W4 packed cache64→128B; BF16 ACT256B와 selected ACT32B는 유지한다. QK는8개 출력 row를 읽으며 PV는 native128 word의8개 BF16 lane을 모두 사용한다. Scale/이전 누산값은128-bit word2개를 읽고 결과도2개 word로 쓴다. 짧은 QK 출력은 필요한 word만 쓰고 나머지 score padding은 INIT clear로0을 유지한다. 각 출력의 tree16, K16 순차 누산, group128 scale·FP32 RNE/FTZ·BF16 경계는 동일하다.

| 연산 | 공급 개선 N4(cycles) | N8(cycles) | 향상 | N8 시간 @200MHz |
|---|---:|---:|---:|---:|
| W4 M1/N128/K128 ACCUM | 12947 | 7395 | 1.751배 | 36.975us |
| W4 M16/N128/K128 INIT | 205616 | 116784 | 1.761배 | 583.920us |
| QK M1/N1024/K64 | 80640 | 56960 | 1.416배 | 284.800us |
| PV M1/N64/K1024 | 112688 | 56360 | 1.999배 | 281.800us |
| 짧은 QK M2/N2/K64 | 1028 | 1060 | 0.970배 | 5.300us |

W4 ACCUM 처리량은0.253→0.443GMAC/s. 시뮬레이션 command 응답까지의 사이클을200MHz로 환산한 값이며 DDR 이동·PS 제어를 포함한 실물/모델 처리량이 아니다. 짧은 QK에서는 추가된 빈 lane skip으로32cycles 증가한다. 전체10case 값은 [comparison](evidence/gemm_n8_comparison_run001.json).

| GEMM module OOC 자원 | 공급 개선 N4 | N8 | 증분 |
|---|---:|---:|---:|
| LUT | 52993 | 104716 | +51723 |
| FF | 44274 | 87614 | +43340 |
| DSP | 139 | 275 | +136 |
| BRAM / URAM | 0 / 0 | 0 / 0 | 0 / 0 |

Private cache는 LUT/register로 구현되며 위 자원은 GEMM 모듈만의 값이다. 외부 bank fabric과 전체 board 자원을 포함하지 않는다. N8 GEMM 단독 LUT는xczu7ev 가용230400개의45.45%다. 전체 시스템의 자원·혼잡·타이밍은 새 전체-board route로 확인해야 한다.

검증 결과:

- Golden/프로토콜: [gemm_n8_xsim_run003](evidence/gemm_n8_xsim_run003/simulation.log) PASS. W4 INIT/ACCUM M1/2/16, QK N2/17/1024, PV K2/17/1024 등10case의 모든 payload word 일치. Invalid shape/route/nonfinite/W4−8/scale/이전 누산값, 완료 ID·backpressure, reset/refill 검사. 추가된 상위4개 lane의 W4/scale/이전 누산값 오류와 upper burst 중 reset도 검증했다.
- 통합: [gemm_n8_board_shell_xsim_run001](evidence/gemm_n8_board_shell_xsim_run001/simulation.log) PASS. 실제 common XPM bank·DMA/adapters,3872golden beats,1024commands/PC1023 END, chunk 상태 유지, CSR와 coordinated reset. Vendor AXI/DDR는 모델이며 전체24layer RTL/보드 실행 증거가 아니다.
- 합성·배치배선: [gemm_n8_200mhz_ooc_run001](evidence/gemm_n8_200mhz_ooc_run001/summary.json) PASS. Vivado2025.2,xczu7ev-ffvc1156-2-e,5ns,input delay min0.300/max1.000ns. Setup+0.145ns,hold+0.039ns,pulse-width+1.968ns; 실패 endpoint0,DRC error0. DSP pipeline 관련 경고와 OOC no-load 경고는 원본 DRC 보고서에 보존했다. [Timing](evidence/gemm_n8_200mhz_ooc_run001/timing_summary.rpt),[utilization](evidence/gemm_n8_200mhz_ooc_run001/utilization.rpt),[routed DCP](evidence/gemm_n8_200mhz_ooc_run001/routed.dcp).
- 소스 동일성: [identity](evidence/gemm_n8_source_identity_run001.json). 검증·통합·OOC의 GEMM/dot RTL 해시가 현재 소스와 동일하다. OOC snapshot의 이전 output_lanes4 profile 메타데이터는 원본 그대로 보존했으며 실제 합성 RTL은OUTPUTS8이다. 해당 필드는 OOC Tcl에 사용되지 않는다. Part/clock/read3는 동일하다.

보강 테스트 run002는 INIT의 정상 초기화 write까지 오류 결과 write로 세어 실패했다. run003은 ACCUM으로 검사 조건을 수정했고 통과했다. 실패 로그·소스도 보존한다.

새 N8 전체-board BIT/HWH/XSA/host package와 실물 실행은 미검증이다. 기존 board007/host SD003/reset patch001은 이전 N4 compute RTL이다. 기존 양자화 품질·긴 context 검증의 실패/제한도 그대로 남아 있다. 전체 모델 가속 완료를 주장하지 않는다.

저장소 root에서 재현(새 output directory 사용):

```sh
python3 designs/qwen25_05b_w4_shared_zcu104_r1/scripts/run_executor_xsim.py gemm /tmp/qwen_n8_recheck_gemm
python3 designs/qwen25_05b_w4_shared_zcu104_r1/scripts/run_core_xsim.py /tmp/qwen_n8_recheck_integration --board
python3 designs/qwen25_05b_w4_shared_zcu104_r1/scripts/run_ooc.py qwen_gemm_executor /tmp/qwen_n8_recheck_ooc
```
