# Command dispatcher infrastructure template

이 디렉터리는 설계별 `isa_command_dispatcher`를 생성할 때 복사해서 사용하는 공용
SystemVerilog template이다. 공통 부분은 command fetch, MM2S/S2MM typed command와
completion 추적이다. 실제 bank ownership state는 별도 `bank_ownership_table`이 소유한다.

## Command BRAM

Command BRAM은 data bank에 포함하지 않는다. Block Design에서 AXI BRAM Controller의
Port A를 PS에 연결하고, 반대쪽 native Port B를 template의 다음 포트에 연결한다.

```text
PS M_AXI_HPM → AXI BRAM Controller → Command BRAM Port A
                                      Command BRAM Port B → cmd_enb/cmd_addrb/cmd_doutb
```

따라서 data bank `0`은 정상 operand bank이다. Ownership 포트 범위는 모두
`[0:BANK_NUM-1]`이다.

## Bank ownership

Read/write ownership을 구분하지 않는다.

```systemverilog
output logic [0:BANK_NUM-1] bank_acquire_valid;
output logic [0:BANK_NUM-1][PORT_ROLE_WIDTH-1:0] bank_acquire_port;
output logic [0:BANK_NUM-1] bank_release_valid;
output logic [0:BANK_NUM-1][PORT_ROLE_WIDTH-1:0] bank_release_port;
input  logic [0:BANK_NUM-1] bank_busy;
input  logic [0:BANK_NUM-1][PORT_ROLE_WIDTH-1:0] bank_owner_port;
```

`*_valid`가 요청 존재 여부를 나타내고 `*_port`가 owner role을 나타낸다. Owner 0을
valid encoding으로 사용하지 않으며 opcode를 owner로 저장하지 않는다. 고정 mapping은
MM2S operand0=`MM2S_ARBITER(1)`, S2MM operand0=`S2MM_ARBITER(2)`이다. 하나의 command가
여러 bank를 사용하면 같은 acceptance cycle에 모두 acquire한다. Completion은 현재 PC와
무관하게 정확한 owner role로 소유 bank를 release한다. Dispatcher는 요청 vector만 생성하며
atomic 검증과 소유 상태 갱신은 별도 `bank_ownership_table`이 담당한다.

## Agent extension

MM2S/S2MM은 고정 infrastructure port다. GEMM이나 다른 compute executor는 template을
설계 revision으로 복사한 뒤 `USER_*_BEGIN/END` 마커 사이에서만 추가한다. 공용 template을
설계별 요구에 맞춰 직접 수정하지 않는다. 생성된 모듈은 별도의 contract, simulation,
lint와 synthesis evidence가 필요하며 template PASS를 상속하지 않는다.

제공된 marker-only GEMM probe는 src0/src1/dst를 서로 다른 세 bank로 제한하고 각각
`GEMM_ACT(3)`, `GEMM_WGT(4)`, `GEMM_PSUM(5)` role로 한 cycle에 acquire/release한다.

Template은 AXI BRAM Controller를 직접 instantiate하지 않으며 AXI 주소도 소유하지 않는다.
그 작업은 board-wrapper 단계에서 수행한다.
