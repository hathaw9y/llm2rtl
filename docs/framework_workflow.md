# 모델별 ISA·executor 설계 흐름 (초안)

목표는 지정한 모델의 지원 실행 경로를 PS가 만든 ISA 명령열과 PL executor만으로
실행하는 것이다. PS는 명령 순서, 타일링, 주소, 재시도와 같은 제어를 담당한다.
모델의 tensor 수학을 PS 코드나 미선언 외부 연산에 숨기지 않는다.

## 1. 공통 infrastructure

프레임워크는 command dispatcher와 DataMover Engine을 제공한다. Dispatcher는
명령을 해석해 executor에 전달하고 완료·오류를 수집한다. DataMover Engine은
DDR과 local bank 사이의 명시적 전송을 수행한다. 실제 보드 구성에 필요한
command BRAM, local bank, ownership, router와 vendor DMA 연결도 공통 실행
기반으로 검증한다. 어느 부분도 모델 연산 순서를 대신 결정하지 않는다.
`cmd_dispatcher_template`은 명령 fetch, DMA 명령, PC 진행과 완료 추적의
공통 골격을 제공한다. `bank_ownership_table`은 bank 점유 상태를 관리하는
재사용 코어이며, `execution_fabric_template`은 모델별 연결을 채울 골격이다.

### Native bank 생성 template

`ip/infrastructure/bank_subsystem_template/`은 MM2S/S2MM native memory 포트만
고정한다. Agent는 package와 top template을 `designs/<revision>/rtl/`로 복사하고,
해당 설계의 bank layout과 연산기 module-port role을 설정한 뒤 `USER_*` 영역에
연산기별 포트와 라우팅을 생성한다. 공용 파일에 GEMM, RN, residual 등 특정
연산기 포트를 추가하지 않는다. Ownership, router, memory의 재사용 코어는
`ip/infrastructure/bank_subsystem/rtl/bank_native_*.sv`에 둔다.

이 native template은 읽기·쓰기 소유권을 분리하는 별도 계약이다. 현재 공통
`local_bank_contract.json`과 기존 모델 dispatcher는 bank 전체의 단일 exclusive
owner를 사용한다. `cmd_dispatcher_template` v4는 native bank에 맞춰 방향별
acquire/release와 수락 확인을 제공한다. 채택하는 revision은
방향별 acquire/release, 충돌 정책과 read drain을 설계 계약과 dispatcher/fabric에
명시해야 한다. 기존 모델과 고정 bank subsystem의 증거는 새 template으로
상속하지 않는다.

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

## 4. 모듈 구현 방식 논의

ISA 단계에서 executor 목록을 정했더라도 각 executor의 구현 방식까지 확정한 것은
아니다. Agent는 **새 executor를 구현할 때마다**, RTL을 작성하기 전에 사용자에게
그 명령이 수행할 연산 범위와 입력·출력, 재사용 또는 fusion 선택을 제안한다.
연산 알고리즘, 양자화·중간 정밀도·반올림, bank 데이터 접근·결과 유효성,
tile 크기·병렬도, 명령 수락·완료 응답의 포트와 동시 실행 한도, 목표 클럭·자원,
ISA simulator의 명령별 golden 값과 RTL 검증 기준도 함께 논의한다.
Agent는 선택지의 비용과 정확도 영향을 설명하고 미결정 사항을 기록한다.
논의 결과가 현재 모듈 계약에 반영되기 전에는 해당 executor의 RTL 구현을
시작하지 않는다. 합의한 계약으로 구현·독립 검증·누적 통합·보드 검증을 진행한
뒤, 다음 executor도 같은 방식으로 논의한다.

## 5. 모델별 템플릿 채우기와 연결

Agent는 합의한 ISA·bank layout·모듈 계약에 맞춰 dispatcher와 execution fabric
템플릿을 설계 revision으로 가져와 채운다. Dispatcher의 공통 fetch, 순차 PC,
handshake 시 bank acquire, 완료 시 release와 END drain 규칙은 유지한다. 모델별
opcode decode, operand 유효성·bank 사용 조건, executor 명령/완료 연결과 outstanding
추적을 채운다. Bank ownership 코어는 합의한 bank 수와 owner 역할에 맞게 연결한다. Native v3
controller를 사용할 때는 `bank_native_ownership`의 방향별 계약을 채택하고,
engine valid 이전 acquisition 수락 확인과 read drain 후 release를 연결한다.
Fabric에는 bank 데이터 경로, DataMover, executor 인스턴스와 라우팅을 연결한다.

새 compute executor의 dispatcher-facing 제어 계약은 `cmd_valid`, `cmd_ready`,
명령 정보, 완료 응답으로 통일한다. 완료 응답에는 outstanding 명령과 bank를
식별할 정보 및 성공/오류 상태를 포함한다. 실제 bank 데이터 포트는 fabric에서
별도 인터페이스나 wrapper로 연결한다. Agent는 이 계약에 맞는 compute 모듈을
구현하고 템플릿의 모델별 영역을 채우며, 공통 PC·ownership 동작을 새로
설계하지 않는다. 채운 RTL에는 해당 revision의 검증 증거가 필요하다.

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

Engine 완료 응답은 필요한 memory `resp_valid`를 모두 수신·처리하고 최종 쓰기가
수락된 뒤에 발행한다. Controller는 일치하는 완료 응답으로 bank를 release하고
accepted를 확인한다. 생성 engine 계약과 연결 테스트는
`contracts/common/engine_completion_contract.json`의 원칙을 검증한다.
