# 모델 그래프 기반 누적 구현 계획

## 책임과 순서

모델 기반 생성에서는 Parent Agent가 다음 순서를 수행한다.

```text
모델 config + 정확한 모델 코드/revision + 실행 조건
    → model_graph.json 작성·정합성 확인
    → module_mapping.json 작성·검토 (FPGA 제약·최적화 요구 반영)
    → 사용자에게 매핑 제시 → 명시적 승인 대기
    → module_mapping_approval.json에 승인 기록
    → 매핑·승인 해시로 bring-up 생성 전 gate 통과
    → bringup.json 작성·검토·확정
    → 단계별 계약 작성·freeze
    → 구현·독립 검증·통합·보드 빌드·사용자 검증
```

`parent-module-decomposition`이 그래프 추출과 모듈 매핑을 담당하고,
Parent가 `fpga-incremental-bringup`으로 누적 구현 계획과 진행을 관리한다.
모델 기반 생성 계획은 승인 후 그래프·매핑·bring-up을 모두 갖춘다. 승인 대기 중에는
그래프와 매핑만 생성하며 `bringup.json`은 아직 없어야 한다. 매핑은 별도 파일에만 저장하며,
bring-up은 그 파일을 참조한다. 단순 질문·설명이나 입력 확인만 하는 단계에서까지
파일을 생성하지 않는다. 입력이 부족하면 기존 초안을 `draft`/`blocked`로 보존하고
확인 질문·남은 조건을 기록한다. 파일을 채우려고 설계 결정을 꾸며내지 않는다.
매핑 검토 후에는 `awaiting_user_mapping_approval`로 멈추고 사용자의 결정을 받는다.
승인 전에는 **bringup.json 생성 자체를 금지**한다. 검토용 초안도 예외가 아니다.
구현 배정·구현 계약 freeze도 하지 않는다. 매핑 수정·단독 구조 검사와 최종 보관
경로를 준비하는 `init`은 가능하지만 bring-up을 생성하거나 구현을 진행하지 않는다.
모델 코드를 읽는 것과 실행하는 것은 별개다. 외부 모델 코드를 자동 신뢰하거나
추출을 이유로 설치·다운로드·원격 코드 실행 권한을 확대하지 않는다.

## 모델 그래프 작성

`config.json`만으로 연산 그래프를 추정해 확정하지 않는다. 실제 forward 구현,
호출되는 연산과 설정 분기를 확인한다. 사용 가능한 추적/export 도구 또는 정적
분석을 선택하고 방법·도구 버전·한계를 기록한다. 특정 추출 명령은 강제하지 않는다.

prefill/decode, batch, sequence 범위, mask, KV cache 초기 상태와 갱신을 명시한다.
실행 경로가 다르면 graph ID를 분리한다. 반복 layer는 반복 횟수와 인스턴스 대응을
명시한 구조로 표현할 수 있으며, cache 순환은 초기 state와 다음 state로 구분한다.
한 입력으로 추적한 그래프를 모든 shape·분기에 대한 증거로 사용하지 않는다.

`model_graph.json`에는 다음 필드를 기록한다.

| 필드 | 내용 |
| --- | --- |
| `schema` | `llm2rtl.model_graph.v1` |
| `design_id`, `revision` | 설계·계획 버전 |
| `model` | 모델 ID·정확한 revision, config·모델 코드의 경로와 SHA-256, 관련 라이브러리 버전 |
| `extraction` | 분석/추적 방법, 실행 조건, 도구, 가정과 미지원 경로 |
| `graphs` | 고유 graph ID별 실행 모드, 입출력 tensor ID, 노드·텐서·상태 정의 |
| `validation` | `draft`/`blocked`/`validated`, 비교 방법, 테스트 입력 신원, 증거 경로·해시, 검토 주체와 제한 |

