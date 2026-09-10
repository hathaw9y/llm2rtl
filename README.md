# llm2rtl — generation framework

모델과 FPGA 하드웨어 명세를 입력으로 받아, LLM 에이전트가 Skills와 프로젝트
계약에 따라 가속기를 설계·구현·검증하도록 구성한 프레임워크입니다.
이 저장소에는 이전 실행에서 생성한 가속기나 bitstream을 포함하지 않습니다.

현재는 **Skill 기반 에이전트 워크플로와 일부 실행 가능한 계약 검사 코드**입니다.
모델 파일 하나를 전달하면 모든 과정을 자동 실행하는 완성된 E2E CLI는 아닙니다.
`src/codegen/variant_contract.py`는 계약 검사·파생 도구이며 RTL 생성기가 아닙니다.

## 포함 범위

| 경로 | 역할 |
| --- | --- |
| `skills/` | 부모 설계, 모듈 구현, 독립 검증, 통합, 보드 빌드와 사용자 검증 절차 |
| `docs/` | Skill 명세와 공통 설계 원칙 |
| `contracts/` | 공통 정책, 설계별 계약 템플릿, 스키마; 실행별 계약은 `designs/` 하위에 생성 |
| `config/hardware/` | 하드웨어 입력 프로파일; 현재 ZCU104 제공 |
| `src/`, `scripts/` | 계획·계약 검사와 프로젝트 Skill 동기화 도구 |
| `verification/framework/` | 재실행 가능한 계획·계약 검사 테스트와 작은 입력 fixture |
| `ip/infrastructure/datamover_engine/` | 재사용 전송 기반 RTL·인터페이스·테스트 |

