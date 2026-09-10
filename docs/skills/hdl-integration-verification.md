# hdl-integration-verification 명세서

독립 통합 감사

- 기준: 2026-09-08 프로젝트 지침
- 원본: [SKILL.md](../../skills/hdl-integration-verification/SKILL.md)
- 문서 성격: 현재 Skill의 동작 명세이며, 아래 사례는 적용 예시로 실제 검증 결과가 아니다.

## 1. 목적과 적용 조건

실제 자식과 부모 제어가 연결된 통합 wave를 수정 없이 검증한다.

## 2. 입력과 선행 조건

자체 테스트를 통과한 통합 소스·TB; 각 child 독립 검증/OOC·hash·parameters; target/clock·memory·coverage.

## 3. 상세 처리 절차

1. exact top의 source closure와 모든 자식이 실제 RTL인지 확인한다.

2. parent→child 호출과 child→parent status를 동적으로 추적한다.

3. start/accept/done/release, 반복·stall·reset·계약된 retry와 output 안정성을 검사한다.

4. payload·scale·tag·mask·주소·layout을 독립 reference와 비교한다.

5. 통합 top 자체의 synthesis 및 패킷이 요구하는 route·resource·timing을 확인한다.

6. findings, promotion eligibility와 오류 소유자를 보고한다.

## 4. 출력과 산출물

integration_verification_report.json, integration_synthesis_report.json; 동적 child 증거·명령·raw logs·source identity.

파일명은 원본 Skill과 작업 패킷의 지정에 따른다. 산출물 목록은 생성 의무/형식을 설명하며 기존 파일 존재를 주장하지 않는다.

## 5. 완료 및 검증 기준

모든 소비 자식과 통합의 현재 증거가 일치해야 통과한다. 자식 단독 OOC로 새 부모·buffer·fanout의 timing을 대체할 수 없다.

## 6. 책임 경계와 실패 처리

RTL·테스트·계약·구현 report를 수정하지 않는다. wiring 문제는 통합 담당, child 기능 문제는 child 담당, timing은 timing Skill과 해당 구현 담당으로 반환한다.

## 7. 연계 Skills

- [fpga-systemverilog](fpga-systemverilog.md)
- [fpga-vivado](fpga-vivado.md)
- [hdl-kernel-contract-gates](hdl-kernel-contract-gates.md)
- [hdl-vivado-timing-closure](hdl-vivado-timing-closure.md)
- [hdl-integration-agent](hdl-integration-agent.md)
- [hdl-module-verification](hdl-module-verification.md)

## 8. 적용 예시

두 자식의 독립 완료 이벤트를 통합 FSM이 놓치는지 동적 테스트하고, sticky capture와 release 조건이 실제로 관측되는지 확인한다.

## 9. 현재 적용 시 유의점

하드웨어 spec 또는 child hash가 바뀌면 기존 통합 증거를 stale로 처리한다.

[전체 Skill 명세 목차](../skills_specification.md) · [공통 계약과 운영 규칙](../skills_overview.md)

