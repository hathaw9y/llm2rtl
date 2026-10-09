# Qwen shared-GEMM r1 검증 상태


**Native GEMM N16 및 전체 보드 implementation 완료:** 사용자 선택으로 내부 M1×N16×K16(256 products),packed W4 cache256B로 확대했다. BF16×INT4/BF16×BF16,FP32 출력·누산·scale,ISA/bank/read3와200MHz 유지. 새 golden run002(10case,N5/9/13 tail,PV 상위word 오류,ID/reset/backpressure),actual-XPM 통합 run001(3872beats/1024records/END/chunk/reset) PASS. 새 OOC200MHz setup+0.079ns/hold+0.030ns/PW+1.968ns,실패 endpoint0; LUT122873/FF115532/DSP292/BRAM0/URAM0. W4 ACCUM7395→4619cycles(1.601배),0.443→0.709GMAC/s; QK/PV L1024 약1.26배,짧은 QK N2는1060→1124cycles. **새 전체-board run009의200MHz route/BIT 및 별도 audit003도 PASS**: setup+0.002ns/hold+0.010ns/PW+1.000ns,실패 endpoint0·DRC error0·unrouted/error nets0; LUT185248/FF151792/DSP314/BRAM85.5/URAM10. Matching SD ELF008/host SD005/N16 patch002 준비·검증 완료. setup 여유2ps는 매우 작으며 실물 성능은 미검증이다. 상세: GEMM_N16_REPORT.md. 아래 N8의 PASS·자원·타이밍은 이전 source 범위다.

**이전 Native N8 곱셈 전환(모듈 범위):** W4는 BF16×signed INT4, QK/PV는 BF16×BF16을 직접 계산한다. FP32 product output·reduction·누산·scale·최종 BF16 CAST·N8 및 ISA/bank 유지. Native 전수1048576개/BF16×BF16추가131072개 곱셈, GEMM10golden·오류/reset/backpressure,actual-XPM/common-DMA 통합 모두 PASS. 새 OOC200MHz setup+0.300ns/hold+0.030ns/PW+1.968ns,실패 endpoint0. LUT62528/FF58131/DSP147/BRAM0/URAM0(이전 N8 대비LUT40.3%/FF33.7%/DSP46.5% 절감). 명령 사이클은 이전 N8과 동일. **새 전체-board BIT·타이밍·실물 성능은 미검증**이다. 상세: BF16_INT4_REPORT.md. 아래 generic-FP32 N8/N4 결과는 이전 구현의 증거다.

**이전 generic-FP32 GEMM N8 확대(모듈 범위):** 내부 M1×N8×K16(128 products), WGT cache128B. 명령 타일 M≤16/N128/K128·ISA·bank 용량·출력별 수치 순서 유지. Golden run003의10cases·상위 lane 오류/reset·backpressure PASS; actual-XPM/common-DMA 통합 run001(3872beats,1024records,END/chunk/reset) PASS. 새 module OOC200MHz setup+0.145ns/hold+0.039ns/PW+1.968ns, 실패 endpoint0. LUT104716/FF87614/DSP275/BRAM0/URAM0. W4 M1 ACCUM12947→7395cycles(1.751배),0.253→0.443GMAC/s; QK L1024 1.416배/PV L1024 1.999배, 짧은 QK N2는1028→1060cycles. **새 전체-board BIT·타이밍·실물 결과는 미검증**이며 기존 host SD003은 이전 N4 RTL이다. 결과 보고서는 GEMM_N8_REPORT.md. 아래 N4 결과는 이전 단계 증거다.

**이전 GEMM N4 공급 개선(모듈 범위):** W4 ACT256B/WGT64B 재사용·연속 tagged read3 burst를 추가했다. Golden10cases·오류/reset/backpressure, actual-XPM/common-DMA board-shell 통합 PASS. 새 GEMM OOC200MHz setup+0.430ns/hold+0.039ns/PW+1.968ns PASS. M1/N128/K128 ACCUM16640→12947cycles(1.285배),0.197→0.253GMAC/s. LUT+682/FF+293/DSP·BRAM·URAM 증분0. QK/PV 명령 사이클·ISA·수치·병렬도는 유지한다. **기존 board007/host SD003/reset patch001은 공급 개선 전 RTL**이며 새 전체-board route/BIT/실물 성능은 미검증이다.

**수정 handoff 준비 완료 — 2026-10-07.** 기존 build005의 auxiliary reset 극성 오류를 수정한 build007, 별도 audit002, SD firmware007, host SD003 및 약10MB reset patch001을 검증했다. 실제 vendor reset+AXI 시뮬레이션 PASS. **수정본 실물 보드 실행은 아직 미검증**이며 기존 build005 package는 철회한다. Ubuntu 실행 절차는 SD_HANDOFF.md.

목표: **ZCU104 / bare-metal /200MHz(5ns)**, W4 group128, BF16 activation/KV, 공유 GEMM K16×16출력×1행(256 products; 이전 board007은 N4), 최대 context1024. 사용자 요청으로 이전100MHz를 대체했다. 이전 Skills는 사용하지 않았다.

