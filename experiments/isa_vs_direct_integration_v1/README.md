# ISA 중심 제어와 직접 FSM 구현의 비교

## 실험 목적

같은 단독 연산기를 연결할 때, ISA 중심 실행 제어가 Agent의 통합 오류를 줄이는지 평가한다. 연산기 자체를 새로 설계하는 능력은 이번 실험의 평가 범위에 포함하지 않는다. 이 범위는 2026-10-06 사용자가 선택했다.

기존 `llm2rtl_design_change_comparison_v1`의 변경 실험과 별도 실험이다. 기존 실행은 새 실험의 반복 횟수나 성공 사례로 합산하지 않는다.

## 두 조건

| 조건 | 동일하게 제공하는 것 | 새로 생성해야 하는 것 |
|---|---|---|
| ISA | 단독 연산기, 수치·메모리·인터페이스 명세, software reference, 공개 시험, 도구 | ISA 형식, lowering 및 실행 프로그램, interpreter, dispatcher, 연결 RTL |
| 직접 구현 | 위와 동일 | 작업 파라미터를 받는 FSM, 반복·주소 제어, 연결 RTL, 호스트 실행 코드 |

단독 연산기의 `cmd_valid/cmd_ready` 호출 인터페이스는 양쪽 모두 사용한다. 직접 FSM이 이 인터페이스를 호출하는 것은 ISA 사용으로 분류하지 않는다. 직접 구현 조건에는 명령 메모리, PC, opcode fetch/decode에 따라 작업 전체를 실행하는 프로그래머블 명령 해석기를 허용하지 않는다. 카운터, FSM 상태, 길이·주소 파라미터와 반복은 허용한다.

ISA 조건은 실제 명령열을 통해 작업을 수행해야 한다. 모델 실행을 별도 FSM이나 PS tensor 연산으로 우회하면 실패다. 두 조건의 PS는 설정·전송·오류 처리만 수행한다. 오프라인 reference 계산과 weight packing은 허용한다.

## 시작 자료의 경계

현재 SmolLM2 revision에서 단독 compute RTL과 필요한 LUT만 추출한다. 양쪽에 동일한 SHA-256의 파일을 제공하고 수정하지 못하게 한다. 단독 연산기의 기존 opcode 필드는 내부 호출 ABI로 취급한다. 직접 조건은 상수로 연결하거나 의미가 같은 adapter를 작성할 수 있다.

완성된 dispatcher, bank fabric, 모델 top, 모델 FSM, ISA 생성기, 기존 모델 interpreter, 통합 testbench 및 이전 실행 로그는 제공하지 않는다. 중립적인 tensor 저장 형식과 메모리 응답 모형은 양쪽에 동일하게 제공한다. 연산기 독립 testbench는 controller나 모델 순서를 포함하지 않는 것을 확인한 후 양쪽에 제공한다.

기존 PASS 보고서는 시작 자료의 검증을 대신하지 않는다. 추출한 파일 집합으로 단독 시험을 다시 실행하고, 지원 범위와 오류·완료 계약을 확인한다.

## 과제

| ID | 입력과 출력 | 핵심 검사 |
|---|---|---|
| I01 | hidden → RMSNorm → Q/K/V projection → Q/K RoPE | 전체 Q/K/V 채널, head 배치, in-place RoPE, 타일 기록 offset, 완료 순서 |
| I02 | Q 및 새 K/V, 이전 KV → cache append → score → causal Softmax → context | 이전 KV 보존, append 위치, GQA head 대응, 저장 완료 전 재읽기 금지, 연속 decode |
| I03 | hidden 및 이전 KV → decoder block → hidden 및 갱신 KV | I01·I02, o_proj, residual, post RMSNorm, gate/up, SILU_MUL, down_proj, 최종 residual |

모델은 checkpoint `93efa2f097d58c2a74874c7e644dbc9b0cee75a2`의 layer 0을 사용한다. H=576, Q head=9, KV head=3, head dimension=64, FFN=1536이다. Prefill block은 1..32 토큰, 전체 context는 최대 1024 토큰이다. 연속 position, causal attention만 지원한다. 임의 padding mask와 사용자 지정 position ID는 제외한다.

