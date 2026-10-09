# SmolLM2-135M BF16 FPGA 실험 결과 보고서

| 항목 | 내용 |
| --- | --- |
| 문서 상태 | 실험 결과 보고서, 2026-10-03 |
| 대상 모델 | `HuggingFaceTB/SmolLM2-135M` |
| Checkpoint revision | `93efa2f097d58c2a74874c7e644dbc9b0cee75a2` |
| 실행 장치 | ZCU104, baremetal A53, PL 100 MHz |
| 데이터 형식 | BF16 가중치, activation 및 KV cache |
| 시험 범위 | 고정 입력 prefill 32토큰과 이어지는 decode 1토큰 |
| 결과 판정 | 전체 ISA 실행 완료. 최종 수치 결과는 검토 필요. |

이 보고서는 짧은 문장과 일정한 용어를 사용한다. 이 방식은 ASD-STE100의 작성 원칙을 한국어에 적용한 것이다. ASD-STE100은 영어에 적용되는 표준이다. 이 한국어 보고서는 ASD-STE100 적합성 인증 문서가 아니다.

## 1. 목적

이 실험은 SmolLM2-135M의 추론 연산을 PS가 생성한 ISA 명령열로 실행하는지 확인한다. PL은 모델의 tensor 연산을 수행한다. PS는 명령 순서, DDR 주소, bank와 크기를 지정한다. PS는 모델 tensor 값을 계산하지 않는다.

### 1.1 실제로 만든 것

Agent는 **모델을 ISA 명령열로 바꾸는 PS 프로그램**, **그 명령을 실행하는 PL 가속기**, **ZCU104용 실행 산출물**, **수치 검증 도구**를 만들었다. 아래 표는 최종 통합 경로에 들어간 구성과 그 역할을 보여준다. 공통 infrastructure를 재사용한 부분도 구분했다.

| 산출물 | 만든 내용과 연결 관계 | 구현 파일 또는 산출물 |
| --- | --- | --- |
| 모델 ISA와 PS 명령 생성기 | 12개 opcode와 128비트 record를 정의했다. PS C 코드가 입력 token ID, 위치, layer 및 tile에 맞춰 명령열을 생성하고 command BRAM에 조각별로 적재한다. | [ISA 명세](../isa_spec.json), [PS 명령 생성기](../full_model_board_probe/program.c) |
| 명령 dispatcher와 bank 상태 관리 | 명령을 decode해 DMA 또는 compute executor로 보낸다. PC, bank 점유·해제, 완료·오류 응답, `FENCE` 및 조각별 `END/DONE`을 처리한다. 공통 dispatcher·bank 관리 계약에 모델별 경로를 채웠다. | [dispatcher](../rtl/isa_command_dispatcher.sv), [tensor 상태 추적기](../rtl/bank_tensor_state_tracker.sv) |
| DDR 전송 및 13-bank 메모리 경로 | 공통 DataMover를 재사용하고 모델용 DMA 연결, bank bridge, bank 메모리, 포트 router를 만들었다. 가중치·KV를 DDR에서 bank로 읽고 KV·logits를 DDR에 쓴다. | [공통 DataMover](../../../ip/infrastructure/datamover_engine/engine_module_index.json), [DMA 연결](../rtl/smollm2_dma_engine_link.sv), [bank bridge](../rtl/smollm2_dma_bank_bridge.sv), [bank 메모리](../rtl/smollm2_bank_memories_wide.sv), [포트 router](../rtl/smollm2_bank_port_router_wide.sv) |
| 행렬 연산 경로 | DSP를 쓰는 16×16 BF16 systolic GEMM executor와 연결 fabric을 만들었다. Q/K/V·output·FFN·lm_head projection에 쓴다. `ATTN_SCORE`와 `ATTN_VALUE`도 같은 PE 배열의 모드로 실행한다. | [GEMM executor](../rtl/smollm2_gemm_systolic_wide_executor.sv), [통합 fabric](../rtl/smollm2_gemm_dma_fabric_wide.sv) |
| 나머지 모델 연산 executor | RMSNorm, RoPE, Softmax, residual ADD, SiLU×Mul을 각각 RTL executor로 만들고 fabric에 연결했다. | [RMSNorm](../rtl/smollm2_rmsnorm_executor.sv), [RoPE](../rtl/smollm2_rope_executor.sv), [Softmax](../rtl/smollm2_softmax_executor.sv), [ADD](../rtl/smollm2_add_executor.sv), [SiLU×Mul](../rtl/smollm2_silu_mul_executor.sv) |
| 보드 통합 및 baremetal 앱 | ZCU104용 100 MHz PL 설계를 배선해 BIT·HWH·XSA를 만들었다. 같은 bitstream에 전체 30-layer용 ELF를 실행한다. SD 카드 `MODEL.BIN`을 DDR에 읽고, 고정 prefill 32토큰과 decode 1토큰을 실행한다. | [BIT](../full_model_board_probe/artifacts/zcu104_first_layer_kv_board_probe.bit), [XSA](../full_model_board_probe/artifacts/zcu104_first_layer_kv_board_probe.xsa), [전체 모델 ELF](../full_model_sd_board_probe/artifacts/smollm2_full_model_30_layer_sd_probe.elf), [정적 BF16 이미지](../full_model_board_probe/ddr_static_bf16.bin) |
| 검증 및 대화형 실행 준비 | Python 명령 검증·ISA interpreter, golden 값, UART 비교 앱을 만들었다. 호스트 tokenization과 token 선택을 위한 대화형 호스트·보드 코드는 준비했다. 대화형 코드는 실물 보드에서 아직 검증하지 않았다. | [명령 검증 스크립트](../scripts/verify_full_model_board_program.py), [검증 결과](../full_model_board_probe/program_verification.json), [보드 앱](../full_model_board_probe/main.c), [대화형 호스트](../interactive_board_probe/ask.py), [대화형 보드 코드](../full_model_board_probe/interactive_main.c) |