각 graph의 `nodes`에는 고유 ID, 연산 종류·속성, 입력/출력 tensor ID,
모델 코드 위치를 기록한다. `tensors`에는 고유 ID, shape(기호 차원과 범위 포함),
dtype, layout, activation/parameter/state 구분을 기록한다. weight와 KV cache를
상수 activation으로 취급하지 않는다. 지원 범위에서 unresolved operator나
누락된 tensor 연결이 있으면 `validated`로 표시하지 않는다.

가능한 환경에서는 원 모델과 추출 표현의 출력 및 필요한 중간값·state 갱신을
동일 입력으로 비교한다. 실행이 불가능하면 정적 검토 결과와 부족한 실행 증거를
분리한다. Parent가 정적 정합성을 검토해 bounded 계획에 사용할 수는 있지만,
실제 모델 동등성/추론 정확도는 미검증으로 남기고 그 증거가 필요한 단계를 차단한다.
`validated`는 반드시 기록된 방법과 범위에 한정되며 실행 검증을 암시하지 않는다.

원 모델의 dtype/연산을 그래프에 보존한다. INT4 양자화·융합·분할·엔진 공유 등은
`module_mapping.json`에서 변환 근거와 수치 검증 기준을 기록한다. 노드 하나를 RTL 하나로
기계적으로 변환하지 않는다.

### 검사 가능한 노드 참조

계획 검사에서 `graphs`는 `id`와 `nodes`를 가진 객체의 배열, `nodes`는 `id`를
가진 객체의 배열이다. graph 내 node ID는 고유해야 한다. graph/node/module ID에는
영문·숫자·밑줄·점·콜론·하이픈을 사용하며 첫 문자는 영문·숫자·밑줄이다.

일반 노드는 `{"graph_id": "prefill", "node_id": "q_proj"}`로 참조한다.
반복은 `op: "repeat_template"`, `attributes.template_id`, 양의 정수 `count`,
고유 `instance_id`를 가진 명시적 `bindings` 배열로 표현한다. 본체는
최상위 `templates[template_id].nodes`에 둔다. 검사기는 repeat 노드 자체와 각
인스턴스의 본체 노드를 모두 목록화한다. 본체의 참조 ID는
`<repeat_node_id>/<instance_id>/<body_node_id>`이며 중첩 반복도 같은 방식으로 확장한다.
예: `decoder_repeat/L0/q_proj`. 범위 문자열 `L0..L15`나 wildcard는 검사 입력으로
사용하지 않는다. Parent가 명시적 참조 목록을 작성한다. repeat 컨테이너는 scheduler
등에 매핑하고 각 본체 연산도 빠짐없이 처리한다. 다른 그래프 표현을 사용했다면
검사 가능한 위 표현으로 정규화한 새 계획을 남긴다.

## module_mapping.json 작성 — 필수

모델 그래프 검토 후, bring-up 계획과 구현별 계약 작성 전에 Parent가 생성한다.
그래프와 같은 계획 디렉터리에 두며 고정 파일명은 `module_mapping.json`이다.
매핑은 **하드웨어 설계 결정과 근거**다. 포트·cycle·메모리·검증 조건을 확정하는
모듈 계약을 대체하지 않으며 `reviewed`도 RTL·수치·보드 검증 완료를 뜻하지 않는다.

