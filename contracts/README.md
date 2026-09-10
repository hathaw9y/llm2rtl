# 계약 구성

- 루트 `*.json`: 구현과 무관하게 유지하는 책임 분담·검증 원칙.
- `templates/`: 설계별 값을 작성하는 초안 양식. 실행 가능한 계약이나 기본값이 아님.
- `designs/<design_id>/<revision>/`: 부모가 설계별로 생성·확정하는 계약. Git 기본 배포에는 포함하지 않음.
- `schemas/`: 대응하는 문서 형식의 스키마. 현재 kernel variant 스키마만 있으며 새 템플릿의 자동 검증 스키마는 아님.

부모 LLM은 적용할 루트 정책을 읽고 `init`으로 새 design/revision 폴더와 계약
초안을 생성한 뒤 값을 작성합니다. 일반 사용자는 입력 명세와 생성 요청을 전달하며,
계약 명령이나 JSON을 직접 작성할 필요가 없습니다. 모듈별 계약은 그 아래
`modules/<module_id>/`에 둡니다.
`contract_index.json`에 정확한 상대 경로와 적용 범위를 기록하고, 구현·검증 담당에게
동일한 index를 전달합니다. 상대 경로 기준은 저장소 루트입니다.

모델 기반 생성은 계약 작성에 앞서 `model_graph.json` → 필수 `module_mapping.json`
→ 사용자 확인·승인 → 생성 전 승인 gate → 참조형 `bringup.json` 생성 순서로 진행합니다.
승인 전 bring-up은 초안도 생성하지 않습니다. Parent의 `reviewed`만으로는 확정이 아닙니다.
승인 전 `init`으로 보관 경로·초안을 준비할 수 있지만 구현 계약 freeze와 구현 배정은
금지합니다. 매핑은 하드웨어 설계 결정의 근거이며
확정된 모듈 계약의 대체물이 아닙니다. [계획 규칙 및 검사](../docs/model_graph_bringup.md)에
따라 Parent가 `scripts/check_planning.py`를 별도로 실행합니다. `init`은 계획 파일을
생성하지 않으며 `freeze/check`는 이 계획 검사기를 자동 호출하지 않습니다.
계약 gate PASS만으로 매핑 누락·불일치를 무시하거나 관련 작업을 배정할 수 없습니다.
사용자 승인은 별도 `module_mapping_approval.json`에 정확한 매핑 경로·해시와 실제
요청/응답 근거를 기록합니다. Parent의 `freeze --approved-by`는 사용자 매핑 승인을
대신하지 않습니다. freeze 전과 소비 시 계획 검사에 매핑·승인 기대 해시를 전달하고,
매핑 변경 시 사용자에게 변경안을 다시 확인받습니다.

`null`은 미결정 값이며 0, 기본값 또는 검사 생략을 뜻하지 않습니다. 적용하지 않는
항목은 `{"not_applicable": true, "reason": "구체적인 이유", "approved_by": "부모 식별자"}`로
명시합니다. 필요한 값과 검증 계획을 채운 뒤 부모가 `freeze`를 실행하기 전에는
RTL 구현 입력으로 사용하지 않습니다. status만 수동 변경해도 해시가 없거나
맞지 않으면 소비 검사를 통과하지 못합니다.

변경 시 기존 계약·소스·증거를 보존하고 새 revision을 만들며, index 경로와
영향받는 소비자를 갱신하고 재검증합니다. 기존 정책 경로는 유지했지만 내용은
정책 전용으로 변경했습니다. 상세 수치·배치가 필요하면 반드시 design index를
통해 실행별 계약을 읽어야 합니다.

## 기본 실행 주체

부모 LLM이 `init` 실행 → 계약 내용 작성·검토 → `freeze` 실행 → index와 SHA를
작업 packet에 전달합니다. 구현·검증 담당은 `check`를 실행하고 반환된 계약을
읽습니다. 입력이 부족하면 부모가 사용자에게 확인하며, 도구가 설계 내용을
자동으로 추론하거나 사용자의 별도 권한을 부여하지는 않습니다.

## 개발·디버깅용 수동 명령

아래 명령은 에이전트 내부 절차를 재현하거나 문제를 진단할 때 사용하는 예시입니다.
일반 사용자에게 필수 수동 단계가 아닙니다. 저장소 루트에서 실행합니다.

```sh
python3 scripts/design_contracts.py init --design-id demo --revision r01 --hardware-profile config/hardware/zcu104.json --module gemm
```

반환된 index 및 각 계약의 미결정 값을 작성합니다. `module_contracts`는 모듈 ID와
`modules/<id>/contract.json`을 연결합니다. 모듈 계약의 interface/numeric/memory/
verification 등은 inline 내용이며, variant 검사 대상이면 `variant` 객체도 inline으로
추가합니다. 파일 경로를 자유 서술 문자열에 쓰는 것만으로 그 파일까지 해시로
묶이지 않습니다. 아래 필수 DataMover 의존성은 예외로 자동 해시됩니다.
나머지 외부 RTL·TB·빌드 소스의 closure는 후속 검증 단계 책임입니다.

```sh
python3 scripts/design_contracts.py freeze --index contracts/designs/demo/r01/contract_index.json --approved-by parent
python3 scripts/design_contracts.py check --index contracts/designs/demo/r01/contract_index.json --expected-sha256 RETURNED_SHA256 --module gemm
```

