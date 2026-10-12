# 공통 계약의 적용 범위

새 설계의 bank 소유권 지침은 [방향별 소유권 규칙](../../docs/framework_workflow.md)을 따른다.
읽기·쓰기 owner와 획득·해제를 분리하고 commit/data availability를 별도로 확인한다.

현재 `local_bank_contract.json`(v2)와 `isa_command_contract.json`(v1)은 이전
single-exclusive·command acceptance와 같은 cycle 예약 방식의 동결 호환 계약이다.
과거 모델을 재현할 때 사용하며 새 방향별 설계에 자동 적용하지 않는다.
새 revision의 `bank_layout.json`, ISA 및 모듈 계약에 방향별 규칙·cycle·원자적 예약과
검증 기준을 명시한다. 기존 JSON을 덮어쓰거나 검사기의 PASS를 방향별 검증으로 보고하지 않는다.

새 설계는 `designs/<revision>/structure_contract.json`에 모듈 경계·실제 연결·재사용·
방향별 ownership·Weight stripe 공급·executor 파이프라인과 구조 의무별 검사를 기록한다.
구현·검증 Agent는 동작 계약과 이 구조 계약을 함께 사용한다.
기존 ISA·bank·수치 계약을 참조해 중복을 줄이고 동결된 과거 JSON은 보존한다.
작성 방법은 [구조 계약 지침](../../docs/structure_contract.md)을 따른다.

`check_common_contracts.py`·`check_isa_design.py`는 이전 호환 계약의 검사기다.
새 방향별 설계의 machine-readable schema와 검사기는 해당 revision에서 준비해야 한다.
구조 계약의 적합성 검사도 별도 범위이며 기존 검사기의 PASS로 대체하지 않는다.
`engine_completion_contract.json`의 memory drain·정확히 한 번 완료·실제 역할 해제 원칙과
`evidence_identity_contract.json`의 증거 identity는 적용 가능한 범위에서 함께 확인한다.