| 필드 | 내용 |
| --- | --- |
| `schema` | `llm2rtl.module_mapping.v1` |
| `design_id`, `revision` | 대응 그래프·계획과 동일한 설계·계획 버전 |
| `path_base` | `repository_root`. 파일 참조는 저장소 루트 기준 상대 경로 |
| `status` | `draft`, `blocked`, `reviewed`. `reviewed`는 Parent 자체 검토이며 사용자 승인이 아님 |
| `scope` | 모델 기반은 `model`, 단독 연산 기반은 `operator` |
| `model_graph` | `model` 범위에서 필수인 `{path, sha256}` |
| `operator_spec`, `scope_reason` | `operator` 범위에서 대신 사용하는 연산 명세 `{path, sha256}`와 범위 사유. 모델 그래프를 조작하지 않음 |
| `hardware_profile` | `{path, sha256}` |
| `architecture` | compute/execution/memory/control 선택과 후보·근거. 특정 엔진·타일을 기본값으로 강제하지 않음 |
| `numeric_policy` | 원본 대비 목표 수치 형식, 변환 위치·규칙, 미결정 사항 |
| `memory_plan` | 상주/전송·버퍼·예산과 가정/계산/측정의 구분 |
| `modules` | 고유 `module_id`, `role`, `implementation`(`generated`/`reused`), `rationale`를 가진 모듈 목록 |
| `mappings` | 아래 형식의 연산→모듈 대응 목록 |
| `unmapped_nodes` | 아직 구현 매핑이 없는 노드와 `blocked`/`excluded` 사유. 없으면 `[]` |
| `review` | `reviewed_by`, `limitations`(문자열 배열). `reviewed`이면 검토 주체 필수 |

파일 참조 객체에는 `path`와 `sha256`만 쓴다. 같은 파일을 다르게 가리키는 경로나
symlink는 허용하지 않는다. 소스 신원 필드에 기록된 외부 모델 경로는 이 계획 파일
참조 규칙과 별개이며, 정확한 모델 소스 확인은 Parent의 책임이다.

하나의 mapping 항목은 다음과 같다. 내용은 형식 예시이며 검증된 구현이 아니다.

```json
{
  "mapping_id": "shared_projection",
  "nodes": [
    {"graph_id": "prefill", "node_id": "q_proj"},
    {"graph_id": "prefill", "node_id": "k_proj"}
  ],
  "module_ids": ["projection"],
  "transform": "shared_engine_with_quantization",
  "rationale": "Q/K projection을 shape와 주소 설정이 다른 동일 엔진으로 순차 실행",
  "numeric_validation": "BF16 reference 대비 목표 양자화 검증과 RTL 대 정수 golden 비교를 분리; 허용 오차는 계약 확정 전 결정"
}
```

여러 노드를 한 모듈에 공유/융합하거나 한 노드를 여러 모듈로 분할할 수 있다.
한 노드는 하나의 mapping 항목에만 기록하고 분할은 그 항목의 `module_ids`에
여러 ID를 쓴다. 원 모델에 없는 transport·router 등 기반 모듈은 `modules`에 두되
가짜 graph node를 만들지 않는다. 모든 graph node는 매핑되거나 아래처럼 명시적으로
미매핑 처리되어야 한다. `excluded`는 사용자 지원 범위를 암묵 축소하는 허가가 아니다.

```json
{"node": {"graph_id": "decode", "node_id": "softmax"}, "status": "blocked", "reason": "목표 수치 형식의 검증 방법 미확정"}
```

단독 연산 생성도 매핑 파일을 작성하되 `scope: "operator"`와 해시로 묶인 연산
명세를 사용한다. 이 경우 mapping의 `nodes`와 `unmapped_nodes`는 `[]`이며 모듈 선택과
수치 변환의 근거는 그대로 기록한다. 누적 보드 구현을 하지 않는 단독 모듈 요청에는
`bringup.json`을 강제하지 않는다.

## 사용자 매핑 확인 — 구현 전 필수

Parent는 매핑을 구성·검토한 뒤 사용자에게 다음을 제시한다.

- 정확한 design/revision, 매핑 파일 링크와 SHA-256.
- 모듈 목록·역할, 연산 공유/융합/분할, 선택한 연산 구조와 병렬도.
- 수치 변환, 메모리 상주·전송 방식, 자원 가정과 미지원·미해결 사항.
- 이 구성으로 구현을 진행해도 되는지 명확한 승인 질문.

