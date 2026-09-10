# hdl-integration-agent 명세서

검증된 자식의 통합 구현

- 기준: 2026-09-08 프로젝트 지침
- 원본: [SKILL.md](../../skills/hdl-integration-agent/SKILL.md)
- 문서 성격: 현재 Skill의 동작 명세이며, 아래 사례는 적용 예시로 실제 검증 결과가 아니다.

## 1. 목적과 적용 조건

검증된 모듈을 레이어·토큰 루프·모델 FSM 또는 누적 단계로 연결한다.

## 2. 입력과 선행 조건

자식별 top/source hash/parameters, interface·cycle·memory 계약, 독립 검증과 OOC, integration packet·coverage·허용 수정 범위.

## 3. 상세 처리 절차

1. 모든 소비 자식의 현재 검증과 설정을 고정하고 누락 증거를 부모에게 반환한다.

2. 부모 FSM, 허용 adapter, local buffer/routing/arbitration과 status/error 연결을 작성한다.

3. payload·scale·mask·tag·주소 순서와 latency·backpressure 정렬을 보존한다.

4. held start/done의 실행·release·재사용을 구현하고 실제 자식으로 반복 테스트한다.

5. 연결·수치·stall·reset·회귀를 self-checking 통합 TB로 검사한다.

6. child manifest, 구현 증거와 남은 범위를 독립 통합 검증에 인계한다.

## 4. 출력과 산출물

통합 RTL/generator, TB·reference, raw logs, 정확한 child manifest/hash/configuration, kernel_report.json, subagent_result.json.

파일명은 원본 Skill과 작업 패킷의 지정에 따른다. 산출물 목록은 생성 의무/형식을 설명하며 기존 파일 존재를 주장하지 않는다.

## 5. 완료 및 검증 기준

자체 통합 테스트 통과는 독립 검증 준비 상태다. 실물·배포 승인이나 full-model 통과로 확대하지 않는다.

## 6. 책임 경계와 실패 처리

자식 RTL·부모 orchestration·독립 report·최종 board artifacts를 수정하지 않는다. 검증된 자식 변경이 필요하면 부모에게 revision과 재검증을 요청한다.

## 7. 연계 Skills

- [fpga-systemverilog](fpga-systemverilog.md)
- [fpga-vivado](fpga-vivado.md)
- [hdl-kernel-contract-gates](hdl-kernel-contract-gates.md)
- [hdl-integration-verification](hdl-integration-verification.md)

## 8. 적용 예시

quantizer 출력 packing과 GEMM 입력 word의 차이를 계약상 adapter로 연결하고 scale과 payload가 같은 transaction인지 검증한다.

## 9. 현재 적용 시 유의점

Board Design의 scheduler/Fabric/mover/compute/router/memory 역할을 하나의 불투명 custom IP로 합치지 않는다.

[전체 Skill 명세 목차](../skills_specification.md) · [공통 계약과 운영 규칙](../skills_overview.md)

