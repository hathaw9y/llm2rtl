# 모델별 ISA·executor 설계 흐름 (초안)

목표는 지정한 모델의 지원 실행 경로를 PS가 만든 ISA 명령열과 PL executor만으로
실행하는 것이다. PS는 명령 순서, 타일링, 주소, 재시도와 같은 제어를 담당한다.
모델의 tensor 수학을 PS 코드나 미선언 외부 연산에 숨기지 않는다.

## 1. 공통 infrastructure

새 설계는 `ip/infrastructure/sources.json`에 등록된 활성 RTL을 기본 참조로 사용한다.
`ip/infrastructure/README.md`와 실제 소스를 읽고 포트·주소 단위·cycle·리셋·의존성을 확인한다.
활성 RTL 15개는 bank 8개, controller 1개, utils 3개, datamover 3개다.

- DMA: `datamover/mm2s_engine.sv`, `datamover/s2mm_engine.sv`의 bank 직접 연결·내부 FIFO·handshake·완료/오류 처리를 기준으로 한다.
- 설정·utility: `datamover/config_pkg.sv`, `utils/fifo.sv`, `utils/pipeline.sv`의 실제 의존성을 따른다.
- Bank: `bank/`의 memory·중재·ownership/router에서 필요한 기능을 선택한다.
- Controller: `controller/cmd_dispatcher_template.sv`의 기존 인터페이스·제약을 확인하고 새 ISA에 맞는 수정 범위를 정한다.

각 선택 모듈의 그대로 재사용·parameter 변경·수정·새 구현 여부와 이유를 기록한다.
맞는 기능은 우선 재사용하며 모델별 변경은 `designs/<new_revision>/`에 분리한다.
`config_pkg`는 레퍼런스 모델 설정이므로 bank ID·폭·payload·수치를 새 W4A4KV4 계약으로 자동 상속하지 않는다.
명령 해석·소유권·동시 실행·완료/오류는 해당 ISA와 bank 계약에서 정하고 새 구성으로 검증한다.
삭제한 generic channel·adapter·command queue·AXIS 폭 변환기와 archive는 기본 참조로 선택하지 않는다.

기존 분리 RTL 9개와 작성 template 6개는 활성 경로에서 삭제하고
`ip/infrastructure/archive/pre_reference_integrated_20261012/`에 보존했다.
이전 호환 profile은 `--include-compatibility`를 명시할 때만 선택된다.

## 1.1 여러 포트로 stripe bank에 Weight 공급

Weight는 여러 전송 포트를 활용해 stripe bank에 공급한다.
포트 수 `N`과 포트별 폭 `W`는 대상 하드웨어의 메모리 인터페이스·실효 대역폭,
계산 engine의 Weight 소비율과 자원 예산을 기준으로 정한다.
특정 보드의 HP 포트 수나 레퍼런스의 4-port 구성을 공통 요구사항으로 고정하지 않는다.
레퍼런스 `striped_weight_bank`의 포트별 stripe 연결 방식을 참고하되 선택한 `N`에 맞게 구현한다.

| 경로 | 연결 규칙 |
| --- | --- |
| Weight 쓰기 port p | 포트별 enable/address/data/byte enable → 대응 stripe p |
| Weight 읽기 | 공통 read enable/address로 필요한 stripe를 동시에 읽기 |
| 계산 engine 입력 | stripe p를 합의한 packing 순서로 결합해 전달 |
| 데이터 준비 | 소비할 모든 stripe의 유효 데이터가 준비된 범위에서만 읽기 허용 |
| Controller 완료 | 관련 전송·status와 필요한 쓰기를 확인한 뒤 Weight load 완료 처리 |

여러 포트의 쓰기 경로를 보존하고 불필요한 단일 쓰기 mux로 직렬화하지 않는다.
각 stripe의 유효 연속 쓰기 범위를 추적하고 전체 읽기 가능 범위는 필요한 stripe들의
범위 최솟값으로 판단한다. 부분 byte write·주소 건너뜀·순서 역전이 있으면 단순 마지막
쓰기 주소만으로 준비 완료를 선언하지 않는다. 전송 계약이나 실제 유효성 추적을 명시한다.
포트별 stall·완료 순서 차이·오류가 있어도 미완성 Weight를 계산 engine에 전달하지 않는다.