이전 N4 기준 **수정 build007의200MHz 전체 routed 빌드와 별도 clock/constraint/DRC 감사002가 통과**했다. setup +0.009ns/TNS0, hold +0.010ns/THS0, pulse width +1.000ns, 실패 endpoint0. 최종 HWH의 reset/clock12연결 검사도 PASS. 해당 reset 보정 build007은 공급 개선 전 compute RTL을 사용하며 변경이 board reset 설정에 한정된다. 사용자가 기존 build005에서 첫 UART banner까지 실행한 뒤 PL MMIO/DAP 오류로 정지한 기록과 이전 실패 run003/004/006을 보존한다. 수정본 모델 결과는 사용자 재실행 대기이며 전체 모델 가속 완료로 표시하지 않는다.

현재 RTL의 FP32 add는 exponent 준비와 alignment를 분리한6stage다. 수치 순서·RNE/FTZ는 유지하며 GEMM만 사용자 요청으로 N8로 확대했다. Descriptor validation2stage/issue metadata1stage/commit packet1stage, Vector 주소 등록, XPM read2+role return1(전체 read3), bank write1stage와 완료 응답의 write drain, 등록 reset, ISA에서 금지하는 role-bank 연결 제거를 적용했다.

| 검증 | 현재 증거와 한계 |
|---|---|
| 모듈 golden/프로토콜 | FP32 `fp32_sim_run007`; nonlinear/RMSNorm/RoPE/Softmax/Vector의 `*_fp6_sim_run001`; GEMM `gemm_fp6_xsim_run001` 모두 최종 payload/error/backpressure/reset 검사까지 PASS. GEMM의 동일 소스·TB·벡터를 실행하던 중복 Iverilog는 취소했으며 취소 결과를 PASS로 집계하지 않는다. |
| Descriptor와 write queue | `descriptor_pipeline_sim_run002`, `bank_write_pipeline_sim_run001` PASS. latter는 논리 memory model이다. |
| Actual XPM 통합 | `board_shell_200mhz_xsim_run012` PASS: common DMA/adapters, compute golden3872beats,1024records/PC1023 END,조각 상태 보존,CSR/reset. Pending write 동안 lease release 및 END/DONE 금지 assertion 포함. Vendor AXI/DDR는 모델이며 전체24layer RTL 증거가 아니다. |
| PS clock | RPLL PL0 divisor6×1, 실제 BD200.000000MHz 확인 `board_validate_200mhz_run002`. IOPLL187.5MHz 실패 결과도 보존. |
| PS compiler | `ps_compiler_run003`: Python/C 명령열과 END 위치 byte exact; prefill1/2/17/512,decode prefix2/1023. PS tensor 연산 없음. |
| Offline data/firmware | backup의 `board_data_run003`, `baremetal_run003` 생성 및 identity 확인. Runtime PS는 ISA 생성·적재·제어·결과 byte 복사만 수행. |
| 실물 FPGA | 기존 build005가 첫 UART banner 후 정지; PL profile 강제 읽기에서 DAP transaction error. 기존 handoff002/host SD002는 철회. 수정 host SD003/reset patch001을 준비했고 사용자 재실행·golden 비교가 필요하다. |

200MHz module OOC 결과(보드 타이밍 증거와 별개; GEMM은 native N16 확대 후 새 결과, 나머지 모듈은 해당 RTL unchanged):

| 모듈 | run | setup(ns) | hold(ns) |
|---|---|---:|---:|
| GEMM native BF16/INT4 N16 | native_n16_gemm_200mhz_ooc_run001 | +0.079 | +0.030 |
| RMSNorm | rmsnorm_200mhz_ooc_run002 | +0.445 | +0.041 |
| RoPE | rope_200mhz_ooc_run002 | +1.104 | +0.042 |
| Softmax | softmax_200mhz_ooc_run002 | +0.646 | +0.040 |
| Vector | vector_200mhz_ooc_run004 | +0.546 | +0.026 |
| Bank fabric | bank_fabric_200mhz_ooc_run005 | +0.121 | +0.047 |
| Descriptors | descriptors_200mhz_ooc_run002 | +0.660 | +0.046 |

각 OOC pulse width도 통과했다. Bank fabric은 LUT27335/FF6194/BRAM70/URAM10이다. 전체 routed 자원은 LUT114017(49.49%)/FF80265(17.42%)/BRAM85.5(27.40%)/URAM10(10.42%)/DSP161(9.32%)이다. Executor 합성만의 수치는 LUT109647/FF67595/BRAM81/URAM10/DSP161이며 전체 보드 수치와 구분한다.

수치 비교의 별도 상태:

