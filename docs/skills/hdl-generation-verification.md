# hdl-generation-verification 명세서

재사용 HDL 생성·검증의 포괄 절차

- 기준: 2026-09-08 프로젝트 지침
- 원본: [SKILL.md](../../skills/hdl-generation-verification/SKILL.md)
- 문서 성격: 현재 Skill의 동작 명세이며, 아래 사례는 적용 예시로 실제 검증 결과가 아니다.

## 1. 목적과 적용 조건

보드 통합 전 모듈의 기능·cycle·source closure를 증명하는 전체 절차다. 제한된 재사용 RTL 구현·수정·검증 작업에 적용한다.

## 2. 입력과 선행 조건

기능 방정식·수치/overflow, clock/reset·handshake·error/cancel/retry, 입력 snapshot, memory latency/write mode·banking, throughput/resource와 source roots.

## 3. 상세 처리 절차

1. legal/illegal transaction·수치·진단·reset recovery를 계약화한다.

2. 기존 구현의 폭·지연·reset·accept/done을 비교하고 가능한 변경은 명시적 adapter로 분리한다.

3. 합성 가능한 bounded RTL과 파라미터 검사를 구현한다.

4. top부터 모든 reachable module이 정확히 하나 정의되는지 검사하고 repository와 packaged source를 모두 elaborate한다.

5. 단위·경계·수치·reset·stall·retry·실제 이웃 연동을 검증한다.

6. OOC의 black box/latch/memory mapping·resource를 확인하고 재사용 integration packet을 제출한다.

## 4. 출력과 산출물

RTL/TB, contract summary, source manifest/hash, golden/cycle 증거, command/version/log, OOC·resource observations와 board 위험.

파일명은 원본 Skill과 작업 패킷의 지정에 따른다. 산출물 목록은 생성 의무/형식을 설명하며 기존 파일 존재를 주장하지 않는다.

## 5. 완료 및 검증 기준

TB 관찰이 실제 변경 경로와 연결되어야 한다. attention/KV는 동일 입력과 cache image에서 새 결과 및 이전 state 보존을 비교한다. OOC는 보드 검증과 구분한다.

## 6. 책임 경계와 실패 처리

보드 배포 판정은 board Skills에 인계한다. 기대값 약화나 source 변경 후 과거 BIT/HWH 사용을 금지한다. 독립 검증이 필요한 multi-agent 경로에서는 역할별 감사 Skill을 대체하지 않는다.

## 7. 연계 Skills

- [fpga-systemverilog](fpga-systemverilog.md)
- [fpga-vivado](fpga-vivado.md)
- [hdl-module-implementation](hdl-module-implementation.md)
- [hdl-module-verification](hdl-module-verification.md)
- [hdl-board-wrapper-signoff](hdl-board-wrapper-signoff.md)
- [fpga-board-build-signoff](fpga-board-build-signoff.md)

## 8. 적용 예시

KV writeback adapter를 수정할 때 payload뿐 아니라 기존 token 불변, scale/value 함께 commit, error 시 invalid snapshot을 검사한다.

## 9. 현재 적용 시 유의점

지원 자료: [verification-matrix.md](../../skills/hdl-generation-verification/references/verification-matrix.md). 원본은 board-build로 직접 인계를 표현하지만 보드 wrapper 구성·감사는 해당 역할 Skill에서 별도로 구분한다.

[전체 Skill 명세 목차](../skills_specification.md) · [공통 계약과 운영 규칙](../skills_overview.md)

