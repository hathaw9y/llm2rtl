# zcu104-xczu7ev-hardware 명세서

ZCU104 장치·clock·보드 제약

- 기준: 2026-09-08 프로젝트 지침
- 원본: [SKILL.md](../../skills/zcu104-xczu7ev-hardware/SKILL.md)
- 문서 성격: 현재 Skill의 동작 명세이며, 아래 사례는 적용 예시로 실제 검증 결과가 아니다.

## 1. 목적과 적용 조건

ZCU104/xczu7ev-ffvc1156-2-e에 한정된 계획·합성·보드 검증 규칙을 제공한다.

## 2. 입력과 선행 조건

정확한 part와 활성 config의 target clock·memory width·tuning, device inventory와 max budget, tool version·PS/PL/DDR 설계·runtime 환경.

## 3. 상세 처리 절차

1. board/part와 target identity를 모든 증거에 기록하고 LUT/FF/DSP/BRAM/URAM inventory와 design budget을 구분한다.

2. weight/scale/zero metadata와 tile/duplicate buffer 용량을 계산해 preload/partial/streaming을 비교한다.

3. 특정 W4A4KV4 WS32+DSP-per-cell=1 조건에서는 실제 PE product/DSP floor를 검사한다.

4. 200 MHz target은 실제 implemented clock period ≤5 ns와 timing/DRC·I/O 조건을 확인한다.

5. 사용자 runtime 테스트 절차에 BIT/HWH identity와 실제 FCLK readback·cycle 환산 검사를 포함한다.

6. 보드 clock 불일치나 source 변경 시 원시 보고서를 보존하고 wrapper/timing 담당에 반환한다.

## 4. 출력과 산출물

장치·예산·clock·memory 설정, capacity 판단, PS/PL/DDR·DRC 체크, raw report 경로와 runtime clock 검증 조건.

파일명은 원본 Skill과 작업 패킷의 지정에 따른다. 산출물 목록은 생성 의무/형식을 설명하며 기존 파일 존재를 주장하지 않는다.

## 5. 완료 및 검증 기준

올바른 routed top·실제 target clock·setup/hold/PW와 board-visible 제약을 만족해야 한다. 낮은 clock의 runtime 결과는 그 실제 주파수로만 분류한다.

## 6. 책임 경계와 실패 처리

다른 FPGA의 inventory로 사용하지 않는다. metadata만으로 PE 존재를 주장하거나 PS 설정 요청값만으로 implemented clock을 인정하지 않는다. 실물 실행은 현재 프로젝트에서 사용자 책임이다.

## 7. 연계 Skills

- [parent-module-decomposition](parent-module-decomposition.md)
- [fpga-ddr-pingpong-residency](fpga-ddr-pingpong-residency.md)
- [fpga-vivado](fpga-vivado.md)
- [hdl-vivado-timing-closure](hdl-vivado-timing-closure.md)
- [hdl-board-wrapper-signoff](hdl-board-wrapper-signoff.md)
- [fpga-board-build-signoff](fpga-board-build-signoff.md)
- [fpga-hardware-validation](fpga-hardware-validation.md)

## 8. 적용 예시

5 ns로 빌드한 overlay의 runtime FCLK가 상향 반올림되면 사용자 테스트에서 실제 주파수를 확인하고 설계 허용치를 넘는 연산을 시작하지 않도록 한다.

## 9. 현재 적용 시 유의점

원본 inventory의 device_*_ram_mb 표기는 단위가 모호할 수 있으므로 용량 판단은 BRAM36/URAM primitive count와 명시적 bit/byte 산식으로 확인한다. 1024 DSP floor는 조건부 예제이며 전 설계 공통 최소치가 아니다.

[전체 Skill 명세 목차](../skills_specification.md) · [공통 계약과 운영 규칙](../skills_overview.md)

