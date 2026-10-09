# ZCU104 PS 실행 재현 문서

## 1. 실제 실행 환경과 범위

이 설계는 ZCU104의 Cortex-A53 #0에서 standalone baremetal C 프로그램을
실행한다. Vivado/Vitis 2025.2를 사용했다. PL 클럭은 100 MHz이고, DDR 데이터
경로는 HP0_FPD 한 포트와 128비트 DataMover이다.

호스트 PC는 JTAG로 BIT와 ELF를 내려 실행하고 UART 로그를 수집한다.
PS의 C 프로그램은 모델 데이터를 DDR에 적재하고 ISA를 생성·전송한다.
PL dispatcher와 executor가 RMSNorm, GEMM, RoPE, attention, Softmax, ADD,
SILU_MUL, final norm, lm_head를 실행한다. PS의 BF16 오차 계산과 top1 비교는
검증용 결과 분석이다. 모델 tensor 연산을 PS로 대체하는 경로는 아니다.

현재 ELF는 고정된 32토큰 prefill 뒤 position 32의 1토큰 decode를 실행하는
검증/계측 프로그램이다. 프롬프트를 입력받는 대화형 프로그램은 아니다.
SD 부팅용 BOOT.BIN으로 실행한 것이 아니라 XSCT의 `dow`와 `con`으로 실행했다.

## 2. 바로 실행할 산출물

저장소 루트: `/home/shmin/llm2rtl`

설계 루트: `designs/smollm2_135m_bf16_zcu104_r1`

배포 파일: 설계 루트의 `perf128_board_handoff.tar.gz`

압축 파일은 아래 파일을 포함한 평평한 디렉터리 구조이다.

| 파일 | 역할 |
|---|---|
| zcu104_perf128_board_probe.bit | 계측 카운터를 포함한 PL 구성 |
| zcu104_perf128_board_probe.xsa / .hwh | 같은 빌드의 하드웨어 정보 |
| psu_init.tcl | 같은 XSA에서 추출한 PS 초기화 코드 |
| smollm2_gemm_tiles_numeric_sd.elf | 전체 모델 수치 비교 |
| smollm2_perf128_sd.elf | PS 시간 및 PL 카운터 계측 |
| run_perf128_numeric.tcl | 수치 비교 실행 절차 |
| run_perf128.tcl | 성능 계측 실행 절차 |
| analyze_pl_profile.py | UART 계측 로그 분석 |
| SHA256SUMS / verification.json | 파일 동일성 및 빌드 증거 |

구형 BIT에는 계측 카운터가 없으므로 새 계측 ELF는 이 패키지의 BIT와 함께
실행한다. BIT만 내려서는 PS 프로그램이 실행되지 않는다.

### SD 카드

FAT 파티션 루트에 `MODEL.BIN`을 둔다. 사용자가 사용한 호스트에서는
`/media/iamjames77/BOOT/MODEL.BIN`이었다. ext4 파티션이 아니라 FAT 파티션에
저장한다. PS 프로그램의 파일명은 `0:/MODEL.BIN`이다.

- 원본: `full_model_board_probe/ddr_static_bf16.bin`
- 정확한 크기: 269161088바이트
- SHA256: `7439dd37925be3ba6c3ef6853b1728d836c6bdda13d7bbbcc93f7966bd745c68`
- PS 로더의 CRC32 기대값: `DB7D52BB`

### 호스트 실행

ZCU104 전원, SD 카드, JTAG와 UART 연결을 준비한다. UART는 115200 baud로
열고 실행 전에 로그 기록을 시작한다. Vitis 2025.2 환경에서 XSCT를 실행한다.

```sh
mkdir smollm2-profile128
cd smollm2-profile128
tar -xzf /복사한/경로/perf128_board_handoff.tar.gz
sha256sum -c SHA256SUMS
xsct -nodisp run_perf128_numeric.tcl
```

수치 비교가 끝난 뒤 새 UART 로그를 열고 계측 프로그램을 실행한다.

```sh
xsct -nodisp run_perf128.tcl
```

`BOARD PL PROFILE COMPLETE`가 나온 뒤 분석한다.

```sh
python3 analyze_pl_profile.py uart_profile.txt
```

Tcl의 마지막 `after 10000`은 10초 지연이며 모델 실행 완료 판정이 아니다.
완료는 UART의 종료 문구로 확인한다. 수치 비교 종료 문구는
`BOARD FULL MODEL ISA EXECUTION COMPLETE; REVIEW LOGITS`이다. 이 문구는
ISA 실행 완료를 뜻하며 reference와의 정확한 일치를 보장하지 않는다.

## 3. XSCT의 실제 초기화 순서

`artifacts/run_perf128.tcl`이 아래 순서로 실행한다.

