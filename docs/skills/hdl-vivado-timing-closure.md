# hdl-vivado-timing-closure 명세서

setup·hold·pulse-width 진단과 수정 루프

- 기준: 2026-09-08 프로젝트 지침
- 원본: [SKILL.md](../../skills/hdl-vivado-timing-closure/SKILL.md)
- 문서 성격: 현재 Skill의 동작 명세이며, 아래 사례는 적용 예시로 실제 검증 결과가 아니다.

## 1. 목적과 적용 조건

Vivado milestone의 timing이 실제로 통과했는지 확인하고 실패 시 수정 소유자와 조정 범위를 결정한다.

## 2. 입력과 선행 조건

현재 source/top/part/clock과 제약, timing_summary·clock·utilization·stage, 허용 pipeline/fanout/memory/placement knobs.

## 3. 상세 처리 절차

1. setup·hold·pulse-width의 worst slack과 failing endpoint 수를 각각 확인한다.

2. post-synth/post-place/post-route와 실제 clock을 명시하고 의도한 target과 비교한다.

3. wide reduction·multiplier·mux·fanout·debug I/O·boundary path의 실패 원인을 분석한다.

4. 원래 로그를 보존하고 구현 담당 하위 에이전트에 제한된 수정 작업을 배정한다.

5. stage 변경 시 latency와 sideband 계약을 갱신하고 관련 기능 및 timing을 재검증한다.

6. 충족 결과와 작은 양수 margin 등 잔여 scaling 위험을 분리해서 보고한다.

## 4. 출력과 산출물

실패 명령·raw report·세 종류 slack·stage, root-cause 가설, tuning/retry owner와 수정 후 current evidence.

파일명은 원본 Skill과 작업 패킷의 지정에 따른다. 산출물 목록은 생성 의무/형식을 설명하며 기존 파일 존재를 주장하지 않는다.

## 5. 완료 및 검증 기준

setup/hold/pulse-width slack ≥0, 실패 endpoint 0, 제약 충족과 올바른 target clock을 확인해야 한다. board I/O signoff에는 적절한 외부 제약도 필요하다.

## 6. 책임 경계와 실패 처리

setup WNS만 보고 통과하지 않는다. 낮은 실제 clock에서의 양수 slack을 목표 clock 통과로 바꾸지 않는다. 부모와 독립 검증 역할은 직접 RTL 수리를 맡지 않는다.

## 7. 연계 Skills

- [fpga-vivado](fpga-vivado.md)
- [fpga-systemverilog](fpga-systemverilog.md)
- [hdl-module-implementation](hdl-module-implementation.md)
- [hdl-integration-agent](hdl-integration-agent.md)
- [hdl-board-wrapper-signoff](hdl-board-wrapper-signoff.md)
- [zcu104-xczu7ev-hardware](zcu104-xczu7ev-hardware.md)

## 8. 적용 예시

200 MHz 목표가 실제 187.5 MHz로 구현되면 slack이 양수여도 clock 요구 미충족으로 분류하고 보드 clock 구성을 수정하도록 반환한다.

## 9. 현재 적용 시 유의점

확정된 모듈 packet의 실제 시뮬레이션·Vivado 스크립트와 보고서 경로를 사용한다.
검증 스크립트가 없다면 해당 담당자에게 반환하며 일반 프레임워크 테스트로
대체하지 않는다. OOC의 unconstrained 외부 I/O caveat를 board timing 통과로 없애지 않는다.

[전체 Skill 명세 목차](../skills_specification.md) · [공통 계약과 운영 규칙](../skills_overview.md)