### 데이터 배치 예시

모든 stripe를 한 번에 읽고 포트별 폭이 같다면 결합 읽기 폭은 `N × W`비트다.
결합 word의 stripe p는 합의한 포트 순서에 따라 `p × W` 위치에 배치한다.
DDR layout과 포트별 stream이 이 배치에 맞도록 주소·전송량·tail 처리를 정한다.
연속 packed 데이터를 임의의 큰 블록으로 나누면 결합 읽기 순서와 달라질 수 있다.
Scale·zero-point metadata는 별도 크기·주소·layout으로 정의한다.

활성 `mm2s_engine.sv`의 command·status·FIFO 처리를 참고하되 이 파일 하나가
여러 포트의 Weight loader 전체를 제공한다고 가정하지 않는다.
새 revision에서 선택한 포트 수에 맞는 전송 경로·stripe bank 연결·완료 집계를 구현·검증한다.
레퍼런스의 고정 4-port 결합이나 commit reduction도 `N`에 맞게 확인한다.

검증은 stripe별 데이터 순서·주소·byte enable, 결합 읽기 순서, 독립 stall,
완료 순서 변화, 오류·reset, commit 경계·tail을 포함한다.
논리 포트 수와 실제 독립 메모리 경로 수를 구분하고 처리량은 측정 결과로 보고한다.

## 1.2 적용 예시: bank 데이터를 DDR에 저장하기

예를 들어 64비트 bank에서 24바이트를 저장하면 3 beat가 필요하다.
`datamover/s2mm_engine.sv`와 `utils/fifo.sv`·`utils/pipeline.sv`를 기본 입력으로 사용한다.
Bank ID·word offset·DDR byte 주소·BTT를 합의한 payload로 전달한다.
`BANK_RD_LATENCY`는 연결한 bank와 mux/pipeline을 포함한 실제 읽기 지연으로 정한다.

검증에서는 bank 반환 데이터의 순서, `tready=0` 동안 output data/keep/last의 안정성,
읽기 요청과 outstanding credit, 마지막 beat의 `tlast`, status 오류와 완료 시점을 확인한다.
마지막 데이터가 만들어졌다는 이유만으로 bank를 해제하지 않는다. 합의한 완료 조건을 검사한다.
추가로 부분 beat가 있는 전송을 시험하고 BTT에 맞는 `tkeep`과 마지막 beat를 비교한다.

## 1.3 적용 예시: cmd_dispatcher_template 사용

기준 파일은 `ip/infrastructure/controller/cmd_dispatcher_template.sv`다.
이 파일을 새 revision의 controller 작성 출발점으로 사용한다.
기존 파일을 그대로 덮어쓰지 않고 재사용 부분과 변경 부분을 기록한다.
아래는 계산 engine을 추가하기 전 DMA_LOAD → DMA_STORE → END 연결 예시다.
현행 MM2S/S2MM engine과 포트가 다르므로 연결 수정이 필요한 예시이며 완성된 top RTL이 아니다.

### 명령 메모리와 시작·종료 연결

PS가 command BRAM에 전체 명령열을 기록한 뒤 `cmd_dispatcher_start`를 한 클록 발생시킨다.
BRAM의 읽기 enable·주소·data를 각각 `cmd_enb`, `cmd_addrb`, `cmd_doutb`에 연결한다.
`CMD_READ_LATENCY`는 연결한 command BRAM과 중간 pipeline의 실제 지연에 맞춘다.
PS는 `cmd_dispatcher_busy`, `cmd_dispatcher_done`, `cmd_dispatcher_error`,
`cmd_dispatcher_error_code`를 상태 register로 읽고 `current_pc`를 진단에 사용한다.
BUSY 동안 명령 메모리를 변경하지 않는다.

### 기존 명령 형식으로 만드는 작은 프로그램

다음 bit 위치는 파일의 기본 parameter인 `CMD_DATA_WIDTH=128`, `OPCODE_WIDTH=4`,
`BANK_NUM_WIDTH=4`, `BANK_ADDR_WIDTH=32`, `BTT_WIDTH=23`, `AXI_ADDR_WIDTH=32`에만 해당한다.
Parameter를 바꾸면 위치를 다시 계산한다. 이것은 이 controller의 3-bank-field 형식이며
새 모델의 SRC0~SRC3 형식이 아니다.

