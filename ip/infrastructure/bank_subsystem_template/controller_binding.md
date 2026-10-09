# Controller와 native bank template 연결

사용자가 제공한 controller는 별도 command BRAM에서 명령을 읽고,
`OP_VERIFY → BANK_ACQUIRE → EXECUTE`에서 operand bank를 확보한 뒤 engine
command handshake로 다음 명령에 진행한다. Engine 완료 응답은 현재 PC와
독립적으로 operand bank를 release한다. 이 흐름을 생성 controller의 기준으로 삼는다.
Command BRAM은 data-bank namespace에 넣지 않는다.

공통 생성물에는 MM2S/S2MM만 고정한다. Weight 전용 MM2S, RMSNorm, GEMV,
ShortConv, elementwise 등은 해당 설계 Agent가 opcode·engine command/response·
bank role·native port를 함께 생성한다. Opcode는 owner ID가 아니다. Operand의
물리 포트 역할이 owner를 결정하며 같은 연산기의 input/output 역할도 구분한다.

## 명령 수락과 bank 수락

예시의 `bank_wr_acquire_o[b] != PORT_NONE`은 요청의 존재를 나타낸다.
Native template은 다음처럼 valid와 ID를 분리한다.

```text
bank_wr_acquire_valid[b] = (example.bank_wr_acquire_o[b] != PORT_NONE)
bank_wr_acquire_port[b]  = example.bank_wr_acquire_o[b]
```

Read도 같은 방식이다. `bank_*_accepted`는 요청을 샘플링하는 rising edge의
조합 수락 신호다. Controller는 valid와 accepted를 같은 edge에서 샘플링하고
다음 cycle에 요청을 내린다. Acquire 후 busy 또는 release 후 owner가 바뀌므로
다음 cycle에 accepted를 다시 조회하는 방식으로 확인하지 않는다.

하지만 예시의 `bank_acquire_done_r`를 그대로 수락 확인으로
사용하지 않는다. 요청을 한 cycle pulse로 보내고 `bank_*_acquire_accepted`로
전체 operand의 수락을 확인한 다음 engine command를 발행한다. 수락되지 않은
명령은 engine에 전달하지 않는다. BANK_ACQUIRE 동안 매 cycle 재요청하면 이미
acquire한 bank에 충돌이 발생한다.

Engine command valid는 ready와 무관하게 유지하며 valid && ready에서만 다음
명령으로 진행한다. Accepted command별로 operand bank와 방향별 owner를 기록하고,
완료 응답의 bank/tag가 그 outstanding 기록과 일치하는지 확인한다. Busy 검사만으로
데이터 유효성이나 RAW/WAR/WAW 의존성을 판단하지 않는다.

예시는 DMA writer/S2MM에 대해 두 방향 모두 free를 기다리지만 일부 연산기의 reader는
read 방향만 검사한다. 이런 조건은 scheduler의 의존성 정책이다. Native ownership은
각 방향의 배타성과 capability를 검사하며, 다른 방향의 동시 접근에 대한 데이터
안전성은 generated controller가 결정한다. Multi-bank 명령의 모든 방향별 operand는
같은 acquisition vector로 제출한다. 같은 bank의 read/write 동시 사용은 허용될 수
있지만 서로 다른 두 reader를 하나의 physical read port에 배정하면 안 된다.

## 완료 응답과 release

예시의 release는 bank bit만 가지고 있다. Native release는 valid와 owner를 함께
요구한다. Release owner는 **outstanding command에 저장한 포트 역할**을 사용한다.
현재 bank owner를 읽어서 복사하면 stale completion이 새 owner를 release할 수 있다.

Engine은 memory `resp_valid`를 받아 필요한 읽기를 모두 처리하고 마지막 쓰기가
수락된 뒤에만 controller에 해제용 완료 `resp_valid`를 발행한다. 완료 뒤에는 해당
명령의 memory 요청을 더 보내지 않는다. Memory 응답과 engine 완료 응답은 서로
다른 신호다. Bank나 controller의 별도 읽기 pending 추적은 사용하지 않는다.

Ready 없는 한 cycle 완료 응답은 bank/tag/owner를 먼저 register에 보관한다.
Matching release를 제출하고 `bank_*_release_accepted[b]`를 확인한 뒤 기록을
지운다. Release 수락 뒤 반복 요청을 중단한다. 이 공통 원칙은
[engine_completion_contract.json](../../../contracts/common/engine_completion_contract.json)을 따른다.

Ready 있는 완료 응답은 위 보관 공간이 확보되었을 때만 수락한다. 여러 engine이
같은 cycle에 완료할 수 있으므로 bank/owner release 충돌도 검사한다. 완료 error가
있더라도 이미 수락한 command의 valid를 철회하지 않으며, drain 또는 전체 reset
정책을 해당 controller contract에 명시한다. Bank subsystem error도 controller의
오류 상태로 전달한다.

## END와 읽기 데이터

END는 예시의 특정 src0/src1 bank 두 개만 검사하는 방식으로 일반화하지 않는다.
모든 outstanding command, 양방향 bank owner, 보관 중인
release가 비워진 뒤 DONE을 보고한다.

Native read latency는 request address register 1 + memory 3 = 4 cycle이다.
DMA/engine은 `*_bank_valid`에서만 doutb를 소비하며, 생성 wrapper는 응답을 현재
owner가 아니라 수락 시점에 저장된 response owner tag로 라우팅한다. 예시의
commit/prefix는 읽을 수 있는 word 범위를 나타내는 정보이며 response valid를
대체하지 않는다. In-place residual처럼 입력 prefix를 보존해야 하는 경우 해당
설계가 snapshot, write/read 충돌과 producer-consumer 의존성을 별도로 정의한다.

이 문서는 controller 연결 요구사항이다. 제공된 controller의 config package와
engine들이 저장소에 없으므로 controller 전체를 compile하거나 모델 실행을
검증했다는 의미가 아니다. 기존 model dispatcher/fabric의 단일 exclusive ownership
계약은 그대로 유지된다. 공통 `cmd_dispatcher_template` v4는 이 연결 규칙에 맞춘
native controller 생성 경로다.