구현 순서는 GEMM과 DMA 경로 → RMSNorm → RoPE → Softmax → 공유 GEMM의 attention 모드 → ADD → SiLU×Mul → DDR KV cache → 첫 layer 전체 실행 → 30-layer PS 명령 생성과 SD 적재였다. 각 단계의 실물 보드 확인 범위는 5절에 적었다.

이 보고서는 네 종류의 결과를 구분한다.

1. Python ISA interpreter와 명령 생성 코드의 비교 결과
2. RTL의 합성·배치·배선 결과
3. 사용자가 제공한 실물 보드 UART 결과
4. 아직 실행하거나 측정하지 않은 항목

## 2. 시험 구성

| 항목 | 설정 |
| --- | --- |
| 모델 구조 | Decoder layer 30개, hidden size 576, FFN size 1536 |
| Attention | Q head 9개, KV head 3개, head dimension 64 |
| Vocabulary | 49,152개 토큰 |
| 지원 context | 최대 1024토큰 |
| Prefill 처리 단위 | 최대 32토큰 |
| 명령 형식 | 128비트 ISA record |
| Command BRAM | 조각당 작업 명령 최대 15개와 `END` 1개 |

PS는 실행 중 필요한 명령을 조각으로 나눈다. PL은 각 조각의 `END`에서 미완료 명령을 끝낸다. PS는 `DONE` 뒤에 다음 조각을 적재한다. Bank 데이터와 DDR KV cache는 조각 사이에 유지된다.

정적 모델 이미지는 SD 카드의 `MODEL.BIN`에서 DDR로 적재한다. 이미지 크기는 **269,161,088바이트**다. 모델 가중치, KV cache와 logits 영역을 포함한 DDR 예약량은 **292,852,352바이트**다. 정적 이미지의 SHA-256은 `7439dd37925be3ba6c3ef6853b1728d836c6bdda13d7bbbcc93f7966bd745c68`이다. 보드 앱은 적재 중 크기와 CRC32 `db7d52bb`를 확인한다.

시험 입력은 고정 token ID 32개의 prefill과 절대 위치 32의 decode token 1개다. Prefill token ID는 11부터 시작해 17씩 증가한다. 마지막 prefill token ID는 538이다. Decode token ID는 555다. 이 시험은 자유 생성 시험이 아니다.