| 필드 | 기본 bit 위치 | LOAD 예시 | STORE 예시 |
| --- | --- | --- | --- |
| opcode | 127:124 | 1 (`OP_MM2S`) | 2 (`OP_S2MM`) |
| operand0 bank | 123:120 | 0 | 0 |
| operand1 bank | 119:116 | 0 | 0 |
| operand2 bank | 115:112 | 0 | 0 |
| bank word offset | 111:80 | 0 | 0 |
| byte count | 79:57 | 128 | 128 |
| DDR byte address | 56:25 | `0x1000` | `0x2000` |
| unused low bits | 24:0 | 0 | 0 |

- PC=0: DDR `0x1000`의 128바이트를 bank 0으로 읽는다.
- PC=1: bank 0의 같은 128바이트를 DDR `0x2000`으로 쓴다.
- PC=2: opcode=0 (`OP_END`), 나머지 필드=0으로 종료한다.

Bank 0은 설명용이다. 실제 `MM2S_BANK_IDS`·`S2MM_BANK_IDS`에 연결한 bank를 사용하고
controller의 `MM2S_BANK_MASK`·`S2MM_BANK_MASK`도 같은 접근 가능 bank 집합으로 맞춘다.
현재 engine의 `config_pkg`는 이 예시와 bank 수·폭이 다를 수 있으므로 별도 설정을 확정한다.

### 활성 MM2S/S2MM engine에 맞추는 부분

| Controller 포트 | 활성 engine 포트 | 필요한 연결·수정 |
| --- | --- | --- |
| `m_ctrl_mm2s_cmd_valid/ready` | `s_ctrl_mm2s_cmd_valid/ready` | valid를 engine 입력에, engine ready를 controller 입력에 연결 |
| `m_ctrl_mm2s_cmd_bank` | `s_ctrl_mm2s_cmd_dst_bank` | bank ID 폭과 접근 가능 bank 집합을 일치시킴 |
| `m_ctrl_mm2s_cmd_addr/offset/btt` | `s_ctrl_mm2s_cmd_payload` | engine의 실제 slice 위치대로 payload를 구성하고 예약 bit를 명시 |
| `s_ctrl_mm2s_sts_valid/error/tag` | `m_ctrl_mm2s_resp_valid/error/bank` | 이 controller는 tag=bank ID이므로 폭을 맞춰 bank를 tag로 변환; valid·error 전달 |
| `m_ctrl_mm2s_sts_ready` | 해당 입력 없음 | engine 응답 발생 시 controller 수락을 보장하는지 확인; 보장할 수 없으면 모델별 controller에 응답 보존 처리 |
| S2MM의 대응 포트 | S2MM의 command·response 포트 | 같은 기준으로 payload·bank·response 연결 |

Engine의 payload는 DDR 주소 → bank word offset → 예약 1bit → BTT 순서의 slice를 사용한다.
Controller의 command word 전체를 그대로 payload로 연결하지 않는다.
Controller의 command tag를 vendor DataMover tag와 동일한 것으로 가정하지 않는다.
`resp_error_code`는 기존 controller에 직접 대응하는 포트가 없으므로 모델별 오류 register나
진단 경로에 보존할지 명시한다.

### Bank 획득·해제와 실행 순서

현재 controller는 방향별 `bank_wr_*`·`bank_rd_*` 소유권과 실제 acquire/release 수락을 요구한다.
현재 bank 모듈의 인터페이스가 이 계약과 일치하는지 먼저 대조한다.
일치하지 않으면 모델별 controller/bank 연결을 수정한다. 수락 신호를 상수 1로 묶어 통과시키지 않는다.

