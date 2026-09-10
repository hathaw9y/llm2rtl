# fpga-incremental-bringup 명세서

핵심 구성부터 누적 확장

- 기준: 현재 프로젝트 지침
- 원본: [SKILL.md](../../skills/fpga-incremental-bringup/SKILL.md)
- 문서 성격: 현재 Skill의 동작 명세이며, 아래 사례는 적용 예시로 실제 검증 결과가 아니다.

## 1. 목적과 적용 조건

실제로 동작하는 최소 가속기를 시작으로 모듈을 추가하며 단계별 사용자 FPGA 확인을 관리한다. 모든 커널을 먼저 만드는 방식 대신 누적 bring-up을 요청받을 때 적용한다.

## 2. 입력과 선행 조건

Parent가 추출·검토한 model_graph.json, 필수 module_mapping.json과 검증 범위; 전체 모델 목표·보드 profile·수치 기준; 재사용 IP; 이전 사용자 통과 baseline과 build identity; 단계별 자원·성능 목표.
bringup.json 생성 전에는 정확한 매핑에 대한 사용자 승인 기록
module_mapping_approval.json과 그 해시가 필요하다. 승인 전 bring-up 초안도 금지한다.

## 3. 상세 처리 절차

1. 사용자 매핑 승인이 없으면 `awaiting_user_mapping_approval`에서 멈춘다. 승인 후 `--before-bringup`에 정확한 매핑·승인 해시를 전달해 통과한 뒤에만 첫 core와 누적 단계를 구성한다.

2. [모델 그래프·계획 규칙](../model_graph_bringup.md)에 따라 module_mapping.json의 경로·해시와 모듈 ID를 참조하고 누적 coverage, reference, 체크포인트를 bringup.json에 기록한다. 매핑 본문은 복제하지 않는다. DDR 전송이 있으면 제공 DataMover Engine·adapter·로컬 메모리·최소 scheduler를 포함한다. 계획 작성·참조 검사는 계약 freeze와 배정보다 먼저 수행한다.

   매핑에 사용자 승인이 없으면 `awaiting_user_mapping_approval`에서 기다린다.
   승인 후 계획을 처음 생성하며 별도 `module_mapping_approval` 참조를 기록한다.
   단계 선택 없는 계획 검사와 소비 검사 모두 별도 approval 해시도 전달한다.
   매핑이 변경되면 다시 승인받으며 이 승인은 각 단계의 사용자 FPGA 확인과 별개다.

3. 이전 통과 소스·계약·파라미터·빌드·테스트를 고정하고 이번 단계의 구현·독립 검증을 배정한다.

4. 검증된 자식으로 누적 통합하고 새 기능 및 이전 단계 회귀를 확인한다.

5. 현재 단계의 보드 구성을 빌드하고 정확한 산출물을 hardware-validation으로 인계한다.

6. awaiting_user_hardware_validation에서 기다린 뒤 결과에 따라 accepted 또는 failed/blocked를 기록한다.

## 4. 출력과 산출물

bringup.json; graph/mapping/bringup 해시와 stage ID에 연결된 단계별 소스/build/evidence; 보존된 accepted baseline; 부모 feedback·retry와 acceptance 기록. 배정·승격 전 별도 계획 gate와 계약 gate를 실행한다. 확정 계획은 보존하고 진행 상태는 기존 parent_loop_state.json과 stage evidence에 기록한다. 과거 bringup_plan.json은 보존하여 이전하되 현재 계획을 이중 관리하지 않는다.

파일명은 원본 Skill과 작업 패킷의 지정에 따른다. 산출물 목록은 생성 의무/형식을 설명하며 기존 파일 존재를 주장하지 않는다.

## 5. 완료 및 검증 기준

도구 검증, 보드 산출물 조건과 사용자 필수 실물 확인이 모두 충족되면 다음 의존 단계로 진행한다. 최종 완료는 요청한 전체 기능의 누적 사용자 검증까지 포함한다.

## 6. 책임 경계와 실패 처리

모든 설계의 첫 모듈을 GEMM으로 고정하지 않는다. 이전 baseline을 덮어쓰거나 미검증 단계를 완료 처리하지 않는다. 인터페이스 변경은 영향받는 자식·통합·빌드를 재검증한다.

## 7. 연계 Skills

- [multi-agent-hdl-generation](multi-agent-hdl-generation.md)
- [parent-module-decomposition](parent-module-decomposition.md)
- [hdl-module-implementation](hdl-module-implementation.md)
- [hdl-module-verification](hdl-module-verification.md)
- [hdl-integration-agent](hdl-integration-agent.md)
- [hdl-integration-verification](hdl-integration-verification.md)
- [hdl-board-wrapper-signoff](hdl-board-wrapper-signoff.md)
- [fpga-board-build-signoff](fpga-board-build-signoff.md)
- [fpga-hardware-validation](fpga-hardware-validation.md)

## 8. 적용 예시

사용자 확인을 통과한 GEMM 가속기 위에 quantizer를 추가한다. 새 데이터 경로와 기존 GEMM 회귀 모두 확인한 bitstream을 다시 전달한다.

## 9. 현재 적용 시 유의점

상태는 planned, implementing, tool_verification, building, awaiting_user_hardware_validation, accepted, failed, blocked이다. 부분 구성의 route 통과가 full-model 증거가 되지는 않는다.

[전체 Skill 명세 목차](../skills_specification.md) · [공통 계약과 운영 규칙](../skills_overview.md)
