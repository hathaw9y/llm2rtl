# Controller generation template

`cmd_dispatcher_template` v3는 제공된 controller의 명령 실행 흐름을 공통화한다.
MM2S/S2MM만 고정하고, compute opcode·engine 포트·operand 역할은 Agent가
`designs/<revision>/rtl/`로 가져온 생성물의 `USER_*` 영역에 추가한다.

```text
IDLE → CMD_READ → CMD_WAIT → OP_VERIFY → BANK_ACQUIRE → EXECUTE
                         다음 PC ← engine valid && ready ─┘
END → 모든 outstanding / read pending / owner / release drain → DONE
```

Command BRAM은 별도 native read port `cmd_enb/cmd_addrb/cmd_doutb`로 연결하며,
read latency는 `CMD_READ_LATENCY`로 정한다. Command BRAM은 data bank가 아니다.
MM2S/S2MM engine은 기존 DataMover typed command(addr/BTT/offset/bank/tag)와
status valid/ready/tag/error 포트를 사용한다. ISA record packing은 이전 template과
같으며 주어진 controller의 모델별 opaque payload나 연산기 opcode를 고정하지 않는다.

## Native bank 연결

[bank_subsystem_template](../bank_subsystem_template/README.md)과 직접 연결한다.
Ownership vector 방향은 `[BANK_NUM-1:0]`이며 각 방향에 다음 포트를 둔다.

- `bank_wr/rd_acquire_valid`, `bank_wr/rd_acquire_port`
- `bank_wr/rd_release_valid`, `bank_wr/rd_release_port`
- `bank_wr/rd_busy`, `bank_wr/rd_owner_port`
- `bank_wr/rd_acquire_accepted`, `bank_wr/rd_release_accepted`

추가로 `bank_rd_pending`, `bank_subsystem_error`를 받는다. Controller는 요청의
valid와 accepted를 같은 rising edge에서 샘플링한다. Busy만 보고 acquisition
성공으로 가정하지 않고, 모든 operand의 acquisition 후에만 engine valid를 올린다.
DMA는 예시처럼 해당 bank의 두 방향이 모두 free일 때 acquire한다.
`MM2S_BANK_MASK`/`S2MM_BANK_MASK`는 DMA가 사용할 수 있는 bank를 지정하며,
생성 package의 DMA bank mapping에 맞춰 설정한다.

Engine command valid/payload는 ready가 낮은 동안 안정적으로 유지한다.
진행 중 다른 명령의 오류 응답 때문에 이미 제시한 valid를 철회하지 않는다.
PC는 engine handshake 뒤에만 증가하며 막힌 명령을 건너뛰지 않는다.

## Completion과 END

DMA status는 valid && ready에서 수락한다. 완료한 bank를 기록해 두고, read
pending이 없어지고 matching-role release가 수락될 때까지 지우지 않는다.
완료와 release는 현재 PC와 독립적이다. Release role은 outstanding DMA 역할을
사용하며 현재 bank owner를 복사하지 않는다. 잘못된 tag, owner 불일치 및
보관 중 중복 완료는 오류이며 잘못된 bank를 release하지 않는다.

Tag는 기존처럼 bank ID다. 같은 bank가 재사용된 뒤 동일한 tag로 늦게 도착한 이전
status는 새 status와 구분할 수 없으므로 DMA status 전달에는 exactly-once 규칙이
필요하다. 이를 보장할 수 없는 transport는 별도 transaction generation/tag 계약이
필요하다.

END는 전체 pending command, 완료 보관 기록, read response pending과 양방향 busy를
확인한다. Protocol acknowledgement 실패와 bank subsystem 오류는 불완전한 release를
가정하지 않고 상태를 보존하며 controller/engine/bank의 coordinated reset을 요구한다.
일반 engine 오류는 matching completion의 안전한 retirement와 drain 후 종료한다.
첫 오류는 sticky하게 유지한다. 구체적인 상태와 오류 코드는 RTL과 계약을 따른다.

## Agent 생성과 이전 버전

Agent는 `USER_PORTS`, `USER_PARAMETERS`, `USER_OPCODES`, `USER_DECLARATIONS`,
`USER_DECODE`, `USER_ISSUE`, `USER_COMPLETION` 영역에서 연산기를 생성한다.
Read/write operand mask와 역할을 acquisition 단계에 지정하고, 명령 valid/ready와
완료 identity/pending/release 처리를 함께 구현한다. 여러 operand는 atomic하게 확보한다.
Compute 연산 자체는 이 controller가 수행하지 않는다.

공통 `local_bank_contract.json` v2와 기존 모델은 bank 전체의 single exclusive owner를
사용한다. 이번 template v3는 `template_contract.json`에 pin한 native bank 계약을
명시적으로 채택한다. 기존 model dispatcher/fabric은 자동 변환하지 않았다.
기존 v2 template 원본은 `history/v2/`, 당시 검증은 기존 `evidence/`에 보존했다.
과거 PASS를 v3에 상속하지 않는다.

```bash
python3 scripts/check_infrastructure_template.py
python3 -m unittest discover -s verification/framework -p 'test_infrastructure_template.py'
```

Checker는 source/contract 선언을 검사한다. RTL 동작은 self-checking simulator,
module 연결은 integration test, 합성과 timing은 실제 Vivado 증거로 따로 확인한다.

## 검증 결과와 재실행

[검증 기록](evidence/run_003/validation.md): XSIM command latency 1·2 각각
17개 사례와 DMA capability 거부 사례, 생성 연산기 확장 6개 사례가 통과했다.
Native XPM bank와 실제 payload를 비교했고, strict lint와 계약 검사도 통과했다.
Controller OOC 합성은 LUT579/FF212, BRAM/URAM/DSP0이며 5ns clock의 unplaced
추정 timing을 기록했다. 배치배선·외부 hold·보드 timing 검증은 포함하지 않는다.
[독립 검토](evidence/native_v3_review.md)는 현재 소스와 정확히 일치하는 증거를 확인했다.

```bash
python3 ip/infrastructure/cmd_dispatcher_template/scripts/run_xsim.py --work-dir /tmp/controller-new-sim --evidence-dir ip/infrastructure/cmd_dispatcher_template/evidence/new-sim
python3 ip/infrastructure/cmd_dispatcher_template/scripts/run_extension_probe.py --work-dir /tmp/controller-new-extension --evidence-dir ip/infrastructure/cmd_dispatcher_template/evidence/new-extension
```

Work/evidence 디렉터리는 매번 새 위치를 사용한다. 생성된 target 모델은 template
검증 PASS를 상속하지 않고 별도의 controller·bank·engine 연결 증거를 만든다.