## 3. 실행 및 비교 방법

PS의 C 프로그램은 각 layer의 정규화, projection, RoPE, attention, residual, FFN을 ISA로 전개한다. K와 V는 `DMA_STORE`로 DDR에 기록한다. `FENCE`가 DDR 쓰기 완료를 확인한다. 이후 `DMA_LOAD`가 현재 위치까지의 K/V를 로컬 bank에 적재한다. 마지막 layer 뒤에는 final RMSNorm, lm_head GEMM 및 logits `DMA_STORE`를 실행한다.

Python 검증은 PS의 실제 128비트 명령 records를 Python 생성 결과와 비교했다. ISA interpreter는 같은 명령을 tensor 값에 적용했다. Interpreter의 마지막 logits는 고정 입력의 reference logits와 일치했다.

실물 보드 앱은 각 명령 조각의 완료를 확인했다. 앱은 layer 중간값과 최종 logits를 reference 값과 비교했다. 앱의 비교 코드는 PL의 `DONE` 뒤에 값을 읽었다. 이 비교 결과는 다음 모델 연산의 입력에 사용하지 않았다.

이 보고서의 *legacy mismatch*는 **BF16 ULP 거리 > 16이면서 절대오차 > 0.002**인 값이다. `mismatches=0`은 이 기준의 위반이 0개라는 뜻이다. 비트 단위 일치를 뜻하지 않는다.

## 4. 만든 가속기의 ISA와 실행 경로

현재 ISA에는 **12개 opcode**가 있다. 레코드의 상위 4비트는 opcode다. 다음 12비트는 최대 세 개의 논리 bank ID다. 나머지 112비트는 명령별 인자다. DMA 명령은 DDR 주소, 로컬 byte offset 및 전송 byte 수를 사용한다. Compute 명령은 DDR 주소를 직접 받지 않는다.

| Opcode | 명령의 입력과 결과 | 실제 구현 |
| --- | --- | --- |
| `END` | 현재 명령 조각을 끝낸다. | Dispatcher가 미완료 DMA·compute 응답을 모두 기다린 뒤 `DONE`을 낸다. Bank와 DDR 내용은 유지한다. |
| `DMA_LOAD` | DDR 주소·byte 수 → 목적 bank. Embedding, 가중치 tile, RoPE 계수 및 KV prefix를 적재한다. | 공통 DataMover의 MM2S 경로와 bank bridge를 사용한다. 로컬 bank 쓰기가 끝난 뒤 완료 응답을 낸다. |
| `DMA_STORE` | 원본 bank·byte 수 → DDR 주소. K/V 또는 logits를 기록한다. | 공통 DataMover의 S2MM 경로를 사용한다. DDR 쓰기 응답 뒤 완료로 처리한다. |
| `GEMM` | Activation bank × weight bank → 출력 bank. `n_start`, `n_total`, `m_start`, `m_count`, `k`, `n_tile`을 사용한다. | 16×16 BF16 systolic array가 최대 32행과 출력 192열의 tile을 계산한다. 각 tile은 K 전체를 누산한다. `n_start`는 출력의 논리 열 위치다. |
| `RMSNORM` | 입력 bank·gamma bank → 출력 bank. | 별도 executor가 hidden width 576을 정규화한다. Epsilon은 `1e-5`다. |
| `ROPE` | Q 또는 K bank·계수 bank → 같은 Q 또는 K bank. | 별도 executor가 BF16 Q/K에 위치 회전을 적용한다. 데이터 bank는 마지막 쓰기까지 점유한다. |
| `ATTN_SCORE` | Q bank·K prefix bank → score bank. | Fabric이 명령을 공유 GEMM PE 배열의 attention score 모드로 보낸다. PL이 Q head 9개와 KV head 3개의 대응을 처리한다. Score에는 `1/8` scale을 적용한다. |
| `SOFTMAX` | Score bank → 같은 bank의 probability. | 별도 executor가 causal mask와 max-subtract softmax를 적용한다. 내부 변환과 근사는 Q16.16 및 Q0.30 형식을 사용한다. 결과는 BF16으로 반올림한다. |
| `ATTN_VALUE` | Probability bank·V prefix bank → context bank. | Fabric이 명령을 공유 GEMM PE 배열의 attention value 모드로 보낸다. PL이 V tile 배치와 GQA head 대응을 처리한다. |
| `ADD` | 두 입력 bank → 출력 bank. | 별도 executor가 residual의 BF16 원소별 합을 계산한다. |
| `SILU_MUL` | Gate bank·up bank → FFN 중간 출력 bank. | 별도 executor가 BF16 SiLU lookup 결과와 up 값을 곱한다. |
| `FENCE` | 앞서 수락된 명령의 완료를 확인한다. | Dispatcher는 S2MM 쓰기 응답을 포함한 모든 앞선 완료 응답을 기다린 뒤 PC를 진행한다. |