긴 context의 값 검사는 1024 범위의 실제 KV를 포함한다. 단순 주소 경계 검사로 긴 context 수치 검사를 대체하지 않는다. 과제별 최소 공개 사례와 숨겨진 사례는 실행 전에 고정한다.

## 공정성

### 자원 공유와 연속 실행

모든 과제는 GEMM executor를 정확히 하나만 인스턴스화한다. I01의 Q/K/V와 I03의 Q/K/V·attention score/value·o_proj·gate/up/down은 같은 16×16 배열을 사용한다. 합성 후 전체 leaf hierarchy에서 executor와 PE 수를 확인한다. 소스의 문자열 개수만으로 공유를 판정하지 않는다. 다른 이름의 복제 연산기나 PS tensor 계산도 허용하지 않는다.

I02와 I03은 각 입력에 대해 prefill 이후 최소 4개의 teacher-forced decode를 수행한다. 다음 토큰은 두 조건에 동일하게 제공한다. 한 조건이 선택한 토큰에 따라 입력이 달라지는 것을 방지한다. 각 decode에서 모든 새 KV 값, 기존 prefix, 전체 context 또는 block 출력과 최종 유효 길이를 검사한다. 이전 실행의 bank·KV 상태를 유지하며, 독립 입력 사이에는 명시적으로 reset한다.

Shape와 tail 사례는 M=1,7,16,31,32, N 타일 경계와 마지막 타일, KV 길이의 16 배수 전후를 포함한다. 1024 context 끝부분의 prefill/decode와 범위 밖 append 거부도 검사한다. Weight 교체, data read-before-write, 완료 응답 backpressure를 포함한다. 모든 중간 출력은 전체 채널을 비교한다.

복잡도 증가는 I01→I02→I03의 세 과제로 평가한다. 단일 연산은 제공 연산기의 사전 검증 및 evaluator 보정에 사용한다. 단일 연산의 기존 성공을 새 Agent의 성공 과제로 합산하지 않는다. 별도 설계 변경·오류 주입 복구 실험은 이 비교의 본 실행에 섞지 않는다.

- 같은 Agent 모델·reasoning 설정·도구·clock·part·시간 제한을 사용한다.
- 각 과제와 조건은 새로운 작업 디렉터리와 새 대화에서 시작한다.
- 조건 간 결과, helper 답변, 기존 통합 소스는 읽을 수 없도록 격리한다.
- 초기 명세 이후 설계 힌트, 코드 수정, 계속 진행 지시는 제공하지 않는다.
- 양쪽에 같은 공개 평가 호출과 원본 실패 로그를 제공한다.
- 최종 숨겨진 시험은 Agent 종료 후 수행한다. golden과 평가기는 수정할 수 없다.
- 조건별로 제공하는 추가 문서는 실행 제어 표현에만 차이를 둔다. ISA 조건만 추가 수치 시험이나 더 강한 오류 명세를 받지 않는다.
- 예비 실험에서 평가기와 초기 자료를 보정한 뒤 본 실험 버전을 고정한다. 보정 전 결과는 본 실험에 포함하지 않는다.

## 판정

수치 판정을 두 층으로 분리한다.

1. **통합 정확성:** 고정 단독 연산기의 실제 산술 규칙으로 만든 독립 golden과 모든 지원 출력·중간 tensor·KV 값이 bit-exact해야 한다. 같은 연산기를 사용하므로 제어 오류를 수치 허용치로 가리지 않는다. 동일한 K 누산 순서와 각 연산의 BF16 cast 경계를 유지한다.
2. **모델 근사 오차:** Hugging Face BF16 reference에 대한 max absolute error, MAE, RMSE, NRMSE를 별도로 기록한다. 이 값은 고정 연산기 체인의 사전 보정 결과에 따라 기준을 고정한다. 현재 제공한 연산기의 누산은 IEEE FP32가 아니므로 HF와 bit-exact를 요구하지 않는다. 실행 결과를 보고 허용치를 올리지 않는다.

