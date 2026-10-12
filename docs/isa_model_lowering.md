# PS-issued ISA 아키텍처

## 책임 경계

```text
PS software
  모델 명령 순서 · DDR residency 타일링 · retry/reset/abort 결정
        ↓
PS-writable command BRAM
  END로 끝나는 instruction records 전체 기록 → START publish
        ↓ fixed record + ready/valid
isa_command_dispatcher
  decode · 기본 operand 검사 · executor routing · response 반환
        ├─ datamover_executor
        ├─ gemm_executor
        └─ 이후 compute executor
```

dispatcher는 모델 scheduler가 아니다. 숨은 DMA를 삽입하거나 다음 연산을 결정하지 않는다.

## 단순 in-order scoreboard 실행

초기 command frontend는 streaming ring queue가 아니다. PS가 PL이 idle인 동안 완전한
프로그램을 BRAM에 적재하고 terminal `END`와 `START`를 마지막에 publish한다. PL이 busy인
동안 PS는 실행 중인 program image를 수정하지 않는다. 따라서 producer/consumer index가
없다.

Dispatcher는 하나의 program counter만 유지하고 현재 PC의 명령만 검사한다. 다음 조건이
모두 참일 때 executor와 ready/valid handshake로 명령을 issue한다.

- 입력 bank의 읽기 역할과 출력 bank의 쓰기 역할을 예약할 수 있다.
- 대상 executor가 명령을 받을 수 있다.
- Opcode·operand·접근 역할·data availability 검사가 성공한다.

현재 명령이 막히면 이후 명령을 검색하거나 추월시키지 않는다.
필요한 모든 방향별 bank 역할을 원자적으로 예약·확인한 뒤 engine command를 제시한다.
명령이 executor에 `valid && ready`로 수락되면 현재 명령을 한 번 진행시켜 다음 record를 읽는다.
예약과 command 수락은 다른 cycle일 수 있다. 예약부터 수락·완료·해제까지 명령 context를 유지한다.
Fetch 주소와 현재 명령의 identity·진행 조건을 구분해서 정의한다.
완료 응답은 현재 PC와 독립적으로 해당 명령이 소유한 방향별 bank 역할을 해제한다.
비충돌 명령은 engine 수용 능력 안에서 여러 개 outstanding일 수 있다.

기본 제어 상태는 다음과 같다.

```text
IDLE → FETCH → CHECK → BANK_ACQUIRE → ISSUE → 다음 FETCH
                       ↑              │
                 역할 충돌 시 대기    └─ valid/ready 수락
END → 모든 outstanding 응답·bank 해제 확인 → DONE
```

Bank는 읽기와 쓰기 owner를 따로 관리하며 같은 방향에는 하나의 owner만 허용한다.
MM2S는 쓰기 역할, S2MM은 읽기 역할, compute는 각 입력 읽기·출력 쓰기 역할을 사용한다.
읽기·쓰기 동시 실행은 명령별 충돌 정책, memory 동작과 데이터 준비 범위를 만족할 때 허용한다.
소비자는 준비된 `read_addr < commit` 범위 안에서 읽고 owner/busy와 데이터 유효성을 혼동하지 않는다.
완료 시 해당 명령의 실제 방향·포트 역할만 해제한다.

과거 `contracts/common/isa_command_contract.json`·`local_bank_contract.json`과 기존 검사기는
single-exclusive 방식의 호환 계약이다. 새 방향별 설계 계약과 검증은 revision에서 분리한다.
구체적인 연결·충돌·generation 규칙은 `docs/framework_workflow.md` 1.5절을 따른다.

Command BRAM은 이 data-bank namespace에 포함되지 않는 별도 memory다. PS는 AXI BRAM
Controller의 한 포트로 command를 기록하고 dispatcher는 반대쪽 native BRAM 포트로
읽는다. 그러므로 data bank `0`도 다른 bank와 동일하게 합법적인 operand bank다.

