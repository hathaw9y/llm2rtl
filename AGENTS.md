# llm2rtl 작업 지침

이 파일은 저장소 전체의 기본 작업 규칙이다. 현재 사용자 지시와 이미 합의한
결정을 우선한다. 과거 설계의 ISA·수치·클럭·bank 배치·PASS를 새 설계에 상속하지 않는다.
사용자가 중단한 작업은 명시적으로 재개하기 전까지 계속하지 않는다.

## 작업 시작과 기준 문서

- 먼저 Git 상태와 현재 설계 revision을 확인하고 사용자 변경을 보존한다.
- 새 설계·구조 변경은 `README.md`, `docs/framework_workflow.md`,
  `docs/structure_contract.md`, `ip/infrastructure/README.md`를 읽는다.
- `contracts/README.md`와 `contracts/common/README.md`를 함께 읽는다.
  이전 single-exclusive JSON 계약·검사기의 적용 범위와 새 방향별 계약을 구분한다.
- 현재 모듈의 동작·ISA·bank·수치·구조 계약과 실제 재사용 소스를 읽는다.
  파일명이나 검사 PASS만 보고 내용을 추측하지 않는다.
- 관련 Skills는 기술적 절차로 사용하되 현행 저장소와 사용자 지시를 우선한다.
  과거 contract index·mapping 승인·bringup 계층을 다시 도입하지 않는다.

## Infrastructure 선택과 구조 계약

- 활성 공통 RTL의 기준은 `ip/infrastructure/sources.json`이다.
  `python3 scripts/infrastructure_sources.py --check`로 경로·해시·의존성을 확인한다.
  이 검사는 기능·타이밍의 증명이 아니다.
- 실제 포트·packing·주소 단위·읽기 지연·reset·완료 동작을 확인하고,
  재사용 / parameter 변경 / 수정 / 새 구현 여부와 근거를 기록한다.
  모델별 변경은 `designs/<revision>/`에 분리한다.
- archive와 호환 profile은 과거 설계를 재현할 때 명시적으로 선택한다.
  레퍼런스 config의 모델 값이나 기존 controller의 ISA를 새 요구로 복사하지 않는다.
- 구현 전에 `structure_contract.json`의 현재 모듈 의무를 구체화한다.
  의무별 ID, 요구사항·출처, 결정 이유, 실제 모듈·연결, 고정 값·허용 범위,
  구현 대응과 검증 방법을 기록한다. Module packet은 구조 계약의 버전·해시·의무 ID를 참조한다.
- 필요한 모델별 구조부터 구현한다. 별도 범용 ownership/router/adapter/queue를
  선행 과제로 만드는 것은 실제 요구와 재사용 근거가 있을 때만 선택한다.

## 첫 RTL부터 타이밍을 고려한 구조 설계

이 절은 합성 실패 후의 수정 지침이 아니라 **첫 생성과 새 연결의 입력 조건**이다.
기능 우선 구현도 아래 구조 결정을 합성 이후로 미루지 않는다. 최종 자원 최적화와
보드 fitting 시점은 해당 설계 계약을 따른다.

RTL 작성·구현 Agent 배정 전에 현재 구조 계약에 다음을 기록하고 Parent가 검토한다.
별도 타이밍 계획을 사용한다면 구조 계약에서 참조하여 같은 결정을 중복 관리하지 않는다.

1. **클럭과 경로 예산:** 목표 클럭·주기·device·tool·clock/reset 경계를 명시한다.
   Stage별 예상 조합 지연과 register·배선 여유를 기록한다. 예측과 측정은 구분하고
   고정 logic-level 개수만으로 통과를 단정하지 않는다.
2. **Packet과 register 경계:** 요청 선택·decode·예약·수락·계산·쓰기·완료 사이에서
   무엇을 저장할지 정한다. Data, valid, source, bank, role, generation, transaction과
   실제 사용하는 metadata를 정렬한다. 직접 조합 연결에는 경로 예산과 protocol 근거가 필요하다.
3. **모듈을 가로지르는 경로:** decode → arbitration → ownership → routing → commit,
   CFG, completion/release, fault/abort의 시작점·조합 논리·끝점을 기록한다.
   Child → parent → child feedback, 반복 bank scan, 큰 mux와 높은 fanout도 검토한다.
4. **연산 분할:** 넓은 합산·scale·반올림, variable division/modulo, 주소 계산을
   한 사이클에 몰지 않는다. 실제 지연과 처리량에 맞는 reduction·pipeline·row/tile base를
   선택한다. Register를 추가해도 다음 stage에 긴 경로가 남는지 확인한다.
5. **Routing 범위:** producer별 합법 bank/role과 mux 폭·입력 수·선택 stage를 정한다.
   도달 가능성 근거가 있을 때 sparse routing을 사용한다. 동적 bank를 임의로 고정하거나
   ownership/generation/format 검사를 제거하지 않는다.
