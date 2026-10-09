# llm2rtl

[English](README.md) | **한국어**

모델의 실제 Python 실행을 module-execution ISA로 낮추고, FPGA executor를 한 모듈씩
구현·독립 검증·보드 검증하는 Parent Agent 중심 프레임워크입니다.

## GitHub에서 시작하기

Git, Python 3.10 이상과 로그인된 Codex CLI가 필요합니다. Codex 설치·인증은
[공식 CLI 안내](https://developers.openai.com/codex/cli/)를 참고하세요.
아래는 터미널에서 실행합니다.

```bash
git clone https://github.com/hathaw9y/llm2rtl.git
cd llm2rtl
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install -r requirements.txt
```

모델 ID와 하드웨어 스펙 파일을 전달하면 프롬프트를 완성하고 대화형 Codex를
시작합니다. 아래 예시는 사용자가 ZCU104를 선택한 경우입니다.

```bash
python3 scripts/start_accelerator.py \
  --model HuggingFaceTB/SmolLM2-135M \
  --hardware config/hardware/zcu104.json \
  --language ko
```

다른 모델에는 Hugging Face 모델 ID 또는 로컬 checkpoint 경로를, 다른 보드에는
해당 하드웨어 스펙 파일을 지정하세요. 스펙은 UTF-8 JSON 또는 텍스트 파일이며,
보드·FPGA part, 클럭, 자원, DDR 용량/주소, AXI 연결과 폭, runtime, 도구 버전을
기록할 수 있습니다. 누락된 값은 Codex가 조사하고 사용자와 논의합니다.

실행기는 자신의 위치에서 저장소 루트를 찾으므로 복제 폴더의 이름이나 위치에
의존하지 않습니다. `--hardware`의 상대 경로는 저장소 루트를 기준으로 해석하고,
저장소 밖의 스펙은 절대 경로로 전달합니다. 로컬 checkpoint도 절대 경로를 권장합니다.

먼저 완성된 프롬프트만 확인하려면 다음과 같이 실행하세요. 이 작업에는 Codex
설치나 로그인이 필요하지 않습니다.

```bash
python3 scripts/start_accelerator.py \
  --model HuggingFaceTB/SmolLM2-135M \
  --hardware config/hardware/zcu104.json \
  --language ko \
  --render-only
```

프롬프트는 Git에서 제외된 `build/prompt_runs/`에 매번 새 파일로 저장됩니다.
원본은 [영어 프롬프트](prompts/model_hardware_accelerator.en.txt)와
[한국어 프롬프트](prompts/model_hardware_accelerator.ko.txt)로 나뉘며 입력과 절차는 같습니다.
실행기의 기본 언어는 영어입니다. `--language ko` 또는 `--language en`으로
프롬프트와 대화 언어를 선택합니다. 하드웨어 입력 데이터는 제공한 그대로 유지합니다.
`--checkpoint-revision <commit>`으로 모델 revision을 지정할 수 있습니다.
미지정이면 Codex가 정확한 checkpoint commit을 조사해 후보로 제시합니다.

첫 실행은 저장소 점검과 모델·하드웨어 조사, 연산→ISA→executor 후보 제안까지
진행합니다. 실행 범위·양자화·성능 목표와 ISA·모듈 경계는 사용자와 논의하며,
합의 전에 HDL 구현을 시작하지 않습니다. 기존 설계의 PASS를 새 설계에 상속하지
않습니다. 프롬프트 생성은 Python 표준 라이브러리만 사용하며, 모델 실행용 라이브러리와
FPGA 도구는 선택한 모델·보드의 구현 및 검증 단계에서 별도로 준비합니다.

## 아키텍처

```text
PS software
  모델 명령 순서 · DDR residency 타일링 · 오류 복구 결정
        ↓
PS-writable command BRAM + terminal END command + START
        ↓
isa_command_dispatcher
        ├─ datamover_executor: DMA_LOAD / DMA_STORE
        ├─ gemm_executor: GEMM
        └─ 이후 compute executor
```

- DDR/AXI 주소는 `DMA_LOAD`와 `DMA_STORE`만 받습니다.
- Compute는 검증된 논리 local bank ID만 받고 raw 주소나 bank offset을 받지 않습니다.
- Dispatcher는 명령을 route하고 response를 반환할 뿐 모델 scheduling을 하지 않습니다.
- PS는 실행 전에 전체 명령열을 command BRAM에 기록하며, streaming ring queue와
  producer/consumer index는 사용하지 않습니다.
- Dispatcher는 단일 PC의 현재 명령만 읽습니다. Native v3 controller는 현재 명령의
  방향별 bank acquisition 수락을 먼저 확인한 뒤 executor valid를 제시하고,
  executor handshake에서 PC를 증가시켜 다음 명령을 읽습니다. 막힌 현재 명령을 건너뛰지는 않지만, 서로 다른 bank를 사용하는 이전
  명령이 완료되기 전에도 다음 명령을 issue할 수 있습니다.
- 기존 공통 계약과 모델의 Bank ownership은 read/write로 나누지 않고 bank마다 하나의 exclusive
  `acquire/release/busy` 상태만 사용합니다.
- Command BRAM은 data-bank namespace 밖의 별도 memory입니다. 따라서 data bank `0`은
  예약되지 않으며 정상 operand bank로 acquire/release할 수 있습니다.
- GEMM은 local bank 안의 계산 타일링을 담당하고, DDR residency 타일링은 PS가 담당합니다.

명령 프로그램 publish 순서는 `END로 끝나는 instruction records → START`입니다. PL이
`BUSY`인 동안 PS는 해당 records를 수정하지 않습니다. Native v3는 executor valid 이전에
bank acquisition을 확인하고, 완료 response를 보관해 read drain과 release 수락까지
추적합니다. 완료 처리는 현재 PC와 독립적입니다.
`END`를 읽으면 새 명령 발행을 멈추고 모든 outstanding bank가 release된 뒤 `DONE`이 됩니다.

`C=A@B`의 명령열:

```text
DMA_LOAD  DDR_A → BANK_A
DMA_LOAD  DDR_B → BANK_B
GEMM      BANK_A, BANK_B → BANK_C
DMA_STORE BANK_C → DDR_C
```

## 최소 공통 계약

활성 공통 계약은 세 개뿐입니다.

```text
contracts/common/
├─ isa_command_contract.json
├─ local_bank_contract.json
└─ evidence_identity_contract.json
```

모델 shape, 정밀도, bank 개수, 배열 크기와 검증 기준은 설계별 파일에 둡니다. 이전의
module mapping approval, bringup stage, contract index 계층은 새 revision에서 사용하지 않습니다.

## 새 revision 흐름

```text
정확한 모델 revision·Transformers source 확인
→ model_trace.json
→ Agent가 모델별 opcode·executor 후보 제안
→ 사용자와 모듈 경계·공유·fusion 논의
→ 논의 결과로 ISA와 bank layout 결정
→ Python ISA interpreter 검증
→ 구현할 executor 하나의 연산·포트·bank 접근·수치·검증 방식을 사용자와 논의
→ 논의 결과로 현재 executor의 module contract 작성
→ 구현·독립 module verification
→ 누적 integration·board build
→ 사용자 FPGA 검증
→ 다음 executor도 구현 전에 같은 방식으로 논의
```

설계 파일:

```text
designs/<revision>/
├─ model_trace.json
├─ isa_spec.json
├─ bank_layout.json
├─ isa_validation.json
└─ modules/<module_id>.json
```

자세한 규칙은 [ISA 아키텍처](docs/isa_model_lowering.md)와
[최소 모델 bring-up 흐름](docs/model_graph_bringup.md),
[모델별 ISA·executor 설계 흐름](docs/framework_workflow.md)을 참고하세요.

## 검사

```bash
python3 scripts/check_common_contracts.py
python3 scripts/check_isa_design.py --design-dir designs/<revision>
python3 scripts/check_infrastructure_template.py --contract-only
python3 scripts/check_infrastructure_binding.py
python3 -m unittest discover -s verification/framework -p 'test_*.py'
```

검사기는 구조·경로·SHA-256·선언 일관성을 확인합니다. 수치 정확도, RTL, Vivado 또는
실물 FPGA 동작을 대신 증명하지 않습니다.

## Parent와 Child

Parent는 모델 trace, ISA, bank lifetime, opcode backlog와 현재 구현할 모듈 계약을
소유합니다. ISA 단계에서 모듈 목록을 논의한 뒤에도, Parent는 각 executor를
구현하기 전에 구체적인 구현 방식과 검증 기준을 사용자에게 제안하고 논의 결과를
해당 모듈 계약에 기록합니다. HDL 구현 Child는 배정된 모듈만 작성·자체 검증하고, 별도 검증 Child는
그 소스와 evidence를 독립적으로 감사합니다. 누적 보드 checkpoint가 사용자에게
수용되기 전에는 다음 executor 모듈을 시작하지 않습니다.

## 주요 경로

| 경로 | 역할 |
|---|---|
| `contracts/common/` | 네 공통 불변식 |
| `docs/` | ISA, 수치, 메모리와 board 흐름 설명 |
| `config/hardware/` | 보드 profile |
| `ip/infrastructure/datamover_engine/` | 기준 DataMover infrastructure |
| `ip/infrastructure/cmd_dispatcher_template/` | 별도 command BRAM과 MM2S/S2MM, 방향별 bank 수락·완료 drain을 갖는 controller 생성 template v4 |
| `ip/infrastructure/bank_ownership_table/template_contract.json` | 모델별 bank/owner 역할로 재사용할 ownership 코어 template |
| `ip/infrastructure/execution_fabric_template/` | ISA·bank·executor 연결을 채우는 fabric binding 및 RTL scaffold |
| `ip/infrastructure/bank_subsystem_template/` | MM2S/S2MM만 고정한 native bank 생성 template; 연산기 포트는 Agent가 설계별 생성 |
| `ip/infrastructure/bank_subsystem/rtl/bank_native_*.sv` | 읽기·쓰기 소유권, native routing, 설정 기반 memory 재사용 코어 |
| `scripts/` | 최소 계약 및 ISA 설계 검사 |
| `scripts/start_accelerator.py` | 모델·하드웨어 입력으로 프롬프트 생성 및 Codex 시작 |
| `prompts/` | 모델·하드웨어별 작업 프롬프트 template |
| `verification/framework/` | 검사기 회귀 테스트 |

기존 계약·구현·빌드·증거는 repository 밖 timestamp backup에 보존되어 있으며 새
revision의 evidence로 자동 상속하지 않습니다.

Native controller/bank 생성 template은 별도 방향별 소유권 계약을 채택합니다.
기존 모델의 exclusive ownership 계약과 RTL을 자동 변환하지 않습니다.

생성 engine은 `contracts/common/engine_completion_contract.json`에 따라 필요한
읽기 응답을 모두 처리하고 마지막 쓰기가 수락된 뒤 해제용 완료 응답을 보낸다.
Native controller v4에는 bank 읽기 pending 입력이 없다.