GEMM PE는 BF16 significand 곱셈에 DSP를 사용한다. PE는 exponent를 정렬한 signed 32비트 누산 값을 유지한다. 이는 IEEE FP32 덧셈기를 그대로 사용한 누산이 아니다. 출력은 BF16 round-to-nearest-even 규칙으로 만든다. 일반 `GEMM`, `ATTN_SCORE`, `ATTN_VALUE`는 같은 16×16 PE 배열을 공유한다. Fabric은 명령 종류에 맞춰 입력 layout과 완료 응답 경로를 선택한다.

Compute executor는 `cmd_valid`와 `cmd_ready`로 명령을 수락한다. 완료 응답은 `done_valid`, `done_tag`, 사용한 bank 수·ID 및 `done_error`를 포함한다. Dispatcher는 응답의 bank ID를 확인해 해당 bank를 release한다. DataMover의 완료 응답도 현재 PC와 별도로 수집한다. Bank router는 논리 bank ID를 실제 데이터 포트에 연결한다.

로컬 메모리는 논리 bank 13개로 구성된다. 기본 저장·쓰기 단위는 128비트다. GEMM에 사용하는 B2, B3, B10, B11은 짝수·홀수 128비트 단어를 병렬로 읽어 256비트 응답을 만든다. Bank read latency는 3 cycle이다. Fabric은 읽기 응답의 데이터, `valid`, bank ID를 함께 등록해 같은 요청으로 정렬한다.

RMSNorm은 입력을 Q16.16으로 변환해 제곱합을 구한다. 평균 제곱과 epsilon에는 Q32.32를 사용한다. Executor는 제곱근과 역수를 계산하고 gamma를 적용한다. Softmax는 행의 최댓값을 먼저 찾는다. 그다음 exp lookup과 보간으로 합을 구하고 역수로 확률을 계산한다. SiLU×Mul은 BF16 SiLU lookup을 사용한다. 이 수치 규칙은 각 명령의 golden 비교 기준이다.

다음은 한 layer의 명령 순서다. PS는 layer 반복 전에 token embedding과 RoPE 계수를 적재한다. 대괄호 안의 `DMA_LOAD`와 `GEMM` 쌍은 필요한 출력 채널 tile마다 반복된다. Weight bank는 각 쌍 뒤에 재사용한다.

```text
DMA_LOAD(gamma) → RMSNORM
[DMA_LOAD(Q weight tile) → GEMM(Q tile)] 반복
[DMA_LOAD(K weight tile) → GEMM(K tile)] 반복
[DMA_LOAD(V weight tile) → GEMM(V tile)] 반복
ROPE(Q) → ROPE(K)
DMA_STORE(K) → DMA_STORE(V) → FENCE
DMA_LOAD(K prefix) → DMA_LOAD(V prefix)
ATTN_SCORE → SOFTMAX → ATTN_VALUE
[DMA_LOAD(output weight tile) → GEMM(output tile)] 반복 → ADD
DMA_LOAD(gamma) → RMSNORM
[DMA_LOAD(gate weight tile) → GEMM(gate tile)] 반복
[DMA_LOAD(up weight tile) → GEMM(up tile)] 반복
SILU_MUL
[DMA_LOAD(down weight tile) → GEMM(down tile)] 반복 → ADD
```

