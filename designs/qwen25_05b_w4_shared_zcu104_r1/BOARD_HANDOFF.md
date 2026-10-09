# N16 전체 implementation 및 사용자 보드 handoff

현재 세트는 **board_200mhz_build_run009 / board_200mhz_audit_run003 / sd_bsp_run005 / baremetal_sd_run008 / board_handoff_200mhz_run004 / qwen_host_sd_200mhz_run005 / qwen_sd_n16_patch_run002**다. ZCU104 native BF16×INT4/BF16×BF16 M1×N16×K16,200MHz 전체 implementation을 완료했다. 기존 board007/host SD003은 이전 N4 RTL이며 N16 증거로 사용하지 않는다.

Routed setup+0.002ns/TNS0,hold+0.010ns/THS0,pulse width+1.000ns,실패 endpoint0; routing error0,DRC error0. 같은 routed DCP를 별도로 열어5ns clocks,unconstrained/clock omissions0,reset/clock12connections를 확인했다. Setup2ps 여유는 매우 작다. 전체 LUT185248/FF151792/DSP314/BRAM85.5/URAM10. 최초 run008 setup−0.029ns 실패는 보존했고 새 run009의 post-route physical optimization으로 closure했다. RTL·수치·N16·ISA·bank·200MHz·timing exceptions를 바꾸지 않았다.

대형 matching BIT/HWH/XSA/DCP는 `/media/admin1/backup/llm2rtl-builds/qwen25_05b_w4_shared_zcu104_r1/board_200mhz_build_run009`에 보존했다. `board_handoff_200mhz_run004/artifact_manifest.json`에 산출물 identity를 기록했고 XSA 내부 BIT/HWH와 외부 파일의 exact hash를 확인했다. Matching XSA로 만든 read-only SD1 BSP와 ELF의 FP/SIMD instructions0을 확인했다. PS는 SD/FAT byte read,integer checksum,ISA 생성/제어 및 byte 결과 복사만 한다.

Ubuntu에는 `releases/qwen_host_sd_200mhz_run005.zip` 전체 또는 기존 SD003에 대한 약13MB `releases/qwen_sd_n16_patch_run002.zip`을 전달한다. 기존 SD QWEN.BIN은 동일하다. 중간 SD004/patch001은 README의 과거 timing 고정값을 고친 최종 SD005/patch002로 대체한다. 실제 archive CRC/SHA256·공백 경로·패치 두 번 적용·33files identity·Tcl stubs·README timing 일치를 확인했다.

정확한 cold power OFF/ON·새 XSCT·UART1 ttyUSB2·load/preflight·HANDOFF_DONE 후 dump/compare 절차는 [SD_HANDOFF.md](SD_HANDOFF.md)를 따른다. 기대 검증 범위는 full24layer prefill[9707,11],decode[151643],last-token logits 및 모든 유효 KV다. 사용자 반환 UART와 네 dump로만 실물 PASS를 판단한다. 아직 실물 model/cycles 결과는 없다.

원본 BF16 대비 W4 품질 probe 실패,prefill512 KV tolerance 실패,reference-seeded prefix1023 decode 한계는 남아 있다. 전체1024context/실물 모델 가속 완료를 주장하지 않는다. 전체 보고서: [IMPLEMENTATION_N16_REPORT.md](IMPLEMENTATION_N16_REPORT.md).
