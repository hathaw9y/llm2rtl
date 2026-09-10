# fpga-vivado 명세서

Vivado 실행과 도구 증거

- 기준: 2026-09-08 프로젝트 지침
- 원본: [SKILL.md](../../skills/fpga-vivado/SKILL.md)
- 문서 성격: 현재 Skill의 동작 명세이며, 아래 사례는 적용 예시로 실제 검증 결과가 아니다.

## 1. 목적과 적용 조건

XSIM·Tcl·합성·구현·Xilinx IP와 source closure를 실행·검사한다. RTL 정적 품질과 실제 도구 결과를 구분한다.

## 2. 입력과 선행 조건

실제 Vivado executable/version, part/board/top, source closure, XDC/clock, generated IP/library, 출력 디렉터리와 필요한 실행 단계.

## 3. 상세 처리 절차

1. 환경 preflight로 도구·소스·IP·clock·scope를 확정한다.

2. xvlog, xelab, xsim의 각각 결과를 검사하며 실제 self-checking 종료를 확인한다.

3. 재현 가능한 Tcl로 synthesis와 필요한 implementation을 실행하고 wait 이후 run status를 검사한다.

4. 목표 clock과 각 timing 단계의 WNS/TNS·WHS/THS·pulse-width·endpoint·unconstrained 항목을 기록한다.

5. DSP/BRAM/URAM inference, black box, source/packaged identity와 parameter 변경의 실제 resource 효과를 확인한다.

6. DRC·methodology·congestion·logs·checkpoints를 원래 run에 묶어 보고한다.

## 4. 출력과 산출물

실행 Tcl/명령과 raw logs/reports, tool version, part/top/clock/source/run identity, sim/synth/implementation 결과와 DSP·memory·warning 범위.

파일명은 원본 Skill과 작업 패킷의 지정에 따른다. 산출물 목록은 생성 의무/형식을 설명하며 기존 파일 존재를 주장하지 않는다.

## 5. 완료 및 검증 기준

실행 단계마다 독립적으로 성공을 판정한다. compile은 elaborate를, sim은 synthesis/timing을, route는 실물 실행을 증명하지 않는다.

## 6. 책임 경계와 실패 처리

미실행·timeout·missing PASS·NA timing·잘못된 clock·stale report를 통과로 해석하지 않는다. unknown IP CONFIG 속성을 만들어내지 않고 실제 버전에서 확인한다.

## 7. 연계 Skills

- [fpga-systemverilog](fpga-systemverilog.md)
- [hdl-vivado-timing-closure](hdl-vivado-timing-closure.md)
- [fpga-board-build-signoff](fpga-board-build-signoff.md)
- [zcu104-xczu7ev-hardware](zcu104-xczu7ev-hardware.md)

## 8. 적용 예시

BRAM을 의도한 RTL이 FF로 합성되면 실제 utilization과 read/reset 구조를 근거로 원인을 보고하고 구현 담당에게 반환한다.

## 9. 현재 적용 시 유의점

기본 선호 버전은 2024.1이지만 활성 패킷이 지정한 버전과 실제 banner가 기준이다. 본 명세 작성은 Vivado 실행을 포함하지 않는다.

[전체 Skill 명세 목차](../skills_specification.md) · [공통 계약과 운영 규칙](../skills_overview.md)

