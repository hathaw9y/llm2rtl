# 구조 계약으로 구현 방식 결정

동작 계약은 무엇을 계산하고 언제 수락·완료해야 하는지 정한다.
구조 계약은 그 요구를 어떤 모듈·메모리·포트·파이프라인·제어 연결로 구현할지 정한다.
구현 Agent는 원문과 동작 계약, 구조 계약을 함께 읽고 RTL의 구성과 연결 방식을 결정한다.
구조 계약은 `designs/<revision>/structure_contract.json`에 기록하고 현재 모듈 계약에서
그 경로·버전·SHA-256과 적용할 구조 의무 ID를 참조한다.

## 작성 위치와 책임

모델 실행 범위, ISA·bank 후보, 모듈 분할·공유를 논의할 때 구조 후보를 작성한다.
실제 구현할 모듈의 알고리즘·수치·병렬도·포트가 정해지면 해당 구조 의무를 구체화한다.
Parent가 합의한 결정과 허용한 선택 범위를 기록하고 구현·검증 Child에게 같은 계약을 전달한다.
이미 승인한 결정은 다시 승인받지 않는다. 새 승인 단계나 범용 계층을 추가하는 절차는 아니다.

`inspect_and_propose`에서는 후보와 근거·미결정 항목을 제시한다.
`continue_agreed_work`에서는 이미 정한 결정으로 현재 모듈의 구조와 구현 대응표를 작성한다.
미결정 사항에는 영향받는 모듈·경계를 표시하고 해당 구현만 대기시킨다.
전체 구조에 영향을 주는 미결정 사항은 그 영향을 받는 모든 모듈에 적용한다.
아직 구현하지 않은 모듈이나 후보를 구현·검증 완료로 표시하지 않는다.

## 계약에 기록할 내용

| 항목 | 구현을 결정하는 내용 |
| --- | --- |
| 범위·identity | 설계 revision, 모델·하드웨어·지원 경로, ISA·bank·수치 계약의 경로·버전·해시 |
| 모듈 경계 | 모듈 ID·책임·opcode/연산 대응, 공유·fusion, 인스턴스 수, 구현 순서와 의존성 |
| 재사용 | 활성 infrastructure의 실제 소스 경로·해시, 그대로 재사용/parameter 변경/수정/새 구현과 근거 |
| 연결 | producer→consumer의 인스턴스·포트, 폭·packing·주소 단위, clock/reset, 수락·응답 방식 |
| 메모리 | bank 종류·용량·포트·읽기 지연, 논리 bank→물리 memory 대응, read/write owner와 commit generation |
| Weight 공급 | 논리 포트 수 N과 실제 독립 경로 수, 폭 W, DDR stripe layout, 포트별 쓰기와 결합 읽기 순서, tail·완료 집계 |
| Executor | command context 저장, read issue→응답 정렬→operand register→core→쓰기, metadata, buffer/credit, 사건별 counter와 drain |
| Controller | fetch와 PC 진행, 원자적 bank 예약 확인→command 수락, outstanding identity·한도, 완료 transport, 오류·해제·END·chunk 상태 |
| 자원·선택 범위 | 목표 클럭·처리 간격·대역폭·자원 예산, 고정한 구조와 조정 가능한 tile/병렬도/buffer/pipeline 범위 |
| 검증 | 구조 의무 ID→요구사항·출처→구현 대응→검사·기대 결과, 미결정·미검증 항목과 영향 범위 |

연산 수식·수치 규칙과 ISA 필드를 다시 복사하지 않고 해당 계약을 참조한다.
문서끼리 충돌하면 구현 전에 근거와 영향 범위를 해결한다.
명세에서 요구한 조건, 사용자 결정, 성능·자원 때문에 선택한 설계 결정을 구분한다.
기존 코드에 있는 구조를 명세의 필수 조건으로 꾸미지 않는다.

각 구조 의무에는 안정적인 `obligation_id`, 연결된 `requirement_ids`,
`source_refs`의 파일·관련 위치, 결정과 이유, 적용 모듈·연결을 기록한다.
`source_refs`는 실제 명세·사용자 결정·설계 지침을 가리킨다.
고정한 값과 조정 가능한 범위, 구현 대응 위치, 검사 방법·기대 결과도 함께 기록한다.
파일 자체의 해시를 파일 내부에 넣어 순환 참조를 만들지 않고 모듈 작업 packet에서 참조한다.

## 현재 방식의 구조 계약 예시

아래는 작성 방법 예시이며 새 모델의 확정 계약이나 구현 완료 결과가 아니다.
N·W·읽기 지연·buffer 용량은 실제 하드웨어와 모듈 계약으로 숫자를 정한다.

    제어: PS → command BRAM → controller → DMA/연산 engine
                            controller → 방향별 bank 예약
                            연산/전송 처리 → memory drain → engine 완료 응답 → 역할 해제 → END

    Weight: DDR 전송 경로 p → MM2S 경로 p → stripe bank 쓰기 포트 p
            필요한 stripe 공통 읽기 → 응답 정렬 → operand register → 계산 core
    결과:   계산 core → 결과 register/필요한 buffer → 출력 bank 쓰기
            출력 bank → S2MM의 읽기·buffer 경로 → DDR