오류 입력, 메모리·완료 backpressure, 가변 read latency, reset/abort, bank alias, 범위 밖 주소, chunk 경계 또는 동일 FSM의 여러 start도 검사한다. 실패 시 부분 결과를 정상 완료로 publish하지 않는다.

합성은 ZCU104 `xczu7ev-ffvc1156-2-e`, 100 MHz에서 동일한 완전한 top과 같은 제약으로 수행한다. 모든 leaf를 link한 후 blackbox, unconstrained path, 자원과 setup timing을 검사한다. 합성과 routed implementation, 실물 보드 시험은 별도 열로 보고한다. 물리 보드 시험은 사용자 수행 범위다.

## 측정

주 지표는 동일 예산 안에서 모든 필수 검증을 완료한 비율이다. 첫 통합 시험은 실제 연산기와 memory 모형을 사용해 tensor 및 상태를 검사하는 최초 평가기 호출이다. 최초 실패도 기록하며, 재호출로 첫 시험 기록을 덮어쓰지 않는다. Agent가 작성한 성공 문장은 판정 근거가 아니다.

추가로 Agent 수정 반복, 사용자 개입 횟수·시간, token 사용량, tool 호출, 산술/순서/주소/상태/완료 오류, LUT/FF/DSP/BRAM/URAM, 작업 cycle을 기록한다. 순수 연산기 cycle과 전체 작업 cycle을 구분한다. 연산기 공유 수를 확인하여 성공률 상승이 연산기 복제나 지나친 직렬화와 함께 발생했는지 보고한다.

예비 실험은 과제당 조건별 1회, 총 6회다. 본 실험은 3개 과제 × 2조건 × 3회=18회를 계획한다. 예비 단계의 시작 예산은 실행당 90분이며 본 실험 전 적정성을 확인한다. 토큰 상한과 도구 동시 실행 정책은 본 실험 전에 명시한다. 실패·timeout·도구 오류도 모두 보존한다.

## 현재 상태

### 검증 예산별 기록

수정 횟수는 evaluator에 제출한 서로 다른 source snapshot 사이의 전환으로 정의한다. 첫 snapshot은 수정 0회, 두 번째는 수정 1회, 네 번째는 수정 3회다. 같은 snapshot을 다시 제출한 경우 새로운 수정으로 세지 않는다. Compile/elaboration 실패도 첫 제출의 실패로 보존한다. Evaluator infrastructure 실패는 후보 실패와 구분하고 동일 snapshot으로 재실행한다. Agent가 내부에서 수행한 수정·self-test 횟수는 별도 도구 로그에서 기록한다.

각 snapshot은 timestamp, source 및 input/evaluator SHA-256, cumulative token usage, participant wall time, evaluator wall time, 원본 결과를 가진다. Snapshot을 복사한 뒤 평가하므로 실행 중 source 변경이 결과에 섞이지 않는다. 최초·1회·3회·최종 시점의 성공률은 해당 예산 안에 실제 평가된 snapshot에 대해서만 계산한다. 조기 종료한 실행에 추가 시험 성공을 만들어 넣지 않는다. 성공 후 종료한 실행은 같은 최종 source 결과를 유지했다고 표시할 수 있다.

개발 중 공개 시험 결과와 종료 후 숨겨진 시험 결과를 구분한다. 숨겨진 시험이 최종 snapshot에만 수행되면 최초·1회·3회 수치는 **공개 시험 성공률**이다. 과거 snapshot의 숨겨진 성공률을 주장하려면 종료 후 보존한 각 snapshot을 숨겨진 시험으로 다시 평가해야 한다. 최종 성공률은 수치·상태·연결·공유 제약·합성의 전체 필수 gate로 산정한다.

`status.json`이 준비 상태를 기록한다. `kernel_inventory.json`은 시작 자료 후보의 source identity다. 이 목록은 실행·검증 PASS 보고서가 아니다. 평가기 보정 및 격리 환경 검사가 완료되기 전에 참가 Agent를 시작하지 않는다.
