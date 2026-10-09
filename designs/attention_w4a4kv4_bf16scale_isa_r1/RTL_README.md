# W4A4KV4 Attention ISA RTL

이 문서는 program-only v1 이후 추가한 RTL 구현을 설명한다. 기존 `README.md`,
`validation.json`, 프로그램 binary와 이전 검증 evidence는 해당 시점의 기록으로 보존한다.
현재 **bounded standalone Attention ISA RTL 검증은 PASS**다. 완료 판정은
`rtl_validation.json`과 `evidence/tensor_isa_final002/parent_acceptance.json`에 기록한다.

## 실행 구조

`rtl/attention_tensor_isa_top.sv`가 command BRAM의 128-bit ISA를 받아 실제
controller, tensor executor와 local bank subsystem을 연결한다. 외부 DMA 경계에는
MM2S/S2MM command/status와 native local-memory 포트가 있다. 공유 infrastructure의
exclusive ownership table, port router, XPM BRAM을 재사용하고 설계별 controller와
compute engine은 이 revision 안에 둔다.

Controller는 한 명령씩 실행한다. 요청 수락 시 source/destination ownership을
원자적으로 획득하고, 해당 명령의 모든 read response 처리와 마지막 write 수락이
끝난 뒤 engine이 발행한 completion을 확인해 ownership을 해제한다. 별도 bank
read-pending scoreboard는 없다. 잘못된 identity, 권한, 주소 또는 transport fault는
ownership을 유지하고 reset을 기다린다. 정상적으로 정리된 연산 오류는 destination을
확정하지 않고 소유권을 해제한다. 완료·해제 cycle의 bank 오류도 즉시 차단한다.

실제 명령 흐름은 입력/weight/mask MM2S 6개 → activation 양자화 → Q/K/V projection과
양자화 → QK → Softmax → PV → context 양자화 → output projection과 양자화 → S2MM → END다.
기본 프로그램은 21개 명령이며 13개 compute 명령을 포함한다. 진단 프로그램은 13개
중간 tensor를 추가 S2MM으로 반출하여 INT4, BF16 scale/probability, FP32와 padding을
모두 비교한다.

## 수치 규칙과 구현 범위

- Signed INT4 `[-7,7]`, zero point 0. Activation/Q/context/output은 token별 BF16 scale,
  K/V는 token·head별 BF16 scale, weight는 output row·input group-32별 BF16 scale이다.
- Projection/QK의 정수 누산은 INT32이며 scale 적용과 합산은 FP32다. FP32 기본 연산은
  finite 입력에서 RNE와 gradual underflow를 지원하고 곱셈과 덧셈을 분리한다.
- Softmax는 `1/sqrt(head_dim)`, stable max subtraction, causal/padding mask를 유지한다.
  exponential은 exp2 ROM과 FP32 보간이며 `[-80,0]`에서 상대오차 상한 `1e-5`,
  -80보다 작은 입력은 0이다. 확률은 BF16, PV는 dequantized V와 FP32 누산이다.
- INT4는 row 사이 padding 없이 low nibble부터 연속 packing한다. Scale 배열 시작과
  전체 DMA 크기는 16-byte 정렬한다. 모든 tensor는 별도 logical bank에 저장한다.
- Token/query 최대 32, input/output 및 전체 head width 최대 256, head 최대 4,
  head_dim 최대 64다. Shape, query 목록, causal 설정은 build 시 descriptor/context
  ROM으로 생성한다. 변경하려면 ROM을 다시 생성하고 해당 구성을 검증해야 한다.
- 초기 scalar 실행 구조다. Systolic array, large-model tiling, persistent KV cache,
  bias, RoPE, GQA, LayerNorm 및 pretrained model 정확도는 구현 범위에 포함되지 않는다.

## 재현

Repository root에서 실행한다. 각 runner는 새로운 output directory를 요구하며
소스 snapshot, SHA256 manifest, raw tool log와 exit code를 보존한다.