실패한 명령은 destination을 `ready`로 commit하지 않는다. 명령의 물리 방향별 owner는
완료·memory drain 뒤 해제한다. source tensor의 논리 lifetime 종료·데이터 무효화는
ISA의 명시적 flag 또는 control 명령으로 표현하며 dispatcher가 임의로 수명을 추론하지 않는다.
두 상태의 유지·종료 조건을 구조 계약에서 구분한다.

## 주소와 bank

```text
DMA_LOAD  (DDR source address, destination bank, transfer configuration)
DMA_STORE (source bank, DDR destination address, transfer configuration)
COMPUTE   (input bank IDs, output bank IDs, shape/numeric configuration)
```

외부 DDR/AXI 주소는 `DMA_LOAD`와 `DMA_STORE`만 받는다. Compute는 논리 local
`bank_id`만 tensor operand로 받으며 DDR 주소, local raw address, bank base 또는
bank offset을 받지 않는다. router가 bank ID를 physical base, extent, format/layout,
valid/busy와 owner로 해석한다. 부분 영역을 독립 operand로 써야 하면 별도 논리 bank를
할당한다.

`C=A@B`의 host-visible 실행은 다음과 같다.

```text
DMA_LOAD  DDR_A → BANK_A
DMA_LOAD  DDR_B → BANK_B
GEMM      BANK_A, BANK_B → BANK_C
DMA_STORE BANK_C → DDR_C
```

GEMM은 local bank 범위 안에서 systolic 계산 타일링을 소유할 수 있다. 전체 tensor가
온칩에 들어가지 않아 필요한 DDR residency 타일링은 PS가 위 명령열을 반복해 표현한다.

## 새 revision 파일

ISA와 executor 목록은 모델별로 정한다. Parent Agent는 실제 모델 trace에서 후보
opcode·모듈 목록과 재사용·fusion 선택을 만들어 사용자에게 제시하고 논의한다.
그 결과로 구조 계약을 작성해 실제 모듈 경계·연결·재사용·파이프라인과 허용한 선택 범위를 정한다.
구조 의무를 요구사항·출처·검사에 연결하고 남은 미결정 사항의 영향 범위를 기록한다.
ISA validation과 현재 모듈 계약은 이 구조를 참조하며 구현 Agent는 구조 계약에서 구현 대응표를 도출한다.
공통 command 전송 계약은 모델별 모듈 목록을 대신 결정하지 않는다.

```text
designs/<revision>/
├─ model_trace.json
├─ isa_spec.json
├─ bank_layout.json
├─ structure_contract.json
├─ isa_validation.json
└─ modules/
   └─ <implemented_module>.json
```

- `model_trace.json`: 실제 Python source identity, workload와 semantic operation 목록.
- `isa_spec.json`: fixed instruction record, opcode/module과 operand 종류.
- `bank_layout.json`: 논리 bank capacity, format/layout와 허용 producer/consumer.
- `structure_contract.json`: ISA·bank·수치 계약을 참조한 모듈·연결·제어·pipeline·재사용·검증 의무.
- `isa_validation.json`: 모든 지원 operation의 instruction lowering, Python interpreter 결과.
- `modules/*.json`: 현재 구현할 한 모듈의 interface/numeric/verification 범위.

실행 trace는 관찰한 경로의 증거이지 모든 분기의 증명이 아니다. 지원한다고 선언한 모든
semantic operation은 ISA lowering을 가져야 하며 tensor 수학을 host에서 숨겨 수행할 수 없다.
미결정 사항이나 interpreter 실패의 영향받는 모듈·경계를 명시하고 해당 RTL 구현을 시작하지 않는다.
구조 계약의 항목·구체적인 작성과 적용 방법은 [구조 계약 지침](structure_contract.md)을 따른다.

## 증분 구현

opcode 목록은 구현 backlog다. 현재 opcode의 구조 의무와 모듈 계약을 작성하고 module verification,
누적 integration, board build, 사용자 FPGA 검증을 통과한 뒤 다음 opcode를 구현한다.
과거 revision의 PASS나 artifact를 새 revision의 결과로 바꾸지 않는다.