`parent_loop_state.json`에는 `status: "awaiting_user_mapping_approval"`와 승인
대상 매핑 경로·해시, 다음 행동을 기록하고 대기한다. JSON만 던져 주지 말고 설계
결정과 trade-off를 읽을 수 있게 요약한다. 일반적인 생성 요청, 입력 모델/환경 확인,
이 승인 절차를 추가하라는 요청, Parent의 `reviewed`, 검사 PASS, 무응답을 구체적인
매핑 승인으로 간주하지 않는다. 단독 연산의 `scope: operator`에도 같은 규칙을 적용한다.

실제 긍정 응답을 받으면 같은 planning 디렉터리에 `module_mapping_approval.json`을
기록한다. 승인 필드를 매핑 본문에 추가해서 승인 대상의 해시를 바꾸지 않는다.

| 필드 | 내용 |
| --- | --- |
| `schema` | `llm2rtl.module_mapping_approval.v1` |
| `design_id`, `revision`, `path_base` | 매핑과 동일한 신원, `repository_root` |
| `module_mapping` | 사용자가 확인한 정확한 `{path, sha256}` |
| `decision` | 실제 결정. 소비 검사는 `approved`만 허용; `pending`, `changes_requested`, `rejected`, `revoked`는 허용하지 않음 |
| `scope` | `implement_this_mapping`. 입력 확인·보드 테스트 통과와 구분 |
| `recorded_by` | 실제 결정을 기록한 Parent 식별자. 승인 주체를 대신하지 않음 |
| `request` | 승인 요청의 `message_ref`, 실제 질문 `text` |
| `user_response` | `actor: "user"`, 실제 응답의 `message_ref`, 응답 원문 `text` |

`message_ref`는 실제 대화 메시지 식별자 또는 보존한 대화 기록의 위치다. 도구가
메시지 ID를 노출하지 않으면 그 제한을 밝히고 확인 가능한 대화 위치를 기록하며
가짜 ID를 만들지 않는다. Parent는 실제 응답과 문맥을 근거로 결정을 기록한다.
별도 자동 승인 명령은 제공하지 않는다. 검사기는 기록의 구조·결정·매핑 일치성을
확인할 뿐, 실제 사람의 신원이나 대화 원문의 진위를 인증하지 않는다.

승인 후 approval 파일의 SHA-256도 packet에 전달한다. 매핑 내용·버전·경로·해시가
바뀌면 기존 승인은 재사용하지 않는다. 원본을 보존하고 변경안을 다시 제시해 승인을
받는다. 반려·수정 요청·철회가 도착하면 과거 승인 기록의 존재와 무관하게 해당 구현을
진행하지 않는다. 매핑 검토용 초안은 수정할 수 있지만 승인 전 bring-up 작성이나
RTL 구현을 병렬로 시작할 수 없다.

승인은 이 매핑으로 구현을 진행하는 것에 한정된다. 수치·계약 검증을 면제하거나
모든 단계의 FPGA 실물 확인을 승인한 것이 아니다. 변경 없는 매핑은 단계마다 재승인을
받을 필요가 없지만 사용자 하드웨어 체크포인트는 기존대로 수행한다.

## bringup.json 작성

정확한 매핑에 대한 실제 사용자 승인 기록을 먼저 생성하고, 아래 `--before-bringup`
검사를 통과한 뒤에만 작성한다. 여기서 매핑의 **확정은 사용자 승인**을 의미하며
Parent의 `reviewed`나 구조 검사 PASS만으로는 충분하지 않다. 승인 전 초안은 금지한다.
그래프와 같은 계획 디렉터리에 저장하고 다음 내용을 포함한다.

