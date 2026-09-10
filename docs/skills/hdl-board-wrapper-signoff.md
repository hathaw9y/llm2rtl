# hdl-board-wrapper-signoff 명세서

보드 wrapper와 Block Design 구성·감사

- 기준: 2026-09-08 프로젝트 지침
- 원본: [SKILL.md](../../skills/hdl-board-wrapper-signoff/SKILL.md)
- 문서 성격: 현재 Skill의 동작 명세이며, 아래 사례는 적용 예시로 실제 검증 결과가 아니다.

## 1. 목적과 적용 조건

검증된 accelerator 계층을 실제 FPGA의 제어·clock/reset·DDR·주소 맵과 연결한다. 구현과 독립 감사 모드를 구분한다.

## 2. 입력과 선행 조건

verified integration/source hashes/parameters, 정확한 board/part/tool/clock/inventory, PS/PL·AXI·interrupt·DDR 정책, XDC·BD 계약·coverage.

## 3. 상세 처리 절차

1. 기존 integration과 보드 입력·source identity를 확인한다.

2. scheduler, Fabric, loader/drain, compute, routing, BMG를 별도 BD 역할로 연결한다.

3. 내부 clock/reset·synchronizer·CDC, AXI widths/control/status/address map을 구성·검사한다.

4. 실제 자식·메모리 경로·포트 closure 및 stub/disconnected/optimized-away 데이터패스를 확인한다.

5. 패킷의 synth/implementation을 실행 또는 감사하고 timing/resource/DRC/methodology/clock/congestion을 기록한다.

6. 정확한 routed wrapper와 소스·Tcl·XDC·hash를 board-build 담당에게 인계한다.

## 4. 출력과 산출물

BD/wrapper/Tcl/XDC(구현 역할일 때), source/child manifest, board_wrapper_report.json, raw logs·checkpoints·연결 요약.

파일명은 원본 Skill과 작업 패킷의 지정에 따른다. 산출물 목록은 생성 의무/형식을 설명하며 기존 파일 존재를 주장하지 않는다.

## 5. 완료 및 검증 기준

해당 build의 setup/hold/pulse-width와 endpoint, blocking DRC/methodology, 필요한 DDR·clock/reset·I/O 조건을 충족해야 routed wrapper signoff이다.

## 6. 책임 경계와 실패 처리

구현 결과와 독립 감사 증거를 혼합하지 않는다. 전체를 opaque custom RTL로 합치거나 side-generated BD만으로 PS/PL 연결을 주장하지 않는다. 최종 BIT/HWH/XSA publication은 다음 Skill 책임이다.

## 7. 연계 Skills

- [fpga-systemverilog](fpga-systemverilog.md)
- [fpga-vivado](fpga-vivado.md)
- [hdl-vivado-timing-closure](hdl-vivado-timing-closure.md)
- [zcu104-xczu7ev-hardware](zcu104-xczu7ev-hardware.md)
- [fpga-board-build-signoff](fpga-board-build-signoff.md)

## 8. 적용 예시

최소 GEMM 구성에 PS AXI control과 DataMover를 연결하고 Fabric endpoint→loader→bank→compute의 실제 경로를 BD와 보고서로 확인한다.

## 9. 현재 적용 시 유의점

프로젝트는 create_bd_design -dir로 canonical BD 위치를 유지한다. 통합 hierarchy와 별도 BD 역할을 어떻게 배치할지는 보드 패킷에서 명시한다.

[전체 Skill 명세 목차](../skills_specification.md) · [공통 계약과 운영 규칙](../skills_overview.md)

