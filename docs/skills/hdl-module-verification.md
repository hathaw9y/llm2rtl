# hdl-module-verification 명세서

독립 모듈 감사

- 기준: 2026-09-08 프로젝트 지침
- 원본: [SKILL.md](../../skills/hdl-module-verification/SKILL.md)
- 문서 성격: 현재 Skill의 동작 명세이며, 아래 사례는 적용 예시로 실제 검증 결과가 아니다.

## 1. 목적과 적용 조건

구현 모듈을 소스 수정 없이 감사해 상위 통합에 사용할 수 있는지 판단한다.

## 2. 입력과 선행 조건

정확한 DUT top·source manifest/hash·parameters; 기능·수치·cycle·memory 계약; TB·golden·raw logs; kernel/subagent/OOC 결과와 활성 target.

## 3. 상세 처리 절차

1. 각 요구사항을 테스트·assertion·report 또는 명시적 blocker에 연결한다.

2. 실제 compile/sim/synth 소스의 identity와 transitive closure를 확인한다.

3. handshake·reset·폭·부호·지연·tail·overflow와 실제 payload 비교를 감사한다.

4. 필요한 권한과 환경 내에서 elaboration, lint, simulation 또는 OOC를 재실행한다.

5. 원시 timing/resource 결과와 보고서 주장을 비교하고 fixture/target 범위를 분류한다.

6. 심각도 순 findings, status, promotion eligibility와 retry owner를 반환한다.

## 4. 출력과 산출물

module_verification_report.json 또는 패킷이 지정한 동등 보고서; 명령·exit status·raw evidence·findings·범위·위험.

파일명은 원본 Skill과 작업 패킷의 지정에 따른다. 산출물 목록은 생성 의무/형식을 설명하며 기존 파일 존재를 주장하지 않는다.

## 5. 완료 및 검증 기준

필수 요구사항과 현재 identity의 증거가 만족되면 passed를 보고한다. 누락 증거·도구 부재·stale 자료는 failed/blocked이며 통과를 추정하지 않는다.

## 6. 책임 경계와 실패 처리

RTL·TB·계약·구현 증거를 수리하지 않는다. timing 진단을 해도 실제 수정은 구현 담당에게 반환한다. P0/P1/P2/P3 분류는 이 Skill의 정의를 따른다.

## 7. 연계 Skills

- [hdl-kernel-contract-gates](hdl-kernel-contract-gates.md)
- [fpga-systemverilog](fpga-systemverilog.md)
- [fpga-vivado](fpga-vivado.md)
- [hdl-vivado-timing-closure](hdl-vivado-timing-closure.md)
- [hdl-module-implementation](hdl-module-implementation.md)

## 8. 적용 예시

TB가 done만 검사하면 수치 correctness 증거가 부족하다고 반환하고 golden과 DUT payload 비교가 추가된 후 다시 감사한다.

## 9. 현재 적용 시 유의점

소스 해시가 다른 과거 OOC나 낮은 resource 수치만으로 target-scale 구현을 인정하지 않는다.

[전체 Skill 명세 목차](../skills_specification.md) · [공통 계약과 운영 규칙](../skills_overview.md)