| 필드 | 내용 |
| --- | --- |
| `schema` | `llm2rtl.bringup.v1` |
| `design_id`, `revision` | 대응 설계·계획 버전 |
| `model_graph` | 검토한 `model_graph.json`의 경로와 SHA-256 |
| `hardware_profile` | FPGA 프로파일 경로와 SHA-256 |
| `target` | `nodes`에 요청된 최종 노드 참조 배열을 명시. 모드·shape·성능/자원 제약과 제외 범위도 기록. 수치 정책은 매핑을 참조 |
| `module_mapping` | 필수 `module_mapping.json`의 `{path, sha256}`만 기록. `entries` 등 매핑 본문 복제 금지 |
| `module_mapping_approval` | 생성 전에 확인한 별도 승인 기록의 `{path, sha256}`. 검사에 전달된 승인 경로·해시와 동일해야 함 |
| `stages` | 순서와 의존성이 명시된 누적 단계 목록 |
| `review` | 계획 검토 주체, 범위와 남은 blocker |

각 stage에 다음을 기록한다.

- 고유 `stage_id`, `depends_on`, 새로 추가할 기능과 유지할 기능.
- `graph_coverage`: `added`, `cumulative`에 위 노드 참조 배열을 각각 기록한다.
- `new_modules`, `reused_modules`: 매핑에 있는 module ID의 배열. 첫 등장 ID와 이전
  단계에서 유지하는 모든 ID를 구분한다. IP 자체의 generated/reused 여부와는 별개다.
  단계별 interfaces·메모리·자원 계획은 매핑의 결정을 구체화하되 복제하거나 상충하지 않는다.
- `contract_index`: 해당 단계 계약의 경로와 freeze 후 SHA-256. 미래 단계는
  `uncreated`로 명시하며 hash를 만들어내지 않는다. 배정 전에는 반드시 확정해야 한다.
- 검증 입력·출력 경계, reference/golden의 근거, 초기 state·필요 가중치.
- 모듈/통합/보드 회귀와 통과 기준, 검증 보고서·빌드 산출물의 예정 위치.
- `hardware_checkpoint_required`: 누적 보드 단계는 `true`; 사용자 인계·결과 평가 기준.

첫 단계는 실제 입출력 검증이 가능한 최소 유용 구성으로 선택한다. 특정 연산 순서를
고정하지 않는다. 데이터 이동만 검증하는 기반 단계는 `graph_coverage`를 빈 목록으로
하고 infrastructure-only 사유를 기록할 수 있지만 모델 연산을 검증했다고 주장하지 않는다.
DDR↔local 전송에는 제공 DataMover Engine, 필요한 adapter·bank·scheduler를 포함한다.

Parent는 배정 전 그래프 노드/텐서 ID와 매핑이 존재하는지, stage 의존성이 앞선
단계를 가리키는지, 누적 범위가 이전 기능을 유지하는지, 최종 단계가 요청 범위를
충족하는지 확인한다. 미지원 노드나 모델 참조 실행 blocker는 숨기지 않는다.
독립 검증 packet에도 해당 graph·stage·매핑을 전달하여 golden과 RTL이 같은
잘못된 해석을 공유하지 않는지 검사하도록 한다.

검사 입력은 순차 누적 단계다. 다음 단계는 바로 이전 단계에 의존하고, 이전 모듈과
coverage를 모두 유지한다. 마지막 단계의 누적 coverage는 `target.nodes`와 같아야 한다.
제외한 노드를 target에 남길 수 없으며, 미래 단계의 blocked 노드는 계획에 보존하되
그 노드를 포함한 단계는 배정하지 않는다. 단독 연산의 누적 계획은 `model_graph` 대신
매핑과 동일한 `operator_spec`을 참조하고 모든 graph coverage 배열을 비워 둔다.

## 저장·버전·진행 상태