1. `connect`로 hw_server에 연결한다.
2. `Cortex-A53 #0`를 선택하고 정지·processor reset한다.
3. `PSU`를 선택하고 `fpga`로 BIT를 내린다.
4. `psu_init.tcl`을 source하고 `psu_init`을 호출한다.
5. 1초 대기 후 `psu_ps_pl_isolation_removal`을 호출한다.
6. 1초 대기 후 `psu_ps_pl_reset_config`를 호출한다.
7. `Cortex-A53 #0`를 다시 선택하고 processor reset한다.
8. `dow`로 AArch64 ELF를 내리고 `con`으로 실행한다.

DDR 초기화와 PS/PL isolation·reset 해제를 빼고 ELF만 실행해서는 같은
실행 환경을 재현할 수 없다. 보드가 켜져 있어도 이 전체 스크립트로 다시
실행할 수 있다. 매 실행은 SD 데이터를 다시 읽고 prefill부터 시작한다.

## 4. PS main()의 실행 순서

실제 소스: `full_model_board_probe/main.c`

1. 모델 checkpoint와 DDR 주소를 UART로 출력한다.
2. `load_model_from_sd()`로 파일을 읽는다.
3. GPIO status의 ACK sequence를 읽어 `host_seq`를 동기화한다.
4. `run_block()`으로 32토큰 prefill을 실행한다.
5. 동일한 PL/DDR 상태를 유지한 채 1토큰 decode를 실행한다.
6. 결과 비교 또는 계측 로그와 종료 문구를 출력하고 무한 루프에 머문다.

SD 로더는 64 KiB씩 읽어 `MODEL_DDR_BASE + loaded`에 memcpy하고,
`Xil_DCacheFlushRange`로 DDR에 반영한다. 파일 크기와 CRC32가 틀리면 모델
실행을 시작하지 않는다. 이 memcpy는 데이터 운반이다.

주요 주소는 `full_model_board_probe/address_map.h`에서 고정한다.

| 항목 | 값 |
|---|---|
| 모델 이미지 DDR 시작 | 0x57A00000 |
| 이미지 끝 주소, exclusive | 0x69149280 |
| logits DDR 시작 | 0x69131280 |
| 레이어별 weight/KV 주소 | layer_weight_base / layer_kv_base 배열 |

이미지에는 weights 외에도 실행용 데이터 영역이 포함된다. 주소를 임의로
옮기면 `MODEL.BIN`, address_map, ISA 생성 코드가 함께 일치해야 한다.

## 5. PS에서 PL로 ISA를 보내는 제어 규약

PS는 3개의 AXI GPIO IP를 MMIO로 사용한다. 명령 적재 경로와 tensor 데이터
경로는 다르다. ISA는 GPIO→command BRAM으로, weights/KV 등은
DDR↔DataMover↔tensor bank로 이동한다.

| MMIO 주소 | 의미 |
|---|---|
| 0xA0020000 | ISA word[0], bits 31:0 |
| 0xA0020008 | ISA word[1], bits 63:32 |
| 0xA0010000 | ISA word[2], bits 95:64 |
| 0xA0010008 | ISA word[3], bits 127:96 |
| 0xA0000000 | host control 출력 |
| 0xA0000008 | host status 입력 |

`host_op()`는 먼저 payload 4워드를 쓰고 `dsb sy`를 실행한다. 이어 sequence
bit를 토글하고 다음 control 값을 쓴다.

```c
control = (host_seq << 31) | (op << 28) | (bank << 24) | addr;
```

control의 op는 ISA opcode가 아니라 board wrapper의 호스트 제어 연산이다.
ISA opcode는 별도로 128비트 payload의 bits 127:124에 들어간다.

| 호스트 op | 이 실행에서의 의미 |
|---|---|
| 1 | addr 슬롯에 128비트 ISA 기록 |
| 2 | dispatcher START, PC를 처음부터 실행 |
| 7, bank=0 | 계측 BIT에서 카운터 halfword 읽기 |

각 host_op 후 status bit31이 보낸 sequence와 같고 bit30이 0일 때 ACK로
판정한다. 같은 control 값을 반복해서 쓰면 새 요청으로 인식되지 않으므로
sequence 토글을 생략할 수 없다.

| status bit | 의미 |
|---|---|
| 31 | ACK sequence |
| 30 | 호스트 제어 FSM busy |
| 28 | 호스트/dispatcher/DataMover 등의 통합 error |
| 27 | dispatcher DONE |
| 24 | dispatcher BUSY |
| 15:0 | 읽기 응답 데이터 |

**START ACK는 연산 완료가 아니다.** `wait_done()`은 bit28 오류를 먼저
검사하고 bit27 DONE을 기다린다. bit30이 0이라는 이유로 다음 chunk를
덮어쓰면 안 된다. 상태·명령 규약은 `rtl/smollm2_dma_gemm_board_probe.sv`에
구현되어 있다.