`RETURNED_SHA256`은 freeze 결과의 실제 index SHA-256으로 바꿉니다. 부모가 이 값을
작업 packet으로 전달하고 소비자는 스스로 계산한 값으로 대신하지 않습니다.
`check`는 파일을 쓰지 않고, 확인된 정책·하드웨어·계약 내용을 JSON으로 반환합니다.
동일 설계/버전, 템플릿 필수 필드, 미결정 값, 파일 존재, 안전한 경로와 symlink,
확정 상태, 정확한 파일 해시를 검사합니다. 정책·템플릿·하드웨어·job-control 문서
변경도 기존 bundle을 무효화합니다. 수정은 새 revision에서 진행합니다.

`freeze`는 기록된 부모 승인 선언이며 사용자 신원 인증이나 보안 서명 시스템은
아닙니다. 각 문서를 임시 파일에 쓰고 원자적으로 교체하며 index는 마지막에 같은
방식으로 교체합니다. 중간 쓰기 실패로
index가 draft이면 소비는 차단됩니다. 부모가 실패를 검토한 뒤 같은 `freeze`를
재실행하면 모든 문서를 다시 검사하고 완료할 수 있습니다. 계약 JSON 자체가
손상됐다면 원본 초안에서 복구하거나 새 revision을 만드세요. 동시 편집은 지원하지
않습니다. frozen index를 다시 freeze해 바뀐 파일에 맞추는 것은 금지됩니다.

이 도구는 **계약 구조·참조·일치성 gate**입니다. 자유 서술 내용의 타당성,
적용 제외 판단, RTL 동작이나 보드 결과를 증명하지 않습니다. 부모/독립 검증은
반환된 실제 내용을 읽고 의미와 구현을 비교해야 합니다.

## 필수 DataMover 선언

공통 `generation_policy.json`은 DDR↔로컬 메모리 전송에 제공된 DataMover Engine
재사용을 의무화합니다. 모델·보드에 따라 달라지는 연결은 부모가 생성한
`contracts/designs/<design>/<revision>/contract_index.json`의 `transport`에 작성합니다.
`init`은 이 필드를 `null`로 남기므로 판단 없이 freeze할 수 없습니다.

DDR를 사용하는 설계의 작성 예시입니다. endpoint는 실제 설계의 계층/인터페이스
이름으로 바꾸고, 양방향 인터페이스는 해당 인터페이스 묶음의 연결을 적습니다.

```json
{
  "ddr_local_transfers": true,
  "engine": "ip/infrastructure/datamover_engine",
  "interface_contract": "ip/infrastructure/datamover_engine/interface_contract.json",
  "command_owner": "model_scheduler",
  "error_policy_owner": "model_scheduler",
  "connections": {
    "command": {"source": "top.scheduler.dm_command", "sink": "top.dm_engine.command"},
    "completion": {"source": "top.dm_engine.status", "sink": "top.scheduler.dm_status"},
    "ddr": {"source": "bd.axi_datamover.M_AXI", "sink": "bd.ps.S_AXI_HP"},
    "local_memory": {"source": "top.dm_adapters.bank_ports", "sink": "top.bank_arbiter.dm_ports"}
  },
  "integration_verification": "Compare elaborated hierarchy and source manifest with these endpoints; test scheduler commands, returned tags, descriptor errors, backpressure and coordinated recovery."
}
```

모듈의 inline `variant.external_transfers` 항목도 `transport: "datamover_engine"`,
`direction: "ddr_to_local"` 또는 `"local_to_ddr"`로 선언합니다.
`verification/framework/fixtures/`의 standalone fixture도 현재 transport 명칭을
사용하지만 검사 도구용 입력일 뿐, 실제 설계나 하드웨어 검증 증거는 아닙니다.

DDR 전송이 없는 설계는 아래처럼 선언합니다. 하위 모듈이 local-only여도 전체 설계가
DDR 전송을 포함하면 전체 index에는 `true`를 사용해야 합니다.

```json
{"ddr_local_transfers": false, "reason": "DDR 없이 local-memory 입력만 사용하는 독립 연산 모듈 검증"}
```

`freeze`와 모든 `check`는 이 선언을 검사합니다. DDR 설계에서는 Engine 인터페이스
계약과 명시된 18개 RTL 파일이 모두 존재해야 하며 frozen SHA-256 목록에 포함됩니다.
freeze 이후 소스 변경·누락은 소비를 차단합니다. scheduler의 명령/오류 처리 소유권,
필수 연결 endpoint, variant의 대체 엔진 선언도 검사하며 이 요구는 정책 적용 제외로
우회할 수 없습니다. 기존 bundle에는 필드가 없으므로 새 revision으로 이전해야 합니다.

이 검사는 **선언과 소스 신원**을 강제할 뿐 endpoint의 실제 존재나 RTL 동작을
증명하지 않습니다. 자유 서술이나 RTL에 숨은 DDR 접근을 자동 발견하지도 않습니다.
독립 통합 검증자는 모든 DDR 전송의 선언 누락 여부, 실제 Engine 인스턴스와 사용 소스,
vendor AXI DataMover·adapter·bank 배선, scheduler의 완료 및 오류 처리, 파라미터와
reset 연동을 구현·시뮬레이션 증거와 비교해야 합니다. 해당 증거 없이는 통합 PASS를
선언할 수 없습니다. vendor IP 생성과 보드 검증도 별도 단계입니다.