권장 경로는 `contracts/designs/<design_id>/<revision>/planning/`이다.
`init`이 revision 디렉터리를 새로 생성하므로, 그래프·매핑은 먼저 작업용 임시 위치에서
작성한 뒤 module ID가 결정되면 `init`을 수행하고 `planning/`에 보관한다. `init`은
초안 폴더 준비이므로 승인 전에도 가능하며, 구현 계약 확정과 다르다. 매핑 승인 질문은
최종 보관 경로에서 제시하여 승인 직후 파일 이동으로 다시 승인을 받는 상황을 피한다.
임시 위치도 저장소 내부를 사용한다. 승인 전 이동하면 저장소 상대 경로와 그래프→매핑
순서의 참조 해시를 다시 계산하고 재검사한다. bring-up은 최종 경로의 매핑 승인 후에
생성한다. 실행되는 모델 코드는 이 과정에서 변경하지 않는다.
기존 revision에 init을 재실행하거나 계획 파일을 덮어쓰지 않는다.

확정된 `bringup.json`은 계획이고, 실행 상태·사용자 결과는 기존 부모
`parent_loop_state.json` 및 stage별 evidence에 기록한다. 계획을 진행 로그로 계속
덮어쓰지 않는다. packet과 검증 보고서에는 graph/mapping/bringup 경로·SHA-256·stage ID를
기록하고 Parent는 배정 전과 결과 승인 전에 다시 확인한다. 계획/모델/보드가 바뀌면
새 revision과 영향을 받는 매핑·계약·검증을 갱신한다.
packet에는 별도 approval 경로·SHA-256도 전달한다. 승인을 보존하려고 바뀐 매핑에
과거 approval의 해시만 맞춰 쓰거나 승인 응답을 만들어내서는 안 된다.

기존 `bringup_plan.json`, 매핑을 inline으로 넣은 계획, 자유 형식의 실험 매핑은
원본을 보존하고 새 revision에서 위 형식으로 이전한다. 두 파일을 동시에 현재
계획으로 사용하지 않는다. 기존 실험 파일은 새 필수 형식을 통과했다고 간주하지 않는다.

## 실행 가능한 계획 검사

저장소 루트에서 아래 명령을 실행한다. 경로는 작성한 실제 파일로 바꾼다.
검사기는 Python 표준 라이브러리만 사용하며 파일을 쓰거나 모델 코드를 실행하지 않는다.

```sh
python3 scripts/check_planning.py --mapping contracts/designs/demo/r01/planning/module_mapping.json
```

이 명령은 승인 전 매핑 단독 구조 확인이다.
필드 구조를 갖춘 `draft`/`blocked`도 검사할 수 있다. 누락된 필드/노드는 실패하며,
미매핑 노드를 사유와 함께 명시한 초안은 `passed_structure_only`가 될 수 있다.
이는 배정 가능 판정이 아니다. 초안의 미확정 값은 숨기지 않고 Parent 검토에서 해결한다.
이 명령은 사용자 승인 기록을 요구하지 않으며 결과의
`user_approval_declaration_checked`는 `false`다. 승인 없는 구조 검사는 구현 허가가 아니다.

사용자가 정확한 매핑을 승인하고 별도 승인 기록을 작성한 뒤, **bring-up 작성 직전**에
다음 명령을 실행한다. 이 시점에는 같은 폴더의 `bringup.json`이 없어야 한다.

```sh
python3 scripts/check_planning.py --mapping contracts/designs/demo/r01/planning/module_mapping.json --expected-mapping-sha256 PARENT_MAPPING_SHA256 --expected-approval-sha256 PARENT_APPROVAL_SHA256 --before-bringup
```

`bringup_generation_gate_passed: true`일 때 승인된 매핑 범위 안에서 bring-up을 생성한다.
매핑 `reviewed` 상태·정확한 해시·실제 사용자 결정 기록을 검사하며, 파일이나 승인이
누락·반려·철회·변경됐으면 실패한다. 승인 자체를 생성하는 명령은 아니다.
기존 bring-up이 있으면 덮어쓰지 않고 기존 계획 검사 또는 새 revision 절차를 따른다.

생성 후에는 단계 선택 없는 계획 검사도 매핑·승인 핀을 필수로 전달한다.

