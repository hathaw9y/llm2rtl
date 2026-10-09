# Ubuntu 호스트에서 N16 SD 모델 실행

2026-10-07 현재 세트: **board build009 / audit003 / SD firmware008 / host SD005 / N16 patch002**. Native M1×N16×K16 BF16×INT4/BF16×BF16 GEMM과 전체 compute/fabric/PS/DDR를 포함한다. 전체 routed 200MHz **setup+0.002ns / hold+0.010ns / pulse width+1.000ns**,실패 endpoint0·DRC error0·routing error0. 별도 clock/constraint/reset 감사 PASS. Setup2ps 여유는 매우 작으므로 이 exact 산출물에만 PASS를 적용한다. 실물 실행은 미검증이다. 상세: [IMPLEMENTATION_N16_REPORT.md](IMPLEMENTATION_N16_REPORT.md).

처음 설치하거나 호스트 원본 상태가 불확실하면 **전체 `releases/qwen_host_sd_200mhz_run005.zip` 및 `.zip.sha256`**을 Ubuntu PC로 복사한다. 다음은 일반 터미널 명령이다:

```sh
sha256sum -c qwen_host_sd_200mhz_run005.zip.sha256
unzip qwen_host_sd_200mhz_run005.zip
cd qwen_host_sd_200mhz_run005
python3 host.py verify
```

기존 **host SD003** 또는 이전 reset patch001을 적용한 `/home/iamjames77/qwen/qwen_host_sd_200mhz_run002` 폴더라면 약13MB **`qwen_sd_n16_patch_run002.zip` 및 `.zip.sha256`**만 복사해 적용할 수 있다:

```sh
sha256sum -c qwen_sd_n16_patch_run002.zip.sha256
unzip qwen_sd_n16_patch_run002.zip
cd qwen_sd_n16_patch_run002
python3 apply_patch.py --package /home/iamjames77/qwen/qwen_host_sd_200mhz_run002
```

`HOST_PATCH_PASS`를 확인한다. `--package`에는 실제 사용 중인 원본 host 폴더를 지정한다. BIT/HWH/XSA/ELF·PS init·manifest·로더와 안내를 matching set으로 갱신하며, 기존 파일 SHA256이 다르면 수정 전에 중단한다. 이전 reset 패치를 적용하지 않은 SD002, 중간 SD004 등 다른 원본이면 전체 SD005 ZIP을 사용한다. 같은 패치를 두 번 적용할 수 있고 폴더 이름은 그대로 남는다.

**기존 SD의 QWEN.BIN은 변경되지 않아 다시 복사할 필요 없다.** 파일이 없으면 새 host 폴더에서 `python3 copy_sd.py --mount /media/iamjames77/BOOT`를 실행해 FAT32 BOOT 루트에 복사한다. `SD_COPY_SHA256_PASS` 후 `sync`와 안전 제거를 수행한다. 도구는 포맷하지 않는다. `/dev/sda2` ext4가 아닌 기존 FAT32 `/dev/sda1`을 사용한다. SD는 모델 저장용이며 보드는 **JTAG boot**다.

중간 host SD004/N16 patch001은 안내의 과거 고정 타이밍값을 고친 SD005/patch002로 대체한다. Hardware는 동일한 audited run009다. 기존 reset 수정 전 빌드의 첫 UART banner 정지와 DAP 오류 기록, N16 run008의 setup−0.029ns 실패 기록도 보존한다.

기존 XSCT를 종료하고 보드를 **전원 OFF→ON**한다. JTAG와 SD를 연결하고 UART1(FTDI if02, 사용자 호스트에서는 ttyUSB2)을115200 8N1, flow control 없음으로 열어 전체 출력을 package 폴더의 `uart.log`에 기록한다. 수정한 원본 package 폴더에서 새 XSCT를 열고:

```tcl
source load_board.tcl
```

새 로더는 matching PS init과 BIT를 적용한 다음 **CPU ELF 다운로드·실행 전에** PSU의 PL profile(0xA0010018=0x51574E31)과 상태(0xA0010004)를 확인한다. XSCT에서 `PL_CONTROL_PREFLIGHT_PASS profile=QWN1 reset_released`가 나와야 한다. 읽기 실패/profile 불일치/busy·reset·error면 CPU 실행을 막는다. 오류가 있으면 그 로그를 보존한다.

UART 예상 순서:

```text
QWEN shared W4 ISA baremetal r1 / no runtime tensor math
SD_LOAD_BEGIN file=0:/QWEN.BIN
SD_LOAD_PROGRESS ...
SD_MODEL_SHA256_PASS
prefill2 DONE commands=123194 chunks=132 PL_active_cycles=<측정값> cache_length=2
decode1 DONE commands=246290 chunks=264 PL_active_cycles=<누적 측정값> cache_length=3
HANDOFF_DONE.
```

349MB SD 읽기·SHA256 검사에는 시간이 걸린다. PS는 read-only FAT SD1에서 정확한348638208bytes를 DDR0x10000000으로 읽고 destination SHA256을 검사한다. 기대 SHA256은 `b43d2ce45485e2a3aeae9620bae6f5ac403739155e05bb91ff05b669b856ddcc`다. 실패 시 ISA START를 수행하지 않는다. PS는 파일 읽기·byte transfer·integer SHA256·ISA 생성/제어·byte snapshot만 수행하며 tensor 계산은 PL에서 수행한다. matching ELF008 disassembly에서 FP/SIMD instruction0을 확인했다.

**UART HANDOFF_DONE을 확인한 뒤에만** 같은 XSCT 세션에서:

```tcl
source dump_board.tcl
```

네 logits/KV dump를 생성한 뒤 일반 터미널에서 `python3 host.py compare`를 실행한다. UART·dump·artifact_manifest.json·user_board_result_run001.json을 함께 반환한다. 기대 status는 `passed_user_returned_prefill2_decode1`이며 측정 cycles는0보다 커야 한다.

호스트 검증: 실제 새/구 ZIP CRC·SHA256, 공백 경로에서 패치 두 번 적용, 모든 새 파일 checksum 일치, QWEN.BIN 변경 없음, hardware command stub으로 정상 load/dump와 profile/reset/error의 CPU 실행 차단을 확인했다. 보드 UART나 dump는 생성하지 않았다. 실제 SD 카드/N16 FPGA 실행은 사용자 검증 대상이다. 원본 BF16 대비 W4 품질 실패, prefill512 KV tolerance 실패, reference-seeded prefix1023 decode 한계는 남아 있다. 이 handoff는 전체1024context 가속 완료 증거가 아니다.