```sh
python3 scripts/check_common_contracts.py
python3 -m unittest discover -s designs/attention_w4a4kv4_bf16scale_isa_r1 -p 'test_*.py'
python3 -m unittest discover -s designs/attention_w4a4kv4_bf16scale_isa_r1/python -p 'test_*.py'
python3 designs/attention_w4a4kv4_bf16scale_isa_r1/scripts/run_tensor_isa.py \
  --out /tmp/attention-isa-verify --mode all \
  --math-review designs/attention_w4a4kv4_bf16scale_isa_r1/evidence/math_review.json \
  --executor-review designs/attention_w4a4kv4_bf16scale_isa_r1/evidence/executor_review.json
```

Runner는 Vivado 2025.2, XSIM, Verilator를 사용한다. 통합 testbench는 실제 compute
RTL과 XPM memory를 실행하고 DMA의 native peer만 BFM으로 제공한다. Command BRAM
검증 구성은 `CMD_ADDR_WIDTH=6`, `MAX_COMMANDS=64`, read latency 1 또는 2다.
Strict lint는 source closure를 대상으로 하며 top 기본 parameter
`CMD_ADDR_WIDTH=10`, `MAX_COMMANDS=1024`, latency 1을 사용한다. 이 구성의 dynamic/OOC
PASS를 주장하지 않는다. Latency 2는 별도 prefill simulation이며 별도 lint/OOC는 수행하지 않았다.
모듈의 다른 parameter 값에는 이 결과를 자동으로 적용하지 않는다. Full top 합성은
기본 prefill descriptor ROM 구성만 대상으로 하며, 다른 shape의 메모리 자원과 타이밍은
별도 합성으로 확인해야 한다.
OOC는 ZCU104 part `xczu7ev-ffvc1156-2-e`, 5 ns clock의 배치 전 합성 검증이다.
Routed timing, BIT/HWH/XSA, 실제 PS/DDR/DataMover 또는 보드 실행 결과는 아니다.

이 standalone tensor ISA는 별도 schema를 사용한다. 기존 whole-model ISA checker의
multiple-outstanding/model-trace gate에는 적용하지 않으며 해당 gate PASS를 주장하지 않는다.

## 최종 검증 결과

| 대상 | 확인한 결과 |
| --- | --- |
| ISA/reference Python | 프로그램 8개, hardware reference 3개 테스트 PASS |
| FP32/exp와 tensor executor | 별도 독립 리뷰 PASS, executor 9개 구성 243개 사례 PASS |
| Controller/bank | Command read latency 1·2 각각 38개 사례 PASS; 완료/해제 오류 및 high-bit 주소 alias 차단 |
| 실제 전체 ISA | 9개 구성 52개 사례와 latency 2 prefill 36개 사례 PASS; 13개 중간 tensor의 모든 data·scale·padding word 일치 |
| Strict lint | 9개 생성 descriptor 구성 PASS; 위에 명시한 기본 parameter 범위 |
| 실제 top OOC | 기본 prefill 5 ns: WNS +0.149 ns, WHS +0.061 ns, WPWS +1.958 ns, setup·hold·pulse 실패 0 |

기본 prefill 합성 자원은 LUT 16,992, FF 7,004, RAMB36 38, RAMB18 1, DSP 8이다.
DSP pipeline DRC 권고 17개와 quantizer RAM output register methodology 권고 1개가
남아 있다. OOC 합성 결과에 한정하며 배치·배선 및 보드 동작을 보장하지 않는다.

수정 전 race 재현과 실패 timing trial은 그대로 보존한다. `tensor_isa_final002/result.json`의
pending-review 상태는 당시 작성된 immutable 기록이며, 이후 완료된 parent 독립 검토는
같은 디렉터리의 `parent_acceptance.json`/`.md`가 기록한다. 최종 checkpoint와 이 문서가
현재 상태를 나타낸다. Parent는 RTL을 작성하지 않았고, child 수치/제어 독립 리뷰와
실제 전체 경로의 source·snapshot·raw evidence 확인을 통해 최종 범위를 승인했다.
