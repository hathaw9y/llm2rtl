# multi-agent-hdl-generation 명세서

부모 에이전트의 작업 조율

- 기준: 현재 프로젝트 지침
- 원본: [SKILL.md](../../skills/multi-agent-hdl-generation/SKILL.md)
- 문서 성격: 현재 Skill의 동작 명세이며, 아래 사례는 적용 예시로 실제 검증 결과가 아니다.

## 1. 목적과 적용 조건

모델·FPGA 입력에서 모듈 구현, 독립 검증, 통합, 보드 단계까지 역할과 의존성을 조율한다. 부모 에이전트가 전체 생성 작업을 맡을 때 적용한다.

## 2. 입력과 선행 조건

모델·하드웨어·최적화 요구사항; 현재 모델별 부모 상태와 기존 모듈 증거; 목표 coverage와 허용 재귀 분해 정책.

## 3. 상세 처리 절차

모델 기반 요청은 [모델 그래프·계획 규칙](../model_graph_bringup.md)에 따라
Parent의 model_graph.json 추출·검토 → 필수 module_mapping.json → 사용자 승인 대기·기록
→ 생성 전 승인 gate → 참조형 bringup.json 생성·검토 → 계획·승인 검사 → 단계별 계약 → 배정
순서를 먼저 적용한다. 아래 wave는 현재 단계 범위에서 수행하며 의존 단계는 사용자
하드웨어 체크포인트를 건너뛰지 않는다. graph/mapping/bringup 신원과 coverage를 독립
검증에도 전달한다. 배정·승격 전 계획 gate와 계약 gate를 별도로 실행하며 매핑 본문은
bring-up에 복제하지 않는다. 두 gate PASS도 의미·수치·선행 사용자 결과 검토를 대체하지 않는다.
매핑 구성·검토 후 사용자에게 제시하고 `awaiting_user_mapping_approval`에서 기다린다.
승인 전 bring-up은 검토용 초안도 생성하지 않으며 구현 계약 freeze·구현 배정도 금지한다.
승인 후 `--before-bringup`을 통과한 뒤 생성하며 계획에 별도 승인 참조를 남긴다.
실제 승인 후 `module_mapping_approval.json`을 매핑 해시에 묶고 그 경로·해시도
packet에 전달한다. 매핑 변경에는 재승인이 필요하며 사용자 반려·철회는 과거 기록보다 우선한다.

1. 입력을 parent-module-decomposition에 연결해 모듈 경계와 패킷을 확정한다.

2. 각 작업에 필요한 역할 Skill을 프로젝트에서 확인한다. 누락 시 시스템 skill-creator로 생성·검증·동기화한 후 패킷을 갱신한다.

3. 의존성이 충족된 작업을 하위 에이전트에 배정한다. 구현 에이전트의 재귀 분해는 명시된 child policy와 depth를 따른다.

4. 구현 결과와 독립 감사 결과를 수집하고 누락·실패·허용 coverage를 판단한다.

5. 누적 확장은 fpga-incremental-bringup으로, 사용자 실물 확인은 fpga-hardware-validation으로 연결한다.

6. 재시도 소유자와 다음 행동을 갱신하며 전체 목표 완료까지 추적한다.

## 4. 출력과 산출물

parent_loop_state.json, feedback_packet.json, retry_plan.json, hdl_subagent_spawn_ledger.json; 필요한 child contract manifest와 작업 배정 기록.

파일명은 원본 Skill과 작업 패킷의 지정에 따른다. 산출물 목록은 생성 의무/형식을 설명하며 기존 파일 존재를 주장하지 않는다.

## 5. 완료 및 검증 기준

의존 작업의 필수 증거가 통과해야 다음 wave를 시작한다. full-target 산출물은 실제 target-scale 자식과 해당 coverage를 요구한다. 부분 단계의 bitstream은 해당 단계 범위로만 인정한다.

## 6. 책임 경계와 실패 처리

부모는 RTL을 직접 작성하지 않는다. 독립 검증 에이전트를 구현자로 암묵 전환하지 않는다. 실패는 증거와 함께 해당 소유자로 반환하며 재사용 가능한 교훈만 Skill로 승격한다.

## 7. 연계 Skills

- [parent-module-decomposition](parent-module-decomposition.md)
- [fpga-incremental-bringup](fpga-incremental-bringup.md)
- [hdl-module-implementation](hdl-module-implementation.md)
- [hdl-module-verification](hdl-module-verification.md)
- [hdl-integration-agent](hdl-integration-agent.md)
- [hdl-integration-verification](hdl-integration-verification.md)
- [hdl-board-wrapper-signoff](hdl-board-wrapper-signoff.md)
- [fpga-hardware-validation](fpga-hardware-validation.md)

## 8. 적용 예시

최소 GEMM 구성의 자식 구현 결과를 모은 뒤 독립 검증과 보드 빌드를 배정한다. 사용자 결과가 없으면 다음 누적 모듈 구현을 시작하지 않는다.

## 9. 현재 적용 시 유의점

부모는 사용 환경에서 제공하는 에이전트 도구로 작업을 배정하고 결과를 수집한다.
계약 처리와 Skill 동기화 스크립트는 제공하지만 전체 E2E runner는 포함하지 않는다.

[전체 Skill 명세 목차](../skills_specification.md) · [공통 계약과 운영 규칙](../skills_overview.md)
