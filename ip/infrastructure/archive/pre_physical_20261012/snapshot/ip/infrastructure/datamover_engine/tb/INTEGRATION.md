# Scheduler-driven DataMover integration test

## 구성

`tb_engine_integration.sv`의 scheduler BFM이 **datamover_engine의 공개
명령 포트**를 구동한다. RTL 내부 신호 force나 command FIFO 직접 주입은 없다.
합성 가능한 실제 모델 scheduler를 생성한 것은 아니다.

```text
Scheduler BFM --command/completion/abort--> datamover_engine
                                              |       |
                          behavioral DataMover       adapters (RTL)
                                  |                      |
                              DDR byte array       bank_arbiter (RTL)
                                                         |
                                                behavioral bank memory
```

- 실제 RTL: engine, 양방향 channel, command queue, FIFO, 폭 변환기,
  MM2S/S2MM adapter, bank read/write arbiter.
- 모델: DataMover 명령 수락·바이트 전송·순차 status, DDR 배열, bank 메모리.
- 두 bank, bank당 64 words, stream 64비트. Bank 폭 32/128비트 × 읽기 지연
  1/3사이클의 네 구성을 실행한다. 메모리와 adapter/arbiter의 지연 설정은 동일하다.
- Clock은 10 ns이다. 이는 테스트 시간 기준이지 100 MHz timing closure 주장이 아니다.
- 별도 bank client가 요청을 유지해 DMA 접근을 지연한 뒤 해제한다. 경쟁 client는
  실제 payload를 생성하지 않으므로 다중 연산 IP의 데이터 통합 검증은 아니다.

## Self-checking 시나리오

1. Bank 점유 중 적재 명령 두 개를 같은 bank의 다른 offset에 제출한다.
   점유 중 실제 native write가 없는지 검사한 뒤 점유를 해제한다.
2. 13/29바이트를 적재하고 각각 DDR로 배출한다. 원본과 byte-by-byte 비교하고
   출력 DDR buffer 앞뒤 sentinel이 유지되는지 검사한다.
3. Bank 1 적재와 bank 0 배출을 동시에 명령한다. 양방향 진행이 실제로 겹치는지
   counter로 검사하고, 57바이트 tail 및 bank 0 데이터 보존을 readback으로 확인한다.
4. 정렬되지 않은 descriptor를 명령 포트로 제출한다. 오류 응답을 확인하고
   DataMover로 발행한 명령 수가 늘지 않았는지 검사한다.
5. Payload 이전에 잘못된 반환 tag를 주입한다. Expected/received tag와 fault를
   확인하고, scheduler 명령 전에는 adapter abort가 발생하지 않는지 검사한다.
6. Scheduler BFM이 오류 응답을 수신하고 abort를 명시적으로 요청한 후,
   engine·DataMover 모델·adapter·arbiter를 함께 reset한다. 이후 새 17바이트
   적재/배출을 명령하고 DDR readback을 확인한다.
7. 명령 및 payload의 결정적 stall, 완료 응답의 5-cycle backpressure를 포함한다.
   Public valid/data/keep/last와 완료 필드가 stall 동안 유지되는지 검사한다.
   DataMover 모델은 S2MM BTT/keep/last 일치도 검사한다.

## 실행

Vivado 도구 경로가 PATH에 있는 환경에서:

```bash
bash ip/infrastructure/datamover_engine/scripts/run_integration_sim.sh
```

Compile, elaborate, simulation 로그와 RTL/TB SHA-256은 출력된 임시 실행 폴더에
분리 저장된다. 모든 구성에 PASS marker가 있어야 스크립트가 성공한다.

2026-09-08 실행 결과: **Vivado/XSim 2025.2, 4/4 PASS**.
보관된 실행은 `../verification/integration/xsim_pass_20260908/`이다.
초기 실행에서 XSIM은 샌드박스 안에서 Tcl 초기화 예외로 종료했으며,
동일 snapshot을 샌드박스 밖에서 실행해 통과했다. 이후 네 구성도 밖에서 실행했다.
Elaboration에는 C compiler 관련 환경변수 경고가 있었으나 compile/elaborate/simulate가
완료됐으며 simulation 오류는 없었다.

`SIMULATOR=iverilog` 경로도 남겨두었다. 현재 환경의 Icarus 통합 실행은 bank
요청/배열 포트에서 X가 관찰되며 timeout으로 실패했다. 이 경로를 PASS로 주장하지
않으며 RTL을 변형해 통과시키지 않았다. 같은 RTL/TB의 XSIM 결과를 기준으로 한다.

## 증거 범위

이 테스트는 **scheduler 역할의 BFM → engine → 실제 adapter/arbiter RTL** 통합을
검증한다. 실제 AXI DataMover IP, AXI-MM bus, XPM, DDR controller, PS cache,
물리 보드, bitstream, 성능·timing은 검증하지 않는다. DataMover 모델의 오류 후
reset 동작이 실제 IP의 모든 복구 조건을 증명하지 않는다.
무작위 stress/formal 검증, S2MM 오류 주입, 모든 tag/descriptor 오류의 통합
경로 조합은 이번 범위 밖이다. 세부 제어 오류는 기존 `tb_command_queue`에서 검사한다.

Simulation/synthesis was run, but timing was not fully verified.
(이번 실행은 simulation만 수행했으며 synthesis는 실행하지 않았다.)
