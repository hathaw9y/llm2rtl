# hdl-module-implementation 명세서

제한된 HDL 모듈 구현

- 기준: 2026-09-08 프로젝트 지침
- 원본: [SKILL.md](../../skills/hdl-module-implementation/SKILL.md)
- 문서 성격: 현재 Skill의 동작 명세이며, 아래 사례는 적용 예시로 실제 검증 결과가 아니다.

## 1. 목적과 적용 조건

한 개의 계약 패킷을 구현하고 자체 검증한다. 구현 담당 하위 에이전트에 적용한다.

## 2. 입력과 선행 조건

module packet, functional/numeric/interface/memory 계약; 허용 수정 파일·tuning knobs·재귀 정책; board/clock와 golden·검증 조건.

## 3. 상세 처리 절차

1. 패킷의 역할과 입력·출력·cycle을 확인하고 기존 child reuse를 고정한다.

2. 큰 패킷은 허용된 경우 child 계약으로 분해하고 아니라면 부모에게 분해 요청을 반환한다.

3. RTL·golden·TB를 작성하며 compute/local-memory와 model_scheduler 책임을 보존한다.

4. 정상·경계·반복·해제·오류 등 계약별 self-checking 검증과 lint를 실행한다.

5. 실제 데이터패스는 OOC 합성으로 자원·timing을 측정하고 허용 knobs 범위에서 문제를 수정한다.

6. 변경 파일·명령·결과·남은 위험을 보고하고 독립 검증으로 인계한다.

## 4. 출력과 산출물

생성/수정 RTL 또는 generator, TB, golden, 원시 로그, kernel_report.json, subagent_result.json; 실제 datapath의 module_ooc_synthesis_report.json.

파일명은 원본 Skill과 작업 패킷의 지정에 따른다. 산출물 목록은 생성 의무/형식을 설명하며 기존 파일 존재를 주장하지 않는다.

## 5. 완료 및 검증 기준

패킷의 기능·interface 테스트와 필수 도구 결과가 있어야 구현 결과를 제출한다. 자체 검증 성공은 독립 promotion 완료와 다르다.

## 6. 책임 경계와 실패 처리

부모 상태·독립 감사 보고서·다른 모듈을 수정하지 않는다. 실패 계약이나 테스트를 약화하지 않는다. timing failure는 전용 Skill과 구현 소유자로 처리한다.

## 7. 연계 Skills

- [fpga-systemverilog](fpga-systemverilog.md)
- [fpga-vivado](fpga-vivado.md)
- [hdl-kernel-contract-gates](hdl-kernel-contract-gates.md)
- [hdl-module-verification](hdl-module-verification.md)
- [hdl-vivado-timing-closure](hdl-vivado-timing-closure.md)

## 8. 적용 예시

INT4 GEMM 패킷에서 명시된 packing과 누산 폭을 구현하고 extreme·tail·반복 start/done 테스트와 OOC 보고서를 제출한다.

## 9. 현재 적용 시 유의점

기본 인터페이스는 aclk/aresetn/start/done이며 프로젝트 계약을 함께 읽는다. busy는 현재 프로젝트에서 선택적 상태다.

[전체 Skill 명세 목차](../skills_specification.md) · [공통 계약과 운영 규칙](../skills_overview.md)