- `isa_small_run002`: 전체24layer prefill2/decode(prefix2) logits/allKV가 독립 W4 reference와 bit exact.
- **원본 BF16 대비 W4 품질 실패**: prefill relative L2약0.444/cosine0.923,decode약0.669/cosine0.798. 기준을 완화하지 않았다.
- `isa_extended_run001`: prefill17 PASS. **prefill512 KV 실패**: layer12 V relative L2 0.0717758 >0.05; logits 기준 PASS.
- context1024 decode 비교 PASS는 reference로 만든 prefix1023에서 한 토큰을 실행한 결과이며, ISA1023-token 연속 prefix 증거는 아니다.

논리 command memory는32KiB/1024record 하나다. 동일 PC의 두 physical128bit half로 구성하며 double buffering이 아니다. END는 outstanding/write drain 후 DONE을 내고 bank/KV/descriptors/psum을 유지한다. PS는 idle에서 다음 chunk를 적재하고 DSB 후 START한다. 오류 복구는 coordinated reset/replay다.

구조 checker는 PASS이나 r1의 기존 common3계약 pin을 유지해 `engine_completion_contract_pinned:false`다. Fixed read3 interface에는 새로운 native-v3의 명시적 memory resp_valid가 없다. 새 completion 계약 전체를 충족한다고 표시하지 않는다. Pending write/release/DONE 증거는 위 통합 범위로 제한한다.

대형 산출물과 immutable snapshots: `/media/admin1/backup/llm2rtl-builds/qwen25_05b_w4_shared_zcu104_r1`. 현재 N16 결과는 `evidence/native_n16_board_200mhz_passed_run009/result.json`, matching handoff는 `evidence/native_n16_handoff_run004.json`이다. 이전 N4 증거 index는 `evidence/verification_index_run007.json`이다. 소스가 다른 이전 PASS를 현재 RTL에 적용하지 않는다. Handoff는 전체 routed setup/hold/PW, clock/constraint/DRC audit와 artifact identity 확인 후 생성했다. 보드 실행은 위 수치 품질 실패를 해소하지 않는다.

추가 wrapper 수정은 run012 actual-XPM/common-DMA golden integration과 DMA fault/backpressure/tag wrap+mismatch/reset run002를 통과했다. Dispatcher는 정확히 고정한 framework `history/v2` exclusive-owner template에 USER 영역만 채운다. 고정 body exact identity와 새 source manifest를 기록했다. Compile run011의 v4/v2 혼합 실패는 보존하고 교정했다.

완료 bank role map을 명령 수락 시 저장하고 DMA adapter payload를 registered bank ID의 one-hot OR로 선택한다. Port/latency/수치/병렬도는 유지한다. 변경한 두 wrapper를 제외한7 OOC의 실제 parsed source/ROM/profile SHA가 unchanged임을 `module_ooc_reuse_identity_run005.json`으로 확인했다.

수정 전 run004의 최종 routed 결과는 setup **−0.249ns**, TNS−27.494ns/380 endpoints,hold+0.010ns/PW+1.000ns다. 배포하지 않는다. 최악 경로인 saved GEMM bank selector→ownership CE는 최신 run005에서 role map register로 분리했다. run005의 정적 타이밍은 통과했으나 reset 오류로 package를 철회했다. 이전 N4 전체 빌드는 reset 보정 run007이며 위 새 타이밍 결과를 사용한다. 이전 closure 기록은 `evidence/200mhz_closure_state_run005.json`에 보존한다.

XSA는 top-level `qwen_system.hwh`와 SmartConnect child HWH2개를 포함한다. 첫 package001은 단일 HWH 가정으로 실패했고 원본은 보존했다. Package002는 top-level system 이름과 standalone HWH의 byte-exact SHA를 확인한다. BIT도 XSA 내부와 byte exact이다.

사용자 선택으로 SD 모델 적재를 추가했다. 최신 native N16 SD 실행 package는 `releases/qwen_host_sd_200mhz_run005.zip`, matching ELF는 `releases/baremetal_sd_run008`이다. 기존 host SD003(또는 reset patch001을 적용한 SD002 폴더)은 `releases/qwen_sd_n16_patch_run002.zip`으로 갱신할 수 있다. 안내 타이밍 수치가 과거 값으로 고정돼 있던 host SD004/N16 patch001은 배포하지 않는다. SD 루트 QWEN.BIN의 정확한 크기와 SHA256이 일치한 후 기존 ISA를 실행한다. JTAG는 BIT/ELF에만 사용한다. 자세한 Ubuntu 절차는 SD_HANDOFF.md. 실물 SD/FPGA 실행은 미검증이다.

2026-10-07 reset 보정 검증: `board_reset_xsim_run006`은 실제 AMD proc_sys_reset으로 기존 active-low aux=0의 reset 유지와 수정 active-high aux=0의 해제·AXI profile read·PS reset 재진입을 확인한다. `reset_only_source_identity_run007.json`은 compute/source identity를 확인한다. `reset_host_patch_validation_run001.json`은 실제 ZIP과 공백 경로에서 두 번 적용 및 stubbed Tcl 정상/오류 경로를 확인한다. `sd_runtime_audit_run007.json`은 matching XSA/BSP와 새 SD ELF의 FP/SIMD0을 확인한다. 모두 실물 모델 결과와 분리한다.