6. **Cycle 의미:** 추가 latency, initiation interval, capacity, priority, backpressure,
   CFG 충돌, pending 요청 안정성, reset·취소·error drain을 명시한다.
   예약·metadata 수락·leaf 수락·물리 쓰기·응답 퇴역은 실제로 다른 사건이면 구분한다.
7. **첫 합성 범위:** 첫 유효한 소규모 연결에서 실제 제어·memory commit 경로를 포함해
   목표 클럭으로 합성할 source closure와 실행 시점을 정한다. 전체 모델 완성까지 기다리지 않는다.

**전역 fault/control은 명시적으로 분할한다.** 여러 모듈의 오류를 모아 모든 engine의
enable·ready·write를 직접 제어하는 긴 조합 경로를 기본 구조로 만들지 않는다.
즉시 필요한 안전 차단과 다음 cycle에 처리 가능한 오류 보고·정리를 구분하고,
실제 연결 범위와 지연을 기록한다. Register를 추가한다는 이유로 필요한 쓰기 차단을
늦추거나 오래된 legality로 commit하게 해서는 안 된다.

Parent는 검토한 구조 의무와 module 계약을 구현 Child에게 함께 전달한다.
Child는 첫 RTL 전에 읽고 의무 → 파일·인스턴스·포트·parameter·stage 대응을 작성한다.
구조를 결정하는 미결정 사항은 영향받는 구현을 막지만 독립 작업은 계속한다.
합의된 범위의 내부 선택은 Agent가 정한다. 이를 위한 새 사용자 승인 단계를 만들지 않는다.

### BANK routing과 memory enable 경로의 필수 확인

이 요구는 `cmd_dispatcher`뿐 아니라 executor 연결, preload/DMA, readback,
ownership/controller와 실제 payload memory에 적용한다. 요청 register나 queue가
있다는 사실만으로 routing·enable 경로가 파이프라인됐다고 판단하지 않는다.

1. **첫 RTL 전 경로 대응:** 구조 계약에 경로별 의무 ID를 부여하고,
   시작 register/port → stage별 BANK 선택·검사 → 경계 register → 최종 memory
   enable을 기록한다. Read/write payload와 commit/coverage metadata memory를
   모두 포함한다. 각 stage의 조합 논리·fanout·예상 지연, 저장할 context와
   sampling edge를 명시한다. 구현 Child는 이를 읽고 대응을 작성한 뒤 RTL을 생성한다.
2. **Routing 분할:** command decode와 role/BANK 선택을 저장한 뒤 필요한
   arbitration·ownership·routing을 stage별로 분할한다. 이후 memory 접근은
   수락해 보존한 context를 사용한다. Live opcode/BANK 선택이 여러 모듈을 거쳐
   최종 enable까지 직접 전파되는 구조를 기본으로 만들지 않는다.
3. **Enable 조건 분할:** 동적 BANK 선택, owner·generation·주소·format 검사,
   commit/coverage·tail·credit 판단을 한 조합 경로로 모아 memory enable을
   만들지 않는다. 필요한 선택과 검사를 앞 stage에서 수행하고 결과를 data·주소·
   strobe·valid·source·role·generation·transaction과 함께 저장한다.
   최종 stage는 선택된 BANK의 국소 조건으로 실제 read issue/write commit을 결정한다.
   경계 뒤에 큰 BANK mux와 여러 검사가 다시 몰리면 추가 분할 대상으로 기록한다.
4. **현재 상태와 안전성:** 앞 stage의 검사 결과를 사용하는 동안 lease·generation·
   CFG·준비 범위가 어떻게 안정적으로 유지되는지 명시한다. 상태가 바뀔 수 있다면
   최종 stage에서 필요한 국소 재검사 또는 무효화로 오래된 허용 결과의 사용을 막는다.
   Enable만 지연하거나 실제 memory 수락 전에 commit/coverage를 갱신하지 않는다.
   Stall 중 packet 보존, 예약 credit, reset/cancel, 마지막 물리 쓰기 후 drain까지
   추가 latency에 맞춰 정의한다. 직접 조합 연결 예외는 경로별 예산·안전성 근거와
   현재 source의 측정 결과로 검토하며, 측정 전에는 타이밍 준수로 판정하지 않는다.
5. **생성 후 코드 대조:** 구현 Child는 각 의무를 실제 파일·인스턴스·신호·register·
   always 블록·cycle에 대응시키고, 각 경계 뒤부터 최종 enable까지 남은 조합 경로를
   적는다. Parent와 독립 검증 Child는 동일한 source hash를 기준으로 이 대응을
   확인한다. 계획 문구, FSM stage 이름, `pipeline.sv` 또는 register의 존재만으로
   구조 준수를 승인하지 않는다. 검토 기록에 확인한 경로와 근거를 남긴다.