| 단계 | controller에서 확인할 동작 |
| --- | --- |
| LOAD 읽기·검사 | PC=0 명령과 bank mask·전송량 검사 |
| Bank 획득 | bank 0 쓰기 소유권 획득 수락 후에만 MM2S command 제시 |
| MM2S 수락 | valid/ready에서 명령 수락, PC 진행; 수락 전에 command 유지 |
| STORE 대기 | PC=1의 읽기 획득은 합의한 read/write 충돌 정책을 따름 |
| MM2S 완료 | 데이터·status 처리 후 응답 수락, 쓰기 소유권 해제 수락 확인 |
| S2MM 실행 | 읽기 소유권 획득 후 command 수락; bank 데이터·status 처리 후 해제 |
| END | 추가 발행 중단, 모든 pending 완료와 bank 해제 이후 DONE |

이 round-trip 예시는 **동일 bank의 LOAD 완료 전에 STORE 읽기를 허용하지 않는 정책**으로 검증한다.
방향별 소유권만으로 데이터 준비가 보장되지는 않는다. 현재 bank 연결이 read/write overlap을
허용한다면 이 예시를 안전하게 실행하도록 controller의 의존성 판단이나 명령열을 수정해야 한다.

### 계산 opcode를 추가할 때

기존 DMA·fetch·오류·END 동작을 참고하고 새 revision에서 계산 command·completion을 추가한다.
파일의 `USER_PORTS`, `USER_OPCODES`, `USER_DECODE`, `USER_ISSUE`, `USER_COMPLETION` 구역은
확장 위치를 찾는 참고이며 그 구역을 채우는 방식 자체를 강제하지 않는다.
Opcode 0·1·2는 기존 END·MM2S·S2MM이므로 새 opcode와 충돌시키지 않는다.
계산 연산은 입력·출력 bank, command 수락, pending 추적, 실제 완료, bank 해제를 모두 연결한다.
Opcode 상수만 추가하고 연산을 수행하지 않는 구현을 완료로 취급하지 않는다.

### Agent에게 전달할 작업 예시

> `cmd_dispatcher_template.sv`를 바탕으로 새 revision의 controller를 작성한다.
> 첫 검증 범위는 위의 MM2S → S2MM → END round-trip이다.
> 기존 명령 fetch와 오류·END drain 동작을 재사용하고, 활성 MM2S/S2MM engine의
> payload·response 및 선택한 bank 인터페이스와 맞지 않는 부분만 수정한다.
> 동일 bank의 STORE는 LOAD의 정상 완료·쓰기 해제 이후 실행되도록 한다.
> 변경 전후 포트·명령 형식·소유권·완료 조건과 변경 이유를 기록한다.
> Command stall, 완료 응답 지연·오류, reset, 잘못된 opcode·bank ID, END 대기와
> DDR round-trip 데이터 일치를 검증한다.

이 문서의 예시는 구현 요청 형식이다. 이 controller와 활성 DMA의 통합 동작 검증이 완료된 결과가 아니다.

## 1.4 Executor의 bank 읽기는 파이프라인으로 처리

각 executor는 bank 출력을 계산 core에 직접 조합 연결하지 않는다.
읽기 요청 발행 → bank 응답 대기·제어 정렬 → operand register → 계산 core 순서로 연결한다.
Weight·activation·scale·KV 등 실제로 읽는 모든 operand 경로에 이 기준을 적용한다.

| 단계 | 설계 기준 |
| --- | --- |
| 읽기 발행 | 필요한 stripe의 데이터 준비, bank 접근 조건과 응답 저장 여유를 확인하고 read enable·주소 발행 |
| 응답 정렬 | 실제 bank 읽기 지연만큼 valid·last·mask·operand index·transaction metadata를 데이터와 정렬 |
| Operand register | 유효한 응답 데이터를 register에 저장하고 operand valid와 함께 다음 단계로 전달 |
| 계산 입력 | 같은 연산에 속한 operand들의 도착 시점을 맞춘 뒤 계산 core에 입력 |
| Drain | 남은 읽기 응답·operand·계산 파이프라인과 최종 쓰기를 처리한 뒤 완료 응답·bank 해제 |