최종 layer 뒤에는 `DMA_LOAD(final gamma) → RMSNORM → [DMA_LOAD(lm_head tile) → GEMM] 반복 → DMA_STORE(logits) → FENCE`가 이어진다. 실제 C 프로그램은 큰 가중치를 tile로 나누고 각 `GEMM` 바로 앞에 해당 tile의 `DMA_LOAD`를 배치한다. 이 명령열에서 PS는 주소와 실행 순서를 만든다. PL은 모든 tensor 계산과 DDR 이동을 수행한다.

## 5. 단계별 보드 확인

| 단계 | 관찰한 결과 | 적용 범위 |
| --- | --- | --- |
| GEMM 및 DMA 적재 | 초기 GEMM과 DDR→`DMA_LOAD`→bank 경로를 보드에서 확인 | 제한된 projection 출력 |
| RMSNorm·RoPE·Softmax | 각 모듈을 추가한 통합 probe가 비교를 수행 | Prefill 32토큰과 단일 토큰의 일부 채널 |
| Attention·ADD | Q, score, probability, context, residual 비교의 보고된 mismatch는 0개 | 첫 layer의 각 행 첫 16개 채널 |
| 실제 attention output projection | Q부터 output projection과 첫 residual까지 비교의 보고된 mismatch는 0개 | 첫 layer의 각 행 첫 16개 채널. K/V 입력은 고정 reference 데이터 |
| SiLU×Mul | 수정한 앱에서 prefill과 단일 토큰의 보고된 mismatch는 0개 | 각 행 첫 16개 채널. Gate/up 입력은 고정 reference 데이터 |
| 첫 layer 전체 출력 | 전체 576개 채널을 캡처해 오차를 분석 | KV cache 없는 prefill 32토큰과 cold 단일 토큰 |
| 첫 layer KV | DDR K/V 갱신 뒤 prefill→decode 실행. 지정한 수치 한계 안에서 PASS | 실제 KV cache를 사용하는 첫 layer |
| 전체 30개 layer | SD 적재, prefill, 이어지는 decode 및 logits 출력 완료 | 고정 입력 1건. 수치 결과는 별도 검토 |

초기 일부 probe는 각 행의 첫 16개 채널만 외부에서 비교했다. 이 결과는 해당 tensor의 모든 채널이 일치한다는 증거가 아니다. 이후 첫 layer 전체 출력 시험은 32 × 576개 값을 캡처했다.

SiLU×Mul의 첫 보드 시험은 완료 전 write count를 읽어서 실패했다. 앱은 dispatcher `DONE`을 기다리도록 수정됐다. 수정 후 시험은 `BOARD SILU_MUL PASS`를 보고했다. 이 수정에서는 ELF를 변경했다.

## 6. 첫 layer 수치 결과

### 6.1 KV cache를 제외한 전체 출력

첫 layer의 마지막 residual 32 × 576개 BF16 값을 보드에서 수집했다. Prefill 결과의 평균 절대오차는 **0.003371**이다. RMSE는 **0.007187**이다. 최대 절대오차는 **0.125**다. Legacy mismatch는 **282/18,432개**다.

이 실험의 단일 토큰은 과거 KV가 없는 cold 입력이다. 해당 576개 출력의 평균 절대오차는 **0.002558**이다. RMSE는 **0.005763**이다. 이 결과를 KV cache를 사용하는 decode 결과로 해석하지 않는다.

FFN 중간 출력의 전체 채널도 따로 조사했다. 보드에서 관찰한 FFN 입력을 reference FFN에 넣어 재계산했다. 이 비교는 이전 단계의 오차 전파와 FFN 자체의 오차를 구분하는 데 사용했다. PS는 이 재계산을 추론 중에 수행하지 않았다.

### 6.2 KV cache를 포함한 실행

첫 layer의 prefill은 K와 V를 DDR에 기록했다. 이어지는 decode는 저장된 KV를 읽었다. Prefill의 DDR K 비교는 **6,144개 값**, V 비교도 **6,144개 값**을 대상으로 했다. Decode 뒤 비교는 K와 V 각각 **6,336개 값**을 대상으로 했다.