6. **판정과 첫 합성:** 누락된 경로, 긴 선택·검사가 남은 stage, 입증되지 않은
   예외는 구조 미충족/미확인으로 기록하고 해당 연결의 구조 PASS·승격을 막는다.
   구조 검토와 실제 타이밍 판정은 구분한다. 첫 합성은 memory enable과 metadata
   commit 경로를 포함하며, 보고서의 실제 시작점·끝점·logic/route 지연을 계획과
   대조한다. 위반 시 실패 이력을 보존하고 별도 revision에서 수정·재검증한다.

## Memory와 handshake

- 새 설계는 방향별 read/write owner·acquire/release와 실제 수락을 명시한다.
  필요한 역할의 원자적 예약을 확인하고 ownership과 commit/data availability를 구분한다.
  Single-exclusive primitive를 그대로 방향별 구현이라고 표현하지 않는다.
- 여러 Weight 전송 포트는 실제 stripe 연결·packing·준비 범위·tail·완료 집계를 명시한다.
  논리 포트 수와 독립 메모리 경로 수를 구분하고 N·폭·대역폭은 현재 hardware에서 정한다.
- 명령은 한 번 수락하고 context를 유지한다. 필요한 읽기 응답·operand/core pipeline과
  최종 쓰기를 처리한 후 완료·bank 해제를 허용한다. 완료 transport와 END drain도 검증한다.
- Job-control과 stream valid/ready는 서로 다른 protocol이다. 현재 모듈 계약과
  `docs/hdl_module_interface_contract.md`의 적용 범위를 확인하고 필요한 adapter를 검증한다.

## Bank 읽기의 필수 파이프라인

모든 executor의 첫 생성과 새 연결에는 `docs/executor_initial_structure.md`를 적용한다.
주소 counter·요청/응답 context·operand 저장·출력과 en/CE 조건의 stage 경계를 먼저 계약화한다.
GEMM에는 `docs/gemm_initial_structure.md`의 배열·타일·누산 구조 의무도 추가 적용한다.

기준은 `docs/framework_workflow.md` 1.4·1.5절과 `docs/structure_contract.md`의
읽기 구조 의무다. **모든 executor는 bank 출력을 계산 core에 직접 조합 연결하지 않는다.**
Weight·activation·scale·KV 등 실제로 읽는 모든 operand에 아래 구조를 적용한다.

```text
읽기 조건 확인 → 요청 발행 → bank/mux의 실제 응답 지연
                          → data·valid·metadata 정렬
                          → operand register → 계산 core
```

1. **발행 조건:** 현재 operand 역할의 읽기 권한, 합법 bank·주소, 유효 generation,
   준비 범위와 반환 응답 저장 여유를 확인한 뒤 read enable·주소를 발행한다.
   진행 중 writer와 겹쳐 읽는 경우 실제 읽기 word 단위로 `read_addr < commit`을
   확인하고 same-address read-during-write 정책을 따른다. Owner만 보고 준비 완료로 판단하지 않는다.
   Stripe weight는 해당 결합 읽기에 필요한 모든 stripe가 준비돼 있어야 한다.
2. **요청 context:** 실제로 발행/수락된 읽기와 함께 bank/source, transaction,
   operand index, last·mask, mode와 필요한 generation/scale 식별자를 보존한다.
   이후 live bank 선택·주소·mode가 바뀌어도 이전 응답을 현재 명령으로 해석하지 않는다.
   Arbiter/ready가 있는 포트는 실제 수락 사건을 사용한다. 고정 enable 포트는
   memory가 enable·주소를 샘플하는 edge를 발행 사건으로 계약화한다.
3. **지연 정렬:** `BANK_RD_LATENCY`는 memory뿐 아니라 bank 선택 mux·중간 register를
   포함한 요청부터 응답까지의 실제 지연이다. 반환 data에 valid·metadata를 맞춘다.
   Bank에 response-valid가 없으면 검증된 고정 지연으로 **발행 사건**을 지연해 valid를
   생성한다. Enable이 없던 bubble의 유지된 dout를 새 응답으로 처리하지 않는다.
   응답 지연이 가변적이면 고정 shift만 사용하지 말고 응답 handshake와 identity를 추적한다.
4. **Operand 저장과 정렬:** 유효 응답을 operand register에 data·valid·metadata와
   함께 저장한 뒤 core에 전달한다. 이 stage는 첫 RTL부터 필수다. 실제 core 입력
   register가 그 경계를 충족하면 구조·cycle 대응으로 명시하며 불필요한 중복 stage는 만들지 않는다.
   Operand별 지연이 다르면 register/buffer로 같은 transaction·연산 index를 맞춘다.
   단순히 모든 valid가 1이라는 이유로 서로 다른 요청의 operand를 결합하지 않는다.