`utils/pipeline.sv`를 고정 지연 제어 정렬에 활용한다.
등록된 CE로 packet을 포착하는 경계는 `utils/registered_capture.sv`의
[계약과 예시](registered_capture.md)를 우선 확인한다. 실제 응답 수락 시점과
E0 준비→E1 출력→E2 downstream sampling, 반환 공간 예약을 현재 구조 계약에 대응시킨다.
`BANK_RD_LATENCY`는 memory 자체뿐 아니라 실제 bank mux·중간 register를 포함한 요청부터 응답까지의 지연이다.
Operand register와 core 내부 지연은 그 이후의 단계로 별도 기록하며 지연을 중복 계산하지 않는다.
Operand별 bank 지연이 다르면 추가 정렬 register나 응답 buffering으로 같은 연산의 데이터를 맞춘다.
읽기 이후 bank 선택·주소·mode가 바뀌더라도 이전 요청의 metadata가 유지돼야 한다.

`pipeline.sv`는 매 클록 진행하는 고정 지연 모듈이며 ready/stall 기능이 없다.
Backpressure가 있는 core에 연결할 때는 반환 중인 읽기까지 수용할 FIFO/버퍼와 outstanding credit을 두거나
설계에서 그와 동등한 수용 능력을 보장한다. 새 요청만 멈추고 이미 발행한 응답을 버리면 안 된다.
Reset 또는 명시한 cancel 정책에서 pending valid를 무효화해 이전 transaction의 데이터가 새 연산에 들어가지 않게 한다.

예를 들어 bank 응답까지의 지연이 L클록이고 operand register가 1단이면,
요청 metadata를 L클록 지연해 bank data와 맞춘 뒤 register에서 함께 포착한다.
계산 core는 그 다음 operand 단계의 data·valid를 사용한다.
이 예시는 구조 설명이며 실제 sampling edge와 core 입력 수락 cycle은 모듈별 cycle 표로 확정한다.

검증은 요청·응답·operand·계산 입력 간 데이터/valid 정렬, 연속 요청과 bubble,
서로 다른 operand 지연, 마지막 요청 후 drain, stall·reset과 이전 응답의 혼입 여부를 포함한다.
파이프라인을 추가한 경우 latency·처리 간격·buffer 용량과 완료 조건을 함께 갱신한다.

## 1.5 Bank 읽기·쓰기 소유권을 분리

새 설계는 각 bank에 읽기 owner와 쓰기 owner를 별도로 둔다.
읽기 상태는 `bank_rd_busy/owner`, 쓰기 상태는 `bank_wr_busy/owner`로 구분하고
획득·해제도 `bank_rd_acquire/release`와 `bank_wr_acquire/release`로 분리한다.
Owner는 opcode가 아니라 실제 engine의 operand 포트 역할을 나타낸다.
같은 방향에는 동시에 하나의 owner만 허용한다.

계산 engine의 입력은 읽기 역할, 출력은 쓰기 역할로 예약한다.
MM2S는 쓰기 역할, S2MM은 읽기 역할을 사용한다.
어떤 명령이 반대 방향까지 비어 있어야 하는지는 명령별 충돌 정책에서 정한다.
단순 round-trip 예시의 STORE는 LOAD 완료 뒤 실행하지만, 계산 소비자는 안전한 경우
진행 중인 writer와 겹쳐 실행할 수 있다.

읽기·쓰기 동시 owner가 있다는 이유만으로 데이터가 준비됐다고 판단하지 않는다.
소비자는 `read_addr < commit`인 유효 범위 안에서만 읽고, memory의 same-address
read-during-write 정책과 pipeline 지연도 확인한다.
`commit`은 읽기 word 단위의 준비 범위 끝이며 owner/busy, tensor의 최종 유효성, lifetime과 구분한다.
새 write 세대의 commit 초기화, append 여부와 in-place 연산의 이전 입력 범위 보존을 명시한다.

명령에 필요한 모든 방향별 bank 역할을 한 번에 예약한다. 일부만 획득한 상태로 실행하지 않는다.
예약 확인 이후 engine command를 제시하고 수락부터 응답·잔여 memory drain·해제까지 context를 유지한다.
같은 cycle의 release/acquire 우선순위, 실제 owner 변경 edge와 수락 확인 방법을 계약에 기록한다.
Accepted 포트가 있는 모듈은 실제 accepted를 확인하고, 없는 레퍼런스 인터페이스는
owner 상태·clock 규칙으로 획득을 확인한다. 없는 신호를 상수로 대체하지 않는다.
완료 응답은 해당 명령이 소유한 방향·포트 역할만 해제한다.

