# 최소 계약 구조

새 설계는 네 공통 계약만 공유한다.

- `common/isa_command_contract.json`: 명령·응답과 opcode operand 경계.
- `common/local_bank_contract.json`: 논리 bank와 ownership 안전 규칙.
- `common/evidence_identity_contract.json`: revision·source·test·artifact 신원.
- `common/engine_completion_contract.json`: 읽기 응답 처리·쓰기 수락 후 engine 완료 응답으로 bank 해제.

새 생성물은 네 계약을 pin한다. 기존 세 계약만 pin한 revision은 원래 경계를
유지하며 새 완료 계약 PASS를 상속하지 않는다.

모델이나 모듈에 따라 달라지는 값은 공통 계약에 넣지 않는다. 새 revision은
`designs/<revision>/`에 `model_trace.json`, `isa_spec.json`, `bank_layout.json`,
`isa_validation.json`을 두고 구현을 시작한 opcode만 `modules/<module_id>.json`으로
계약화한다. Opcode를 실행하지 않는 command dispatcher 같은 필수 infrastructure도
동일한 module contract와 hash pin을 사용하되, opcode를 소유한다고 표기하지 않고
route하는 opcode 목록만 선언한다. 과거 계약 체계는 repository 밖 backup에 보존되어 있으며 새 설계가
참조하거나 과거 PASS를 상속하지 않는다.

공통 계약이 개정될 때 이전 exact content는 `contracts/history/<sha256>/`에 보존한다.
과거 revision의 보고서는 당시 기록한 hash에만 적용되며 현재 공통 계약 PASS로 다시
표시하지 않는다.

공통 계약 검사:

```bash
python3 scripts/check_common_contracts.py
```

설계 검사:

```bash
python3 scripts/check_isa_design.py --design-dir designs/<revision>
```

검사 PASS는 JSON 구조와 선언 신원만 증명한다. 모델 수치 정확도, RTL 동작,
Vivado 결과 또는 FPGA 실행을 증명하지 않는다.