DataMover Engine은 매번 생성할 연산 IP가 아니라 재사용하는 기반 소스입니다.
DDR↔로컬 메모리 전송이 있는 설계는 **제공된 DataMover Engine 사용이 필수**입니다.
부모는 설계 index의 `transport`에 사용 여부·scheduler 소유권·연결 계획을 작성합니다.
`freeze`/`check`는 누락·대체 엔진·inline variant의 상충 선언을 차단하고,
Engine 인터페이스 계약과 18개 RTL 소스를 SHA-256으로 묶습니다.
DDR 전송 없는 독립 연산 모듈은 사유를 명시하여 제외할 수 있습니다.
이는 계약 gate이며 실제 소스 포함과 배선 일치는 별도 통합 검증에서 확인해야 합니다.
작성 형식은 [계약 안내](contracts/README.md#필수-datamover-선언)를 참조하세요.
AMD AXI DataMover IP 자체는 포함하지 않습니다. 생성할 scheduler가 전송 정책과
오류 복구를 소유하며 compute IP는 로컬 메모리에만 접근합니다.

## 사용 흐름

1. 모델 config·정확한 모델 코드/revision·실행 조건과 FPGA part·클럭·메모리·도구 환경을 준비합니다.
2. Skill을 읽을 수 있는 LLM 에이전트에 해당 입력과 생성 요청을 전달합니다.
3. 부모 에이전트가 모델 코드에서 `model_graph.json`을 추출·검토하고, FPGA 제약을
   반영한 **필수 `module_mapping.json`**을 구성·검토한 뒤 사용자에게 제시하고 승인을 기다립니다.
   **사용자 승인 후 생성 전 gate를 통과해야** 누적 단계 계획 `bringup.json`을 처음 생성합니다.
   승인 전에는 bring-up 초안도 만들지 않습니다. 계획·승인 검사를 거쳐
   계약 초안의 내용을 작성·검토하고 `freeze`로 확정합니다. `init`으로 초안·최종 보관 경로를
   미리 준비할 수 있지만 승인 전 구현 배정은 금지합니다. 계약·계획·승인 신원을 packet에 전달합니다.
4. 구현 에이전트가 RTL·golden·TB를 생성하고 별도 검증 에이전트가 검사합니다.
5. 검증된 모듈을 통합해 Vivado 빌드와 산출물 일치 검사를 진행합니다.
6. 사용자가 실제 FPGA에서 테스트하고 결과를 반환한 뒤 다음 단계로 진행합니다.

그래프의 실행 조건·정합성 확인, 단계별 그래프 범위와 계획 파일 형식은
[모델 그래프와 bring-up 계획](docs/model_graph_bringup.md)을 참고하세요.
그래프는 모델 동작의 근거, 매핑은 하드웨어 모듈 선택·공유·수치 변환의 근거,
bring-up 계획은 구현 순서의 근거, 계약은 구현·검증 기준입니다.
`bringup.json.module_mapping`은 `{path, sha256}`만 저장하며 매핑 본문을 복제하지 않습니다.
단독 연산 생성도 `scope: operator`의 매핑을 남기되 가짜 모델 그래프는 만들지 않습니다.
일반 질문이나 입력 확인 단계마다 계획 파일을 생성하는 것은 아닙니다.
Parent는 모듈 역할·공유 구조·수치·메모리 결정과 위험 요소를 요약해 보여주고
`awaiting_user_mapping_approval`에서 명시적 답변을 기다립니다. 실제 승인은 별도
`module_mapping_approval.json`에 매핑 경로·해시와 요청/응답 근거를 기록합니다.
Parent의 `reviewed`는 사용자 승인이 아니며, 매핑이 변경되면 다시 확인받습니다.
현재 그래프 추출과 계획 작성은 Parent LLM의 작업이며 범용 자동 추출기는 포함하지 않습니다.

구체적인 절차는 [Skill 명세](docs/skills_specification.md)와
[운영 규칙](docs/skills_overview.md)을 참고하세요. 에이전트·모델 API 접근,
Vivado와 시뮬레이터, FPGA 보드는 사용자가 별도로 준비합니다.

### 사용자가 하는 일

환경과 Skills를 준비한 뒤, 모델·보드 명세와 원하는 생성 범위를 LLM에 전달합니다.
일반 사용자는 `init` 명령이나 계약 JSON을 직접 작성할 필요가 없습니다.
아래는 요청 형식 예시이며 완성된 설계 계약이나 실행 결과가 아닙니다.

> 이 저장소의 Skills와 공통 계약을 사용해, 제공한 모델·FPGA 명세에 맞는
> 가속기를 생성해줘. 부모 에이전트가 설계 분해, 계약 초안 생성·작성·확정과
> 작업 배정을 수행하고, 구현과 독립 검증 담당이 동일한 계약 index를 검사하도록 해줘.
> 이번 생성 범위는 [원하는 모듈 또는 누적 단계]야.
> 설계에 필요한 정보가 부족하면 먼저 확인하고, 실제 FPGA 실행은 내가 진행할게.

사용자는 부족한 요구사항에 답하고, 보드 단계에 도달하면 실제 FPGA 테스트를
수행합니다. 부모 LLM의 계약 확정은 사용자 권한을 대신하거나 요청 범위를
확장하는 승인이 아닙니다.

### 에이전트가 내부적으로 하는 일

- 부모: 입력 해석 → `model_graph.json` → `module_mapping.json` 구성·검토 → **사용자 승인 대기·기록** → 생성 전 승인 gate → `bringup.json` 생성·검토 → 계획·승인 검사 → 계약 작성·검토 → `freeze` → 단계별 배정
- 구현·검증 담당: 전달받은 index·SHA·모듈 ID로 `check` → 계약 내용을 읽고 작업

배정·승격 전에는 graph/mapping/bringup 및 approval 경로·해시와 stage/module ID도 전달하고
계획 참조 gate를 다시 실행합니다. 계획 gate와 계약 gate는 별도 명령이며 둘 다
필요합니다. PASS만으로 수치 검증이나 선행 사용자 하드웨어 체크포인트를 생략하지 않습니다.

`init`은 폴더·초안·참조를 만드는 도구일 뿐입니다. 타일 크기·포트·메모리 배치를
결정하고 미결정 값을 채우는 주체는 부모 LLM입니다. 명령은 LLM의 도구 실행을
통해 호출되며, 사용자 요청을 자동 수신하는 별도 E2E 서비스는 포함하지 않습니다.
수동 CLI 사용법은 [개발·디버깅용 계약 안내](contracts/README.md)에 분리했습니다.

## 단계별 계약 사용

**모든 구현·검증에는 기준 계약이 있어야 하지만, 모든 단계에서 계약을
처음부터 다시 작성하지는 않습니다.** 새 모듈이나 통합 경계가 생길 때 계약을
구체화하고, 이후 단계는 확정된 계약을 소비합니다.

### 공통 계약과 실행별 계약

```text
contracts/
├── *.json                         # 구현과 무관한 공통 원칙
├── templates/                     # 미결정 값을 가진 작성 양식
├── designs/<design_id>/<revision>/ # 실행 시 생성; Git 기본 제외
│   ├── contract_index.json        # 적용 정책과 실제 계약 경로
│   ├── planning/                  # model_graph / module_mapping / bringup + 별도 사용자 승인 기록
│   └── modules/<module_id>/       # 모듈별 계약
└── schemas/                       # 제공된 문서 형식 스키마
```

부모는 `init`으로 필요한 템플릿을 새 설계 폴더에 생성한 뒤 수치·배치·소유권을 작성하고,
`contract_index.json`에 정확한 저장소 기준 상대 경로를 기록합니다. 구현·검증
담당은 부모가 확정한 동일 index를 받아 관련 공통 원칙과 실행별 계약을 함께
읽습니다. `null`은 미결정 값이므로 구현 전에 해결해야 합니다. 적용 제외는
이유와 승인을 기록합니다. 상세 규칙은 [계약 안내](contracts/README.md)를 따릅니다.

- **공통 계약:** `contracts/`에 포함된 프로젝트 정책·스키마입니다. 부모가
  설계 전에 관련 규칙과 하드웨어 프로파일을 확인하고, 해당 규칙의 경로와
  적용 범위를 구현·검증 담당에게 전달합니다. Skill은 작업 절차를 안내하고,
  프로젝트 계약은 해당 설계가 따라야 할 기준을 정합니다.
- **실행별 계약:** 모델·보드·모듈에 맞춰 생성하는 `module_packet.json`,
  `interface_contract.json`, `memory_contract.json` 등입니다. 실행 workspace의
  `contracts/designs/<design_id>/<revision>/` 아래 해당 모듈·통합 범위에 보관하며,
  공통 정책 파일을 실행 결과로 덮어쓰지 않습니다.
  재사용 기반 IP의 기존 인터페이스 계약은 구현과 함께 입력으로 유지합니다.

| 단계 | 담당 | 계약의 사용 방식 |
| --- | --- | --- |
| 전체 설계 | 부모 설계 에이전트 | 관련 공통 규칙을 읽고 입력 모델·보드에 맞는 시스템 경계와 제약 확정 |
| 모듈 분해 | 부모 설계 에이전트 | 모듈별 포트·수치 형식·메모리·핸드셰이크·검증 기준 작성 및 확정 |
| 모듈 구현 | 구현 에이전트 | 전달된 계약에 맞춰 RTL·golden·TB 생성; 필요 변경은 부모에게 요청 |
| 독립 검증 | 구현과 별도인 검증 에이전트 | 같은 계약을 기준으로 실제 RTL 동작과 소스에 연결된 검증 근거 비교 |
| 모듈 통합 | 통합 담당, 부모 승인 | 자식 계약은 유지하고 연결·제어·buffer·오류 전달의 상위 통합 계약 추가 |
| 보드 구현 | 보드 통합·빌드 담당 | 클럭·리셋·PS/PL·DDR·주소 맵과 기존 자식 계약의 일치 확인 |
| 실보드 검증 | 사용자 실행, 검증 담당 평가 | 확정된 계약과 정확한 빌드의 manifest에 묶인 테스트·결과로 판정 |

예를 들어 GEMM을 Scheduler·DataMover에 연결할 때는 GEMM의 기존 로컬 메모리
인터페이스를 다시 정의하지 않습니다. 전송·buffer 소유권·시작/완료 순서 등을
상위 통합 계약에 추가하고, 연결이 기존 GEMM 계약을 만족하는지 검증합니다.

### 공통 파일을 읽는 시점

| 파일 | 주요 적용 시점과 내용 |
| --- | --- |
| [generation_policy.json](contracts/generation_policy.json) | 생성 계획 수립 시 단계·RTL 작성 전 조건·검증 및 승격 기준 확인 |
| [model_scheduler_role.json](contracts/model_scheduler_role.json) | Scheduler 분해·구현 시 실행 순서와 타일 루프 소유권 확인 |
| [address_ownership.json](contracts/address_ownership.json) | 인터페이스 설계 시 PS·Scheduler·엔진의 주소 생성 책임 구분 |
| [memory_ownership.json](contracts/memory_ownership.json) | 버퍼·메모리 설계와 통합 시 접근 주체·데이터 폭·소유권 확인 |
| [native_memory_timing.json](contracts/native_memory_timing.json) | 해당 native-memory 경로의 RTL·BMG 연결 시 읽기 지연과 valid 정렬 확인 |
| [block_design_layout.json](contracts/block_design_layout.json) | 보드 통합 시 BD 구성 요소·연결 경계·생성 경로 확인 |
| [schemas/](contracts/schemas/) | 대응하는 계약을 작성·검사할 때 데이터 구조 확인 |

모든 모듈에 모든 공통 파일이 적용되는 것은 아닙니다. 부모가 적용 범위를
명시해야 하며, legacy 전송 정책과 새 DataMover 인터페이스처럼 충돌하는 규칙을
발견하면 구현 전에 해결해야 합니다. 적용되지 않는 규칙을 조용히 무시하거나
새 설계에 과거의 검증 상태를 그대로 붙이지 않습니다.

### 조건부 계약과 변경 절차

DDR 텐서 배치와 로컬 bank 배치 사이에 주소·lane·packing 변환이 필요하면
`remap_adapter_contract.json` 같은 별도 계약을 작성할 수 있습니다. 변환 필요
여부는 설계 시 확인하되, 이 파일을 모든 모듈에 항상 생성하는 것은 아닙니다.
변환이 없다면 기존 인터페이스·메모리 계약으로 충분할 수 있습니다.

확정된 계약 변경이 필요하면 다음 절차를 따릅니다.

1. 구현·검증 담당이 변경 이유와 영향받는 경계를 부모에게 보고합니다.
2. 부모가 상위·자식 계약과의 일관성을 검토하고 변경을 승인합니다.
3. 이전 계약·소스·증거를 보존한 채 새 계약 버전과 영향 범위를 기록합니다.
4. 변경된 구현 및 영향을 받는 통합 경계를 다시 검증합니다. 이전 PASS를
   변경된 설계의 검증 결과로 재사용하지 않습니다.

### 현재 자동화 범위

`scripts/check_planning.py`는 필수 매핑 파일, 모델 그래프·하드웨어·계획의 참조 해시,
노드/모듈 ID, 미매핑 노드, 단계별 누적 범위와 모듈 가용성을 검사합니다.
`bringup.json` 안의 매핑 본문 복제도 차단합니다. `--stage` 검사는 Parent가 전달한
매핑·계획 해시와 검토된 매핑을 요구하며, 미매핑 노드가 포함된 단계는 차단합니다.
`--before-bringup`은 매핑·승인 해시와 아직 bring-up 파일이 없음을 확인하는 생성 전
gate입니다. 생성된 계획에는 별도 `module_mapping_approval` 경로·해시도 기록합니다.
`--bringup` 검사는 stage 선택 없이도 매핑·승인 해시를 요구합니다.
매핑 기대 해시를 전달한 소비 검사는 `--expected-approval-sha256`도 필수입니다.
실제 사용자 결정을 기록한 `module_mapping_approval.json`이 해당 매핑과 일치해야 하며,
없거나 다른 매핑의 승인·반려·변경된 승인 기록이면 소비를 차단합니다. 승인 없는 기본
구조 검사 PASS로 구현을 시작할 수 없습니다. 이 검사는 승인 선언을 확인할 뿐
사람의 신원·대화 원문을 인증하지 않으므로 Parent는 실제 사용자 의사를 반드시 따라야 합니다.
검사기는 파일 쓰기 자체를 잠그지 않습니다. Parent가 생성 직전 gate를 실행할 의무와
미승인 계획의 검사 차단을 결합한 규칙이며, 과거 파일 생성 순서를 증명하는 기능은 아닙니다.
이는 **선언된 구조·참조 검사**이며 모델 정확도나 RTL·보드 동작을 증명하지 않습니다.
명령·필드·이전 방법은 [계획 검사 안내](docs/model_graph_bringup.md#실행-가능한-계획-검사)를 참고하세요.

`scripts/design_contracts.py`가 초안 생성(`init`), 필수 값 확인 및 부모 승인 기록과
파일 해시 확정(`freeze`), index에 묶인 소비 검사(`check`)를 수행합니다. 부모·모듈
구현·독립 검증·통합·보드·하드웨어 검증 Skills에 같은 index와 부모가 전달한
SHA-256을 검사하도록 연결했습니다. 실행법은 [계약 안내](contracts/README.md)에 있습니다.
이 계약 CLI는 계획 검사기를 자동 호출하지 않으며, `init`도 계획 세 파일을 생성하지
않습니다. Parent가 두 gate를 별도로 실행하고 결과와 의미 검토 근거를 남깁니다.

`variant_contract.py`의 일반 CLI 경로는 `--contract-index`, `--expected-sha256`,
`--module`을 필수로 받아 gate를 통과한 모듈의 inline `variant`와 하드웨어를
사용합니다. 임의 spec/하드웨어 override는 허용하지 않습니다. 독립 fixture 검사는
명시적인 `--fixture-only`로만 실행하며 design gate를 통과한 것으로 기록하지 않습니다.

도구는 누락·미결정 값·버전 및 해시 불일치를 차단하지만, JSON Schema 범용 실행기나
모든 자유 서술의 의미 검사기는 아닙니다. 계약 통과가 RTL 동작·보드 실행의 증명도
아닙니다. Skill을 따르는 에이전트 작업과 실제 구현·검증은 여전히 필요하며 완성된
E2E 에이전트 실행기를 추가한 것은 아닙니다. 변경된 프로젝트 Skills를 설치할 때만
새 지침이 해당 런타임에 반영됩니다. 이번 저장소 편집은 런타임을 자동 변경하지 않습니다.

메모리 지연은 전역 상수가 아니라 설계별·경로별 결정입니다. 설계별 검증 계획에서
실제 생성 메모리와 소비자의 지연 일치 검사를 마련해야 합니다.

## 로컬 검사

Python 3.9 이상을 사용합니다. Skill YAML 검사는 저장소의 자체 검사기와
PyYAML을 사용하며 외부 `quick_validate.py`나 Codex 설치를 요구하지 않습니다.

```sh
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install -r requirements.txt
python3 scripts/sync_project_skills.py validate
```

Python 3으로 실행하는 계획·계약·Skill 동기화 테스트:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s verification/framework -v
```

Icarus Verilog가 설치되어 있다면 기반 adapter 테스트:

```sh
bash ip/infrastructure/datamover_engine/scripts/run_sim.sh
```

### Skill 설치·동기화

먼저 변경 계획만 확인합니다. `--dry-run`은 대상 폴더가 없어도 생성하지 않습니다.
기본 대상은 `CODEX_HOME/skills` 또는 사용자 홈의 `.codex/skills`입니다.

```sh
python3 scripts/sync_project_skills.py sync --dry-run
```

대상과 변경 목록을 확인한 뒤 실행합니다. 특정 Skill만 설치하려면
`--skill parent-module-decomposition`처럼 지정합니다.

```sh
python3 scripts/sync_project_skills.py sync
python3 scripts/sync_project_skills.py check
```

동기화는 모든 선택 Skill의 형식·경로 검사 → 대상 파일시스템의 임시 복사 →
복사본 내용 비교 → 기존 Skill 백업 → 새 복사본 설치 순서입니다. 소스·대상 간
동일/상하위 경로와 symlink·비정규 파일은 거부합니다. 선택하지 않은 Skill은
변경하지 않습니다. `check`는 파일 내용을 해시로 비교하며 쓰기 작업을 하지 않습니다.

기존 대상은 출력되는 `.skill-sync-backup-*/previous/`에 보존됩니다. 복사·교체
오류나 처리 가능한 중단이 생기면 이미 교체한 Skill까지 복원하며, 실패한 새
복사본은 같은 복구 폴더의 `failed/`에 보관합니다. 백업은 자동 삭제하지 않습니다.
백업과 대상의 Skill 이름을 확인한 뒤 복구하며, 기존 대상에 무조건 덮어쓰지 마세요.

이는 전체 묶음의 원자적 교체는 아닙니다. 교체 중에는 Skill을 읽는 작업을
중지해야 하며 외부 동시 편집은 지원하지 않습니다. 협력하는 sync 실행은
`.skill-sync.lock`으로 중복 실행을 막습니다. 강제 종료·전원 장애 후에는 잠금과
백업을 보존하고 실행 중인 작업이 없는지 확인한 다음 대상별로 복구해야 합니다.
복원 자체가 실패하면 오류 메시지의 복구 디렉터리와 `rollback errors`를 확인하세요.

`--validator /path/to/custom_validator.py`는 **신뢰하는 추가 검사기**를 선택할 때만
사용합니다. 원본 대신 staged 복사본에 실행하고 자체 검사를 생략하지 않습니다.
외부 코드의 무변경을 보장할 수 없으므로 `--dry-run`과 함께 사용할 수 없습니다.
기존 `--no-validate` 옵션은 제거했습니다. 자체 검사는 형식·필수 필드·이름을
확인하며, Skill 지침의 의미나 생성 RTL의 정확성을 검증하지는 않습니다.

## 공개 범위와 남은 정리

- 생성된 `boards/`, 모델별 workspace, compute RTL, packaged IP, 실행 보고서,
  BIT/HWH/XSA, 논문 PDF, 개인 상태 파일은 포함하지 않습니다.
- fixture의 W4A4 ACC16 계약은 검사기 회귀 입력이며 검증된 WS32 가속기나
  기본 생성 설정을 의미하지 않습니다. legacy Fabric 문자열도 보존돼 있습니다.
- 루트 계약에서 고정 지연·주소·셀 이름·기존 구현 경로를 제거하고 설계별
  템플릿으로 분리했습니다. 기존 상세 문서와 회귀 fixture에는 legacy Fabric
  설명이 남을 수 있습니다. 이것이 모든 생성기·검사기의 DataMover 이관 완료를
  뜻하지는 않으며 충돌하는 설명은 생성 전에 검토해야 합니다.
- 독립적인 새 환경 E2E 재현·라이선스 결정·최종 비밀정보 검사는 별도 필요합니다.
  특정 빌드나 실보드 검증 결과를 이 소스 묶음의 검증 결과로 주장하지 않습니다.