## 6. ISA 생성과 조각 실행

실제 생성 코드: `full_model_board_probe/program.c`

`smollm2_emit_block()`은 token ID, rows, start position과 레이어 주소에서
ISA를 만들고 `issue()` callback으로 전달한다. 고정 hex 파일을 호스트에서
매번 내려 실행하는 방식이 아니다. GEMM_TILES를 사용할 때는 PL이 반복
weight LOAD와 GEMM을 전개한다.

command BRAM은 16개 × 128비트 = 256바이트이다. 한 조각에는 최대 15개
작업 명령과 END 1개를 넣는다. 진단용 probe counter 중복 조건에 따라
15개 이전에도 조각을 종료한다.

```text
issue(): 작업 ISA를 슬롯 0부터 기록
flush_chunk(): 다음 슬롯에 all-zero END 기록
               START 전송
               error 또는 DONE까지 polling
               계측이면 frozen counter 읽기
               다음 조각을 슬롯 0부터 기록
```

END는 조각의 outstanding 작업을 drain하고 DONE을 만든다. 다음 START는
PC와 실행 bookkeeping을 다시 시작하지만 tensor bank/KV 데이터를
전체 초기화하지 않는다. 따라서 chunk 사이와 prefill→decode 사이의 상태가
유지된다. 이 사이에 PL 재프로그래밍이나 전체 reset을 넣으면 안 된다.

현재 compact 실행은 prefill 93조각, decode 91조각이다. DMA_LOAD/STORE는
PS가 해당 tensor를 직접 계산하는 명령이 아니라 PL DataMover를 구동하는
명령이다. GPIO로 전달하는 것은 이 경로의 ISA와 제어 정보이다.

## 7. ELF를 다시 빌드하려는 세션의 필수 의존성

준비된 ELF를 실행할 때는 재빌드가 필요 없다. 소스를 수정할 때 사용한
빌드 스크립트는 `scripts/build_perf128_sd_board_app.py`이다.

- AArch64 compiler: Vitis 2025.2의 `aarch64-none-elf-gcc`
- BSP: standalone_a53_0, Xilinx.spec, BSP include와 lib
- 링커: `build/gemm_board_vitis_cli/gemm_board_smoke/src/lscript.ld`
- C 소스: main.c, program.c, sd_model_loader.c
- FatFS: xilffs_v5_5의 ff.c, diskio.c, ffsystem.c
- 추가 헤더: FSBL BSP의 xilffs_config.h
- 라이브러리: xilstandalone, xiltimer, xil, gcc, c
- 공통 define: SDT, LOAD_MODEL_FROM_SD, USE_GEMM_TILES
- 계측 define: PERF_ONLY, PROFILE_PL

스크립트는 이 PC의 `/media/admin1/backup/tools/Xilinx/2025.2/Vitis`와
설계 루트 아래 기존 `build/gemm_board_vitis_cli` 플랫폼을 참조한다.
소스 압축만 푼 다른 PC에는 이 BSP와 링커가 자동으로 생기지 않는다.
다른 세션은 기존 의존성을 사용하거나, 일치하는 XSA에서 standalone
Cortex-A53 #0 플랫폼을 만들고 SD/FatFS 지원·주소·링커 구성을 맞춰야 한다.
이 ELF는 GPIO 주소와 PS 구성이 유지된 기존 BSP를 재사용하여 빌드했다.

## 8. 다른 세션이 실행을 재현하지 못할 때 확인할 항목

1. BIT뿐 아니라 ELF를 `dow`하고 `con`했는가?
2. 같은 XSA의 psu_init과 isolation/reset 해제를 수행했는가?
3. Cortex-A53 #0의 standalone AArch64 프로그램인가?
4. FAT 루트의 MODEL.BIN 크기·CRC가 일치하는가?
5. DDR 적재 후 cache flush가 있는가? DMA_STORE 결과의 PS 읽기는 기존
   비교 코드의 cache invalidate 절차를 따라야 한다.
6. GPIO 주소·word 순서·sequence 토글·ACK 규약을 지켰는가?
7. START ACK와 dispatcher DONE을 구분했는가?
8. chunk 사이의 bank/KV 상태를 reset하지 않았는가?
9. 계측 ELF와 카운터가 있는 BIT를 함께 사용하는가?
10. 소스 재빌드라면 BSP, FatFS 헤더, libxil, 링커까지 준비했는가?

실물 확인 근거는 사용자가 반환한 UART이다. 새 동작을 추가하면 이 문서의
기존 실행 증거를 새 기능의 통과 증거로 사용하지 않는다.