모델별 bank subsystem은 방향별 owner 상태, engine 직접 포트, 선택 mux, commit와
실제 memory 연결을 함께 정의한다. 별도 범용 ownership/router 계층을 선행 과제로 만들지 않는다.
현재 `bank_ownership_table.sv`는 단일 exclusive 방식이므로 그대로 방향별 구현으로 사용할 수 없다.
사용할 공통 primitive의 호환 범위를 확인하고 필요한 모델별 연결은 새 revision에 작성한다.

`contracts/common/local_bank_contract.json`과 `isa_command_contract.json` 및 기존 검사기는
이전 single-exclusive·command acceptance와 같은 cycle 예약 계약을 보존한다.
새 방향별 설계의 계약은 revision에서 별도 작성하며 이전 JSON을 조용히 덮어쓰지 않는다.
이전 검사 PASS를 방향별 소유권 검증으로 표시하지 않는다.

검증은 same-direction 충돌, 안전한 read/write overlap, commit 밖 read 차단,
원자적 multi-bank 예약, 잘못된 owner release, 동시 acquire/release와 마지막 응답 후 해제를 포함한다.

## 2. 모델별 ISA 논의

Agent는 정확한 모델 코드·revision, 실행 조건, 연산 방식, 양자화 방식과 하드웨어
정보를 읽고 지원할 prefill/decode 경로의 semantic operation을 빠짐없이 기록한다.
각 operation을 어떤 ISA 명령열로 표현할지 후보와 근거를 사용자에게 제시한다.
사용자와 명령의 경계, fusion, 수치 형식, PS/PL 상태 소유권, 모델 실행의
출력 경계(예: logits 출력과 토큰 선택 중 어디까지 포함할지)를 논의한 뒤
`isa_spec.json`과 bank layout을 정한다. ISA는 모델별 설계 결과이며 공통
infrastructure가 연산 opcode 집합을 미리 결정하지 않는다.

## 3. Executor 모듈 논의

Agent는 결정된 각 opcode가 필요로 하는 executor와 공유 가능한 모듈을 제안한다.
사용자와 모듈의 분할·공유·입출력 bank·데이터 layout을 논의한다. 모든 지원
semantic operation에는 ISA lowering과 실행할 executor가 있어야 한다.
opcode 목록만 존재하거나 아직 구현되지 않은 executor는 실행 완료로 간주하지 않는다.

## 3.1 구조 계약으로 구현 구성 결정

동작·ISA 계약은 무엇을 실행하고 언제 수락·완료할지 정한다.
여기에 **구조 계약**을 추가해 모듈 분할·공유, controller→engine→core→bank/DMA 연결,
방향별 owner, 여러 포트의 Weight stripe 배치, executor 읽기 파이프라인과
buffer/credit·완료 경로를 어떻게 구현할지 정한다.
후보 논의에서 `designs/<revision>/structure_contract.json`을 작성하고,
현재 executor의 구현 방식을 정할 때 해당 구조 의무를 구체화한다.

각 구조 의무에는 ID·요구사항/출처·결정 이유·적용 모듈/연결·고정 값과
조정 가능한 범위·검사 방법/기대 결과를 기록한다.
ISA·bank·수치 계약과 활성 infrastructure의 경로·버전·해시를 참조한다.
현재 모듈 packet은 구조 계약의 버전·해시와 적용 의무 ID를 포함하고,
구현 Agent는 이를 읽어 파일·인스턴스·포트·parameter·cycle의 대응표를 만든 뒤 구현한다.
미결정 사항은 영향받는 모듈·경계에 연결하며 이미 합의한 결정은 다시 승인받지 않는다.
항목·예시·변경 및 검증 절차는 [구조 계약 지침](structure_contract.md)을 따른다.

## 4. 모듈 구현 방식 논의