5. **Stall과 credit:** `ip/infrastructure/utils/pipeline.sv`는 매 클록 진행하는 고정
   지연 모듈이며 ready/stall 기능이 없다. 제어 정렬에 사용할 때 data·metadata와 같은
   지연을 보장한다. Core stall 중에도 이미 발행한 응답은 도착하므로 FIFO/elastic buffer와
   outstanding credit 또는 동등한 수용 보장을 설계한다. 새 요청 발행 때 반환 공간을
   예약하며, FIFO가 full이 된 뒤 발행을 멈추는 것만으로 안전하다고 판단하지 않는다.
   Core에 제시한 operand는 실제 수락까지 보존하고 pending 응답을 버리거나 덮어쓰지 않는다.
6. **사건별 진행과 drain:** read issue, 응답 포착, core 수락, 최종 쓰기 수락을
   서로 구분해 counter와 완료 조건을 정한다. 마지막 read issue만으로 완료하지 않는다.
   잔여 응답·operand buffer·core pipeline과 최종 쓰기 처리 후 완료·bank 해제를 허용한다.
   Reset/명시적 cancel에서는 pending valid와 context를 무효화하고 이전 응답이 새
   transaction에 섞이지 않게 한다. 공유 reset이 아닌 cancel의 잔여 응답·해제 정책도 명시한다.
7. **Cycle 표와 검증:** 요청 샘플 edge, data 도착·포착 edge, operand 제시·core 수락
   edge를 계약에 적는다. Operand register와 core 내부 지연은 bank 응답 지연 이후에
   별도로 계산한다. 실제 sampling edge를 확인해 off-by-one·중복 지연을 방지한다.
   연속 요청, bubble, 서로 다른 operand 지연, 요청 후 bank/mode 변경, core stall,
   반환 중 buffer 압력, tail·last·mask, reset/cancel과 마지막 요청 후 drain을 검증한다.

Parent는 위 단계의 저장 위치·읽기 지연·capacity·처리 간격·완료 조건을 구조 의무로
전달한다. 구현/검증 Child는 실제 인스턴스·register·valid·credit 경로와 대응시킨다.
`pipeline.sv` 인스턴스 하나가 존재한다는 이유만으로 이 요구 전체를 충족했다고 보고하지 않는다.

## 검증·타이밍 결과와 실패 기록

- 구현과 독립 검증 Child는 동일한 동작·구조 계약과 exact source를 사용한다.
  실제 연결·payload·cycle·stall·reset·오류를 대조한다. Module 선언의 존재만으로 통과시키지 않는다.
- Pipeline 변경 시 latency와 테스트 기대값을 함께 갱신하되 payload·순서·오류·reset
  assertion을 약화하지 않는다. 실제 연결에서 불가능한 force 상태는 별도 stress 범위로 기록한다.
- Vivado에서는 목표 `create_clock`/XDC를 **synth_design 이전**에 적용한다.
  실제 tool 버전·part·source hash·명령·종료 코드와 timing/utilization 보고서를 보존한다.
- 종료 코드 0만으로 timing PASS를 선언하지 않는다. Setup·hold·pulse-width와
  내부 unconstrained/no-clock/loop 검사를 확인한다. 외부 I/O constraint와 제외 경로를 명시한다.
  합성 OOC, routed timing, board 검증은 각각의 증거 범위로 보고한다.
- 타이밍 실패마다 설계 revision의 `TIMING_ISSUES.md`와 machine-readable evidence에
  source/보고서 identity, 목표 클럭, WNS/TNS, 실패 endpoint 수, 대표 경로, 원인 근거,
  수정과 재검증 결과를 기록한다. 원인 추정과 측정 사실을 구분하고 이전 실패를 지우지 않는다.
- 목표 클럭 실패가 남은 연결에 독립적으로 무관한 작업은 진행할 수 있지만,
  그 경로에 의존하는 확장·버전 승격은 하지 않는다. 전체 연결의 fresh 결과가 통과해야 승격한다.
- 계획·identity 검사, simulation, 합성, routing, 실물 보드와 full-model 수치 검증을
  구분한다. 문서 추가나 한정된 테스트 PASS를 자동 집행·전체 모델 성능의 증명으로 표현하지 않는다.

## 작업 보존과 보고

현재 소스·계약·검증 결과를 hash로 연결한다. 계약/구조 변경은 새 버전과 영향받는
검증으로 반영하고 과거 동결 source·보고서를 덮어쓰지 않는다.
최종 보고에는 변경 이유, 실제 검증 결과, 남은 범위와 사용할 source/contract/evidence를 적는다.
요청되지 않은 commit·push·배포는 하지 않는다.