```sh
python3 scripts/check_planning.py --mapping contracts/designs/demo/r01/planning/module_mapping.json --bringup contracts/designs/demo/r01/planning/bringup.json --expected-mapping-sha256 PARENT_MAPPING_SHA256 --expected-approval-sha256 PARENT_APPROVAL_SHA256
```

bring-up의 `module_mapping_approval`도 검사된 승인 기록과 일치해야 한다. 승인 없는
`--bringup` 검사는 더 이상 허용하지 않는다. 매핑 단독 구조 검사는 bring-up 검사나
생성 전 gate를 대신하지 않는다.

배정·승격 전에는 Parent가 전달한 정확한 해시와 stage ID로 다시 검사한다.

```sh
python3 scripts/check_planning.py --mapping contracts/designs/demo/r01/planning/module_mapping.json --bringup contracts/designs/demo/r01/planning/bringup.json --expected-mapping-sha256 PARENT_MAPPING_SHA256 --expected-bringup-sha256 PARENT_BRINGUP_SHA256 --expected-approval-sha256 PARENT_APPROVAL_SHA256 --stage s01 --module projection
```

`PARENT_*_SHA256`은 packet에 전달된 실제 값으로 바꾼다. 소비자가 현재 파일의 해시를
새로 계산해서 기대값 대신 쓰면 안 된다. stage 검사는 검토된 매핑, 선택한 단계의
미매핑 노드 부재, 해당 단계에서 사용 가능한 module ID도 요구한다. 특정 모듈 작업이
아니면 `--module`은 생략한다. 누적 계획 없는 단독 연산은 첫 명령에
`--expected-mapping-sha256`, `--expected-approval-sha256`, `--module`을 붙인다.
기대 매핑 해시를 전달한 모든 소비 검사는 `reviewed`와 같은 디렉터리의 정확한
`module_mapping_approval.json` 및 그 기대 해시를 요구한다. 단독 연산의 module ID도
매핑에 존재해야 한다. 누락·반려·승인 대상 불일치·approval 파일 변경은 실패한다.
계약 freeze 전에도 승인 기록을 포함한 소비 검사를 실행하고 현재 단계의 의미·수치
blocker를 검토한다. 승인 없이 기본 구조 검사만 실행해서 freeze하면 안 된다.

이 검사기는 파일·참조 SHA-256·설계 버전·고유 ID·노드 매핑 누락과 중복·매핑 본문
복제·단계 의존성·누적 coverage·모듈 가용성 및 생성 전/계획 검사/소비 시 사용자
승인 선언을 확인한다.
실패 시 종료 코드는 1이다. 승인 기록의 진위·사용자 신원은 인증하지 않는다.
검사기는 읽기 전용이며 파일 시스템 쓰기를 잠그거나 과거 생성 시각의 선후관계를
증명하지 않는다. Parent는 실제 생성 직전에 gate를 실행해야 하며, 승인 전에 몰래
쓴 파일을 나중에 승인 참조만 붙여 정당화해서는 안 된다.
반복의 tensor/state 연결, 원본 코드와 그래프의 동등성, 연산 공유/융합의 타당성,
수치 정확도·성능·메모리 용량·RTL 배선과 실제 보드 통과는 증명하지 않는다.
JSON에 선언된 target/exclusion이 사용자 요구와 맞는지도 Parent/독립 검증 책임이다.

현재 생성·배정은 **Skills에 따른 Parent의 작업 의무**다. 범용 모델 추출기나 E2E
실행기는 제공하지 않는다. `design_contracts.py init`은 계획 세 파일을 생성하지 않고,
`freeze/check`도 계획 검사기를 자동 호출하지 않는다. Parent는 **계획 gate와 계약
gate를 둘 다 실행**하고 승인 기록·두 결과와 검토 근거를 packet/증거에 남긴다. 계획 검사 PASS는
계약 freeze나 선행 사용자 하드웨어 체크포인트를 대체하지 않는다.
