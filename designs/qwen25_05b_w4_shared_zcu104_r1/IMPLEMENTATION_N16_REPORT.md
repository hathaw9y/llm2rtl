# Native N16 전체 implementation — 2026-10-07

ZCU104 `xczu7ev-ffvc1156-2-e`, Vivado2025.2, PL0 **200MHz**에서 native BF16×INT4 / BF16×BF16 **M1×N16×K16** GEMM을 포함한 전체 시스템을 합성·배치·배선·BIT 생성까지 완료했다. 나머지 compute executors, dispatcher, bank fabric, 공통 DataMover, PS/DDR 연결을 포함한다. PS는 SD/FAT byte 읽기·integer SHA256·ISA 생성/적재/제어·결과 byte 복사만 수행한다.

| 범위 | 새 증거 | 결과 |
|---|---|---|
| GEMM golden/프로토콜 | native_n16_gemm_xsim_run002 | 10cases, tail N5/9/13, numeric/address errors, reset/backpressure/ID PASS |
| RTL 통합 | native_n16_board_shell_xsim_run001 | actual-XPM BRAM/URAM/common-DMA,3872beats,1024commands/END/chunk retention PASS; bounded vendor DDR model |
| GEMM module OOC | native_n16_gemm_200mhz_ooc_run001 | setup+0.079ns/hold+0.030ns/PW+1.968ns; DSP292 |
| 전체 board route | board_200mhz_build_run009 | setup**+0.002ns**,hold**+0.010ns**,PW**+1.000ns**; 실패 endpoint0 |
| 별도 routed 감사 | board_200mhz_audit_run003 | same-DCP hash, clock5ns, constraint omissions0,DRC errors0,reset/clock12connections PASS |
| SD firmware | sd_bsp_run005 / baremetal_sd_run008 | matching XSA/ELF, FP/SIMD instructions0 |
| Ubuntu 패키지 | host SD005 / N16 patch002 | ZIP CRC/SHA256,공백 경로,패치 두 번 적용,33files hashes,Tcl stubs,README timing 일치 PASS |
| 실물 FPGA | 사용자 실행 대기 | UART/cycles/logits/KV 미확인 |

전체 자원: **LUT185248/230400(80.40%),FF151792/460800(32.94%),DSP314/1728(18.17%),BRAM36 tiles85.5/312(27.40%),URAM10/96(10.42%)**. Bank fabric를 포함한 전체 결과이며 GEMM 단독 자원과 구분한다. Routing 대상301350nets 전부 routed, routing error0이다.

최초 run008은 setup−0.029ns/TNS−0.168ns/16endpoints로 실패했다. 최악 경로는 RoPE parameter address→fabric BRAM enable, data delay4.554ns 중 route3.368ns였다. 실패 기록을 보존하고 새 run009 사본에서 **post-route AggressiveExplore**로 closure했다. RTL·numeric order·ISA·bank layout·N16 병렬도·200MHz 및 timing constraints를 바꾸지 않았다. 공유 RTL39개가 통과한 통합 simulation snapshot과 hash 일치한다. **Setup 여유2ps는 매우 작다. 이 정확한 routed 산출물의 PASS를 이후 소스/빌드에 적용하지 않는다.**

수치 계약은 BF16 입력, W4 signed[-7,7]/group128, exact FP32 product, adjacent tree16와 순차 K16/group FP32 누산·scale, 별도 BF16 CAST/RNE/FTZ를 유지한다. 사용자 선택의 native BF16×INT4이다. W4 M1/N128/K128 ACCUM은4619cycles(200MHz 환산23.095us/0.709GMAC/s), native N8 대비1.601배다. QK/PV L1024는 약1.26배. 이 값은 모듈 시뮬레이션이며 DDR·PS·전체 모델 실물 throughput은 아니다.

배포 세트:

- build009 / audit003 / SD BSP005 / ELF008 / board handoff004
- [전체 Ubuntu ZIP](releases/qwen_host_sd_200mhz_run005.zip):291476651bytes, SHA256 `d21808882cdbd7d0356e0fa925147ea32b38a9c0f1ec743e2b91646c55a8ed1c`
- [N16 업데이트 ZIP](releases/qwen_sd_n16_patch_run002.zip):13197854bytes, SHA256 `8aec2a6eaf68012f1a3130f9981d119e5addee110c8b891eaf618630f201f944`
- SD `QWEN.BIN`:348638208bytes, SHA256 `b43d2ce45485e2a3aeae9620bae6f5ac403739155e05bb91ff05b669b856ddcc`; 이전 SD003와 byte exact이므로 재복사 불필요.

XSA 내부 BIT/HWH와 외부 파일이 exact hash 일치한다. Fresh SD BSP는 SD1FF170000/read-only FAT를 사용한다. 새 ELF의 SHA256은 `25cdf56e618636039cbed7a2b9b67f2699a05649a612e57112984081d9822a8c`다. Hardware profile은 matching build/firmware가 사용한 snapshot hash를 유지한다. 패키지 안내의 과거 hardcoded setup값을 발견해 audit 값으로 생성하도록 수정했다. 중간 host SD004/N16 patch001은 배포하지 않는다.

실행은 [SD_HANDOFF.md](SD_HANDOFF.md)를 따른다. 보드 JTAG boot, cold power OFF/ON, 새 XSCT, UART1 FTDI if02/ttyUSB2/1152008N1. `load_board.tcl`은 PL profile/status preflight 후에만 CPU를 실행한다. SD 전체 SHA256 이후 ISA START. `HANDOFF_DONE` 이후에만 `dump_board.tcl`과 `python3 host.py compare`를 실행한다. Full24layer prefill[9707,11],decode[151643]의 logits·모든 유효 KV 비교가 대상이다.

기존 원본 BF16 대비 W4 품질 probe 실패와 prefill512 KV tolerance 실패는 남아 있다. decode1024 증거는 reference-seeded prefix1023이며 전체 ISA prefix1023 생성 검증이 아니다. 이 implementation 완료를 전체1024context 모델 가속·실물 PASS로 표시하지 않는다.

증거:

- [전체 routed/audit 결과](evidence/native_n16_board_200mhz_passed_run009/result.json)
- [최종 타이밍](evidence/native_n16_board_200mhz_passed_run009/timing_summary.rpt),[전체 자원](evidence/native_n16_board_200mhz_passed_run009/utilization.rpt),[별도 감사](evidence/native_n16_board_200mhz_passed_run009/audit/result.json)
- [실패 run008](evidence/native_n16_board_200mhz_failed_run008/result.json),[SD integer-runtime audit](evidence/sd_runtime_audit_run008.json),[실제 archive/patch 검증](evidence/n16_host_patch_validation_run002.json)

대형 immutable project/DCP/BIT/HWH/XSA 원본은 `/media/admin1/backup/llm2rtl-builds/qwen25_05b_w4_shared_zcu104_r1/board_200mhz_build_run009`에 보존했다. Build009의 manifest에 build008 snapshot과 continuation Tcl hash가 기록된다. 재현은 fresh output directory에서 `build_board.py`로 전체 build를 하고, 필요 시 `continue_board_implementation.py PRIOR FRESH_OUT`으로 같은 제약의 post-route closure를 수행한다. 이후 `audit_board.py`,matching BSP/ELF build, `package_handoff.py`,`package_host.py`,`validate_host_patch.py` 순서로 준비한다. 실물 보드에 자동 접근하지 않는다.
