# parent-module-decomposition 명세서

입력 해석과 모듈 계약 분해

- 기준: 현재 프로젝트 지침
- 원본: [SKILL.md](../../skills/parent-module-decomposition/SKILL.md)
- 문서 성격: 현재 Skill의 동작 명세이며, 아래 사례는 적용 예시로 실제 검증 결과가 아니다.

## 1. 목적과 적용 조건

사용자 목표를 독립적으로 구현·검증할 수 있는 최소 HDL 패킷으로 변환한다. 모델, 최적화, 하드웨어와 설계 방법론을 해석하거나 통합 전 모듈 경계를 검토할 때 적용한다.

## 2. 입력과 선행 조건

모델 config·정확한 코드/revision·실행 조건(prefill/decode, shape, KV cache 등); 수치/희소 정책; 보드 inventory와 프로젝트 예산; 처리량·클럭·오차 기준; 기존 IP와 검증 환경.

## 3. 상세 처리 절차

선행 필수 단계: [모델 그래프·계획 규칙](../model_graph_bringup.md)을 읽고 Parent가
`model_graph.json`을 추출·검토한다. 노드·텐서·state와 코드 신원을 기록하고 정적 검토와
실행 비교의 증거를 구분한다. 필수 `module_mapping.json`에 노드→모듈 대응·공유/융합/
분할·수치 변환과 검증 근거를 기록한 뒤, 정확한 파일·해시와 읽을 수 있는 요약을
사용자에게 제시한다. `awaiting_user_mapping_approval`에서 명시적 승인을 기다리고,
실제 요청/응답을 별도 `module_mapping_approval.json`에 기록한다. 승인 후
`--before-bringup` 승인 gate를 통과한 뒤 `fpga-incremental-bringup`으로
`bringup.json`을 생성한다. 승인 전에는 bring-up 초안도 만들지 않는다.
bring-up은 매핑 본문 대신 경로·SHA-256을 참조하고 별도 승인 참조도 기록한다. 계획·승인 검사를 거쳐 아래 계약
분해를 진행하고, 배정·승격 전 계획 gate와 계약 gate를 별도로 실행한다. packet에는
graph/mapping/bringup 해시와 stage/module ID를 함께 전달한다. 단독 커널도
`scope: operator`의 매핑을 작성하되 가짜 모델 그래프는 만들지 않는다.

1. compute_style, execution_style, memory_style, control_style의 네 축을 구분하고 자유 형식의 선택 근거도 보존한다.

2. 부족한 정보가 경계·수치·예산에 영향을 주면 input_clarification_questions.json으로 확인한다. 초기 확인 질문에서는 허용 수치 오차를 묻지 않는다. 모듈 계약의 오차 기준과 기존 검증 합격 기준은 유지한다.

3. 상주 가능성을 packed-byte 용량으로 계산하고, streaming 선택 시에도 실제 tile·metadata buffer를 정의한다.

4. 연산 종류·데이터 이동·병목·재사용·독립 검증 가능성을 기준으로 root/child 계약 트리를 만든다.

5. 각 패킷에 포트·cycle·수치·메모리·검증·수정 범위·tuning knobs·재귀 정책을 배정한다.

6. 통합 전 현재 자식의 source/configuration, OOC와 실제 downstream payload를 검토한다.

## 4. 출력과 산출물

model_graph.json, 필수 module_mapping.json, 실제 사용자 결정 후 module_mapping_approval.json,
참조형 bringup.json(누적 계획 Skill 연계), 아키텍처 계약 트리, module_packet.json,
interface/memory/verification 계약, child_contract_manifest; 부모 상태·feedback·retry 갱신.

파일명은 원본 Skill과 작업 패킷의 지정에 따른다. 산출물 목록은 생성 의무/형식을 설명하며 기존 파일 존재를 주장하지 않는다.

## 5. 완료 및 검증 기준

핵심 입력이 확정되고 패킷 경계와 검증 방법이 실행 가능해야 구현에 배정한다. 통합은 현재 하드웨어와 설정에 대응하는 자식 증거를 요구한다.
매핑의 `reviewed`와 계획 구조 PASS는 수치 검증 완료가 아니다. 부족한 정보는
`draft`/`blocked`와 명시적 사유로 남기며, 일반 질문·입력 확인만 할 때 파일을 강제로 생성하지 않는다.
`reviewed`는 사용자 승인도 아니다. 승인 없는 구현 계약 freeze·구현 배정은 금지하며,
수정 요청은 새 매핑으로 반영해 다시 확인받는다. 승인은 정확한 매핑 해시에 한정되고
수치 검증·사용자 하드웨어 체크포인트를 면제하지 않는다.

## 6. 책임 경계와 실패 처리

직접 RTL을 작성하지 않는다. compute IP에 AXI/DDR 제어를 숨기지 않는다. model_scheduler는 자체 반복과 load/compute/drain 의사결정을 가져야 한다. 초기 correctness-first와 최종 board-fit을 구분한다.

## 7. 연계 Skills

- [multi-agent-hdl-generation](multi-agent-hdl-generation.md)
- [fpga-incremental-bringup](fpga-incremental-bringup.md)
- [fpga-ddr-pingpong-residency](fpga-ddr-pingpong-residency.md)
- [fpga-quantization](fpga-quantization.md)
- [zcu104-xczu7ev-hardware](zcu104-xczu7ev-hardware.md)

## 8. 적용 예시

Attention을 projection, RoPE, KV 이동, Softmax, AV 및 제어 패킷으로 나누고 Q/K/V/O projection의 공통 IP 재사용을 검토한다.

## 9. 현재 적용 시 유의점

보드 용량은 generic Skill에 고정하지 않는다. 특정 모델에서 선택한 shape나 precision을 전체 프레임워크 규칙으로 일반화하지 않는다.

[전체 Skill 명세 목차](../skills_specification.md) · [공통 계약과 운영 규칙](../skills_overview.md)