Prefill의 K RMSE는 **0.001165**다. V RMSE는 **0.000045**다. 첫 layer 출력의 prefill RMSE는 **0.007187**이다. Decode 출력의 RMSE는 **0.005700**이다. 이 시험은 각 비교 tensor에 설정한 MSE ≤ 0.001 및 최대 절대오차 ≤ 0.2 조건으로 `BOARD LAYER0 KV PASS`를 보고했다.

## 7. 전체 모델 ISA 실행

PS 명령 생성기는 prefill에 **2,679개 연산 명령**을 만들었다. 보드 앱은 이를 **187개 command BRAM 조각**으로 실행했다. Decode는 **2,648개 연산 명령**을 **185개 조각**으로 실행했다. 조각 수에는 layer 경계에서 진단을 위해 끝낸 조각도 반영돼 있다.

사용자가 제공한 전체 UART 로그는 SD 이미지 **269,161,088바이트**의 적재와 CRC32 `db7d52bb` 확인을 기록한다. 같은 로그는 prefill 187개 조각과 decode 185개 조각의 완료를 기록한다. 마지막 표시는 `BOARD FULL MODEL ISA EXECUTION COMPLETE; REVIEW LOGITS`이다. 이 표시는 명령 실행 완료를 뜻한다. 최종 출력의 수치 판정은 아래 비교 결과를 따른다.

| 최종 logits 비교 | Prefill 32토큰 | Decode 1토큰 |
| --- | ---: | ---: |
| 비교한 BF16 값 | 49,152 | 49,152 |
| 평균 절대오차 | 0.054948 | 0.084860 |
| RMSE | 0.082846 | 0.102023 |
| 최대 절대오차 | 0.3125 | 0.3125 |
| 최대 ULP 거리 | 15 | 56 |
| Legacy mismatch | 0 | 3 |
| 보드 top-1 token ID | 282 | 28 |
| Reference top-1 token ID | 282 | 85 |

Prefill의 top-1 token ID는 reference와 같다. Decode의 top-1 token ID는 reference와 다르다. 해당 decode에서 reference의 상위 두 후보 점수 차이는 **0.125**다. 작은 점수 차이는 BF16 오차가 순위를 바꿀 가능성을 높인다. 이 사실만으로 오차의 모든 원인을 특정할 수는 없다.

각 layer에서 캡처한 첫 16개 채널의 평균 절대오차는 뒤쪽 layer에서 커졌다. Prefill은 layer 0에서 **0.003537**, layer 29에서 **0.545029**다. Decode는 layer 0에서 **0.001831**, layer 29에서 **0.373047**이다. 이 수치는 각 layer 전체 576개 채널의 평균이 아니다.

Final RMSNorm 뒤 lm_head에 들어가는 값은 마지막 token의 첫 16개 채널만 별도로 확인했다. Prefill의 평균 절대오차는 **0.016003**이다. Decode의 평균 절대오차는 **0.010468**이다. 이 tap은 전체 576개 채널 또는 logits 오차의 단일 원인을 증명하지 않는다.

## 8. 구현 결과

전체 실행에 재사용한 bitstream은 100 MHz로 배선됐다. 배선 보고서의 setup WNS는 **+0.997 ns**다. Hold WHS는 **+0.010 ns**다. 보고된 자원 사용량은 다음과 같다.

| 자원 | 사용량 | 장치 자원 대비 |
| --- | ---: | ---: |
| CLB LUT | 210,889 | 91.53% |
| CLB register | 101,301 | 21.98% |
| BRAM tile | 184 | 58.97% |
| URAM | 64 | 66.67% |
| DSP | 282 | 16.32% |

이 자원과 타이밍 수치는 배선된 bitstream에 적용한다. 실물 보드의 수치 정확도를 대신 증명하지 않는다. 특히 LUT 사용률은 후속 RTL 기능 추가의 여유가 작다는 점을 보여준다.

## 9. 증거의 범위와 제한

