# Native bank subsystem generation template

공통 template에는 **MM2S/S2MM만** 고정한다. 연산기별 포트, owner role,
bank ID mapping과 연결은 Agent가 설계 revision에서 생성한다.

```text
ip/infrastructure/bank_subsystem_template/rtl/
    bank_config_pkg.sv.tpl     설정 package 생성 원본
    bank_subsystem.sv.tpl      DMA 포트와 Agent 확장 영역
ip/infrastructure/bank_subsystem/rtl/
    bank_native_ownership.sv   방향별 owner와 atomic acquire/release
    bank_native_router.sv      owner 검사, 주소 pipeline, 응답 valid/tag
    bank_native_memories.sv    설정에 따른 BRAM/URAM 생성

designs/<revision>/rtl/
    <design>_bank_config_pkg.sv Agent가 결정한 bank layout/역할
    <design>_bank_subsystem.sv  Agent가 생성한 연산기 포트와 연결
```

`infrastructure`는 재사용 코어와 생성 template의 위치다. 모델별 설정이나
GEMM/RN/residual 등의 포트를 공용 template에 넣지 않는다. 기존
`../bank_subsystem/rtl/bank_subsystem.sv`는 고정 SA 구성의 이전 예제이며,
새 경로가 기존 모델이나 execution fabric을 자동으로 교체하지 않는다.

## 생성과 연결

Agent는 두 template을 해당 revision으로 가져와 package/module 이름을 정하고,
생성 package에서 bank 설정과 capability mask를 정하고, 생성 top의
`USER_*_BEGIN/END` 영역에서 연산기 포트와 요청/응답 연결을 생성한다.
요청 선택은 `USER_ROUTING`, ready/응답 연결은 `USER_OUTPUTS` 영역을 사용한다.
DMA는 MM2S write owner 1, S2MM read owner 2를 사용한다. 추가 역할은 해당 설계의
package에 선언한다. 주소 단위는 byte가 아니라 각 물리 bank의 write/read word다.
DataMover stream 연결에는 기존 stream-bank adapter와 해당 word 폭/latency에 맞는
설계별 연결이 필요하다. 이 template 자체는 AXI DMA를 instantiate하지 않는다.

Ownership, router, memory는 개별 모듈이다. Router에는 연산기 이름 대신 bank별
요청과 owner tag를 전달한다. 생성된 wrapper가 연산기별 native memory 포트를
요청으로 변환하고, 수락 당시의 응답 owner tag로 결과를 반환한다. 한 bank에는
방향별로 하나의 선택된 요청만 전달하므로, Agent가 생성하는 wrapper는 여러
source의 동시 요청을 arbitrate하거나 충돌을 검출해야 한다. 선택되지 않은 source의
잘못된 요청까지 내부 router가 검사한다고 가정하면 안 된다. DMA ready도 최종
선택된 owner를 기준으로 돌려준다.

Default 구성은 DMA-only 검증용 두 bank(BRAM 128-bit/64 words,
URAM 128-bit/4096 words)다. 모델 bank layout이나 보드 자원 크기를 대신 결정하는
기본값으로 사용하지 않는다. 지원 memory는 BRAM과 equal-width URAM이며,
비정수 폭 비율이나 혼합/특수 memory는 별도 구현과 검증이 필요하다.

## 동작 계약

- Read/write owner를 별도로 관리한다. Acquire/release에는 valid와 owner ID를
  각각 전달하며, owner 0을 요청 valid 대신 사용하지 않는다.
- 잘못된 capability, acquire 충돌, owner 불일치 및 acquire/release overlap을
  검출한다. Multi-bank acquire와 release는 각각 두 방향을 묶어 atomic하게 검사한다.
- Engine은 모든 memory 응답 valid를 수신·처리한 뒤 해제용 완료 valid를 발행한다.
  Controller는 완료 응답에 따라 matching-role release를 요청하고 accepted를 확인한다.
  Bank에는 읽기 pending 포트나 읽기 진행에 따른 release 거절 조건이 없다.
- 주소/enable 등록 1단 + memory read latency 3 = 총 4 cycle이다. 응답에는 valid와
  수락 당시 owner가 붙는다. 응답 backpressure는 없으며 II는 1이다.
- 같은 native 요청 cycle의 write/read는 read 주소 등록 때문에 서로 다른 memory
  cycle에 수행된다. 기존 동시 read_first 결과와 같다고 가정하지 않는다.
- Prefix는 accepted write acquire에서 0으로 초기화한다. 주소 0부터 연속된
  full-strobe write만 prefix를 늘리고, read word 단위의 exclusive end를 보고한다.
  Partial/gap write는 prefix를 늘리지 않는다. Prefix 자체로 읽기를 차단하지 않으며,
  scheduler가 데이터 유효성과 충돌을 관리한다.
- Reset은 synchronous active-low이며 owner와 response valid/error/prefix를 초기화한다.
  Memory 내용은 reset 또는 owner 전환으로 초기화하지 않는다.

Scoped 계약은 [native_v3.json](../bank_subsystem/contracts/native_v3.json)이다.
기존 공통 `contracts/common/local_bank_contract.json`은 bank 전체의 단일 exclusive
owner를 사용하며, native controller v4는 이 scoped 방향별 계약을 채택한다. 따라서 새 template을 채택하는
설계는 dispatcher/fabric을 방향별 계약에 맞게 생성해야 한다. 기존 계약에
직접 연결하거나 기존 PASS를 새 소스의 검증 결과로 상속하지 않는다.

생성된 module에는 별도 module contract, source manifest, self-checking simulation,
lint와 Vivado synthesis 증거가 필요하다. Template smoke test와 생성 예제는 모델
실행, routed timing 또는 실제 보드 동작을 증명하지 않는다.

Controller command 수락·완료와 연결하는 규칙은
[controller_binding.md](controller_binding.md)를 따른다. 제공된 controller 예시의
opcode별 연산기 포트는 공통 template으로 옮기지 않고 설계별 Agent가 생성한다.

## 검증 실행

```bash
python3 ip/infrastructure/bank_subsystem_template/scripts/run_native.py --mode sim
python3 ip/infrastructure/bank_subsystem_template/scripts/run_native.py --mode synth
```

명령은 template을 별도 evidence 디렉터리에 materialize하고 source hash와 실제
Vivado version, 종료 코드를 기록한다. Sim은 DMA-only top과 생성된 custom-role/
asymmetric fixture를 따로 실행한다. Synth는 기본 DMA-only top만 검사한다.
`--out <새 디렉터리>`로 출력 위치를 지정할 수 있으며 기존 evidence는 덮어쓰지 않는다.

이전 pending 기반 버전의 [검증 기록](evidence/validation.md)은 당시 소스에만
적용된다. 현재 completion 기반 버전은 [새 검증 기록](../cmd_dispatcher_template/evidence/run_004/validation.md)을
따른다. Bank는 LUT123/FF416/RAMB36 2/URAM288 2이며 배치배선 검증은 포함하지 않는다.
