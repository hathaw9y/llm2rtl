# Executor 첫 생성의 공통 구조 지침

모든 executor의 첫 생성과 새 연결에 적용한다. 동작 계약과 함께 아래 결정을 현재
구조 계약에 기록한다. 수치·bank 배치·연산 구조는 해당 모듈에서 정한다.
Bank 읽기와 routing의 상세 요구는 `../AGENTS.md`, `framework_workflow.md` 1.4·1.5절,
`structure_contract.md`를 함께 적용한다.

1. **실제 연산 구조를 유지한다.** 병렬도, 연산기 수, pipeline, context 수와
   initiation interval을 정한다. 병렬도나 shape를 줄인 소형 테스트를 원래 executor의
   첫 구현 성공으로 대체하지 않는다. 연산별 추가 의무는 별도 문서에서 구체화한다.
2. **주소 생성과 요청 context를 정한다.** 반복 index를 bounded counter와 등록된
   base/stride로 추적한다. 응답 주소에서 동적 나눗셈으로 index를 역산하지 않는다.
   꼭 필요한 동적 연산은 별도 latency/II로 계약화한다. 실제 요청 수락 시 bank/source,
   transaction, generation, operand index, mode, last·mask와 필요한 scale 식별자를 저장한다.
   Executor 내부에서 수락한 payload를 해석하고 이후 live payload로 응답을 해석하지 않는다.
3. **Data와 enable 조건을 함께 파이프라인한다.** 요청 선택·decode·routing과
   identity·권한·generation·주소·준비 범위·credit 검사를 stage별로 나누고 결과를
   data·주소·valid·metadata와 함께 저장한다. 각 read/write enable 및 내부 register CE의
   시작 register/port → 조건 계산 → 경계 register → 실제 sampling edge를 기록한다.
   Register 뒤에 여러 검사를 다시 결합해 긴 en/CE 경로를 만들지 않는다. Enable만
   지연하지 않으며 최종 접근의 필요한 국소 안전 검사·취소 차단을 유지한다.
   검사 결과의 유효 기간, CFG/lease 변경 시 무효화와 직접 조합 연결의 경로 예산·근거를 적는다.
4. **응답과 operand 저장 경계를 정한다.** 실제 bank/mux 응답 지연을 확인하고
   data·valid·context를 맞춘 뒤 operand register에서 core로 전달한다.
   응답 포착 → bounded slice/검사 → 저장 → operand register → core 경계를 정한다.
   서로 다른 transaction/index의 operand를 결합하지 않는다. 큰 mux·검사·주소 계산이
   전역 error/ready까지 한 번에 이어지지 않게 한다. Core 입력 register가 operand 경계를
   충족하면 cycle 대응을 기록하고 불필요한 중복 stage는 만들지 않는다.
5. **저장 포트와 backpressure를 계약화한다.** 실제 buffer의 폭·깊이·포트,
   producer/consumer 처리율과 출력 packing을 정한다. Stall 중 packet을 보존하고 이미
   발행한 응답을 받을 공간을 발행 시 예약한다. FIFO → core → scheduling → read issue의
   credit 경계를 명시한다. 고정 지연 `pipeline.sv`를 ready/stall buffer로 간주하지 않는다.
6. **오류와 완료를 분할한다.** Local 검사 결과를 등록하고 bounded reduction으로
   command error를 모은다. 즉시 필요한 commit 차단은 해당 write 경계에서 보장한다.
   마지막 read 발행, 응답 처리, core 수락·결과, 마지막 write 수락, 완료 응답 퇴역과
   bank 해제를 구분한다. Error/cancel/reset 시 pending context·응답·쓰기의 drain 또는
   무효화 정책과 이전 transaction이 새 명령에 섞이지 않는 조건을 정한다.
7. **첫 소스와 실제 경로를 검증한다.** 첫 RTL의 source closure와 hash를 보존하고
   인터페이스·구조 대조, 기능 검증, 목표 클럭 합성을 수행한다. Lint 등 검사 적용 범위는
   현재 사용자 지시와 모듈 계약을 따른다. 각 의무를 실제 파일·인스턴스·register·always
   블록·cycle에 대응시키고 각 경계 뒤부터 최종 en/CE까지 남은 조건을 검토한다.
   첫 합성에 실제 제어·memory enable·metadata commit 경로를 포함한다. 수정 후 PASS를
   첫 생성 PASS로 보고하지 않으며 Testbench 수정과 DUT 수정, 최초 실패를 구분해 보존한다.

목표 클럭, stage별 예상 지연, bank 응답 지연, operand/core latency, 처리 간격,
capacity와 stall/drain 조건을 cycle 표로 명시한다. 연속 요청, bubble, 요청 후 bank/mode
변경, 서로 다른 operand 지연, core/output stall, 반환 공간 압력, tail·mask, reset/cancel과
마지막 요청 후 drain을 실제 연결로 검증한다. 구조 검토·합성·배선 결과는 각각 구분한다.