ISA 단계에서 executor 목록을 정했더라도 각 executor의 구현 방식까지 확정한 것은
아니다. Agent는 **새 executor를 구현할 때마다**, RTL을 작성하기 전에 사용자에게
그 명령이 수행할 연산 범위와 입력·출력, 재사용 또는 fusion 선택을 제안한다.
연산 알고리즘, 양자화·중간 정밀도·반올림, bank 데이터 접근·결과 유효성,
tile 크기·병렬도, 명령 수락·완료 응답의 포트와 동시 실행 한도, 목표 클럭·자원,
ISA simulator의 명령별 golden 값과 RTL 검증 기준도 함께 논의한다.
Agent는 선택지의 비용과 정확도 영향을 설명하고 미결정 사항을 기록한다.
논의 결과가 구조 계약의 해당 의무와 현재 모듈 계약에 반영되기 전에는 해당 executor의 RTL 구현을
시작하지 않는다. 합의한 동작·구조 계약으로 구현·독립 검증·누적 통합·보드 검증을 진행한
뒤, 다음 executor도 같은 방식으로 논의한다.

## 5. 모델별 작성과 연결

Agent는 선택한 활성 infrastructure와 재사용·수정 목록을 구현·검증 입력으로 전달한다.
실제 파일 경로·해시·인터페이스·의존성을 기록하고 합의한 설계 revision에 필요한 코드를 작성한다.
구현·검증 Agent에게 같은 구조 계약과 현재 모듈의 구현 대응표를 전달한다.
검증 Agent는 실제 RTL의 구성·연결을 구조 의무에 대조하며 파일 존재나 과거 PASS만으로 통과시키지 않는다.
허용 범위 밖의 구조 변경은 이유와 영향받는 의무·모듈·검사를 기록하고 새 계약 버전으로 재검증한다.
기존 generic 템플릿의 USER 영역을 채우는 절차를 강제하지 않는다.
별도 범용 executor·ownership/router·adapter·command queue를 선행 과제로 만들지 않는다.

명령 수락, context 저장, PC 진행, 동시 실행, memory 응답과 최종 쓰기 수락,
완료·오류 응답, bank 해제와 END 조건을 해당 설계에서 명시한다.
필요한 FIFO·읽기 지연·backpressure 처리를 유지하고 독립 검증으로 확인한다.

`scripts/infrastructure_sources.py --check`는 공통 소스의 해시와 의존성을 검사한다.
기존 ISA/template/binding 검사기의 PASS는 새 모델의 검증을 대신하지 않는다.
새 설계의 계약·schema와 검사 기준을 만들고 생성 RTL에 맞는 증거를 기록한다.

## 전체 모델 실행의 완료 조건

- 지원 범위의 모델 진입점부터 출력까지 모든 tensor 연산과 상태 갱신이 trace에
  포함되고, 각 연산이 ISA 명령열로 lowering된다.
- PS 프로그램 생성기는 해당 입력과 상태에서 유효한 명령열을 만들며, PS가 모델
  tensor 연산을 직접 수행하지 않는다. 메모리 이동과 KV cache 접근도 명시된다.
- Python ISA interpreter가 실제 tensor 값과 상태를 실행해 모델 reference와
  정해진 수치 기준으로 비교한다. 명령 발행 순서만 맞춘 검증은 여기에 해당하지 않는다.
- 모든 opcode의 executor와 공통 infrastructure가 같은 ISA·bank·수치 계약으로
  연결되고, 전체 prefill/decode 실행을 보드에서 reference와 비교한다.
- 사용자와 정한 출력 경계 및 지원하지 않는 경로와 실행 범위(예: 최대 context,
  입력 형식)를 명시한다. 토큰 선택을 ISA에 포함할지는 프레임워크가 미리 정하지
  않는다. 일부 경로만 통과했다면 전체 모델 실행 완료로 표시하지 않는다.

현재 `issue_r4`의 projection 제어 흐름 검증은 이 완료 조건의 일부이며,
전체 모델의 tensor 실행 증거는 아니다.

Engine 완료 응답은 필요한 memory 응답을 모두 수신·처리하고 최종 쓰기가
수락된 뒤에 발행한다. 명시적 `resp_valid` 또는 검증한 고정 지연의 내부 response-valid를
구조·모듈 계약에서 선택한다. Controller는 명령에 대응하는 완료 응답으로 bank를 release하고
해제 시점과 실제 state 전이를 확인한다. 생성 engine 계약과 연결 테스트는
`contracts/common/engine_completion_contract.json`의 원칙을 검증한다.