| 구조 의무 예시 | 계약에서 정할 구현 | 구현·검증 대응 |
| --- | --- | --- |
| SC-WEIGHT-01 | 여러 쓰기 포트를 stripe p에 연결; N·W·packing과 필요한 stripe의 준비 범위 확정 | 포트→stripe 인스턴스·slice 대응표; 독립 stall·tail·결합 순서 검사 |
| SC-BANK-01 | bank별 read/write owner 분리; 모든 operand 역할의 예약 확인 후 command 제시 | 모델별 bank subsystem의 owner/mux/memory 연결; 충돌·commit 밖 읽기·잘못된 해제 검사 |
| SC-READ-01 | bank 요청→응답 정렬→operand register→core; 실제 지연에 data와 metadata 정렬 | 지연 register와 수용 buffer/credit 위치; 연속 요청·bubble·core stall·reset 검사 |
| SC-CTRL-01 | 예약부터 명령 identity 유지, engine 수락에서 실행 context 저장; 잔여 읽기·최종 쓰기 처리 후 식별 가능한 완료 응답과 역할 해제 | controller/engine의 context·pending·응답 연결; 마지막 요청 직후 조기 완료와 END 검사 |

각 행은 해당 요구사항 ID와 실제 출처에 연결한다. 이 예시의 SC ID는 설계별 계약에서
구체화할 의무 이름이며 기존 모델에 이미 부여된 요구사항 ID가 아니다.

활성 `mm2s_engine.sv`의 interface·FIFO·완료 처리를 참고해 필요한 전송 경로를 구성한다.
한 engine만으로 여러 독립 전송 포트가 구현됐다고 판단하지 않는다.
모델별 stripe bank와 bank subsystem의 작성·연결 범위를 명시하고,
필요한 MM2S 경로 수를 실제 DataMover·메모리 연결 및 대역폭과 대조한다.

`pipeline.sv`는 stall 없는 고정 지연 모듈이다. 이미 발행한 응답을 모두 수용할
buffer/credit이나 동등한 수용 보장을 계약에 정한다.
Bank에 명시적 response-valid가 없으면 검증한 고정 지연으로 내부 valid를 생성한다.
Read issue·응답 포착·core 수락·최종 쓰기의 사건과 counter를 구분하고,
완료 조건에 남은 응답·operand·core 파이프라인과 쓰기 처리까지 포함한다.

새 설계의 bank subsystem에는 방향별 owner·실제 engine 포트·mux·commit·memory를 연결한다.
`bank_ownership_table.sv`는 단일 exclusive primitive이므로 그대로 방향별 구현으로 선택하지 않는다.
일반화된 별도 ownership/router·adapter·command queue를 선행 과제로 만들지 않는다.

## 계약에서 RTL로 연결하는 절차

1. 현재 모듈의 요구사항·동작 계약과 적용할 구조 의무를 읽는다. 출처와 실제 재사용 소스를 대조한다.
2. 의무별로 구현할 파일·모듈·인스턴스·포트·parameter·제어 상태와 검사 방법을 대응시킨다.
   구조 의무와 연결이 없는 선언만으로 구현 완료를 표시하지 않는다.
3. 고정한 경계는 유지하고 허용한 범위의 구체적인 설정을 모듈 계약에 기록한 뒤 구현한다.
   내부 FSM encoding 같은 자유 선택을 위해 매번 사용자 승인을 요구하지 않는다.
4. 기존 독립 검증 Child는 대응표와 실제 RTL 전체를 대조하고 연결·cycle·stall·reset·오류를 검증한다.
   소스 파일 이름이나 module 선언의 존재만으로 실제 경로가 구현됐다고 판단하지 않는다.
5. 변경이 필요하면 이유·원본 근거·영향받는 요구사항/구조 의무·모듈·검사를 기록한다.
   고정한 경계를 바꾸는 경우 계약의 새 버전·해시와 관련 packet을 갱신하고 영향 범위를 재검증한다.

검증에는 계약의 정합성, 실제 인스턴스·포트·parameter·source closure,
동작 시뮬레이션과 필요한 합성·자원·timing 증거를 구분해 기록한다.
구조 계약 자체는 동작 정확성이나 목표 성능의 증명이 아니다.
현재 공통 검사기는 소스 identity와 이전 호환 계약을 검사한다.
새 구조 계약의 schema·적합성 검사는 설계별로 준비하고 실제 실행한 범위만 보고한다.
이 지침을 추가한 것만으로 자동 구조 검사기가 구현됐다고 표현하지 않는다.