Python 명령 검증은 C 명령 record와 Python ISA의 일치를 확인했다. Interpreter는 고정 입력의 reference logits와 일치했다. 이 결과는 소프트웨어 수준의 ISA 의미 검증이다.

보드 실행 결과는 사용자가 제공한 UART 로그에 근거한다. UART 로그는 실행 마커와 수치를 기록한다. 로그 자체가 보드에 실제로 프로그램한 BIT와 ELF의 SHA-256을 독립적으로 증명하지는 않는다. 따라서 이 보고서는 보드 산출물과 UART 결과의 관계를 전달된 실행 문맥에 따라 식별한다.

현재 실물 시험은 고정 prefill 32토큰과 이어지는 decode 1토큰이다. 임의 프롬프트의 연속 생성 결과는 아직 없다. TTFT, prefill token/s, decode token/s, 소비 전력도 아직 실측하지 않았다. 대화형 실행 및 시간 계측 코드는 준비됐다. 실물 보드 시험 결과는 대기 중이다.

## 10. 결론

SmolLM2-135M의 고정 입력은 PS가 생성한 ISA 명령열을 통해 실물 ZCU104에서 실행됐다. PL은 30개 decoder layer, KV cache 갱신, final norm 및 lm_head를 실행했다. 보드는 prefill과 이어지는 decode의 최종 logits를 DDR에 기록했다.

명령 경로의 완료는 확인됐다. Prefill의 top-1 token ID도 reference와 같다. Decode의 top-1 token ID는 다르다. 따라서 결과는 **전체 ISA 실행 완료와 측정된 수치 차이**로 보고한다. 자유 생성의 정확도와 처리량은 후속 실물 시험으로 판단한다.

## 11. 근거 자료

| 자료 | 위치 |
| --- | --- |
| ISA 명세 | [isa_spec.json](../isa_spec.json) |
| PS 명령 생성 코드 | [program.c](../full_model_board_probe/program.c) |
| ISA dispatcher RTL | [isa_command_dispatcher.sv](../rtl/isa_command_dispatcher.sv) |
| DMA 연결·bank bridge | [smollm2_dma_engine_link.sv](../rtl/smollm2_dma_engine_link.sv), [smollm2_dma_bank_bridge.sv](../rtl/smollm2_dma_bank_bridge.sv) |
| GEMM·attention 공유 PE RTL | [smollm2_gemm_systolic_wide_executor.sv](../rtl/smollm2_gemm_systolic_wide_executor.sv) |
| 정규화·위치·softmax RTL | [smollm2_rmsnorm_executor.sv](../rtl/smollm2_rmsnorm_executor.sv), [smollm2_rope_executor.sv](../rtl/smollm2_rope_executor.sv), [smollm2_softmax_executor.sv](../rtl/smollm2_softmax_executor.sv) |
| Residual·FFN RTL | [smollm2_add_executor.sv](../rtl/smollm2_add_executor.sv), [smollm2_silu_mul_executor.sv](../rtl/smollm2_silu_mul_executor.sv) |
| Compute 및 bank 연결 | [smollm2_gemm_dma_fabric_wide.sv](../rtl/smollm2_gemm_dma_fabric_wide.sv) |
| Python 명령 검증 | [program_verification.json](../full_model_board_probe/program_verification.json) |
| 배선 검증 요약 | [verification.json](../full_model_board_probe/artifacts/verification.json) |
| 전체 모델 사용자 보드 결과 | [board_result_user_reported_full.json](../full_model_sd_board_probe/board_result_user_reported_full.json) |
| 첫 layer KV 보드 결과 | [board_result_user_reported.json](../first_layer_kv_board_probe/board_result_user_reported.json) |
| 첫 layer 전체 출력 분석 | [board_full_output_analysis.json](../first_layer_full_output_board_probe/board_full_output_analysis.json) |
| FFN 중간값 분석 | [board_ffn_analysis_rev2.json](../first_layer_ffn_board_probe/board_ffn_analysis_rev2.json) |
| 대화형 실행 계획과 상태 | [README.md](../interactive_board_probe/README.md) |
