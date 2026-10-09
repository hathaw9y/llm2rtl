# W4A4KV4 Attention 전체 ISA 프로그램 — program-only v1

현재 구현 범위는 **전체 Attention 프로그램 생성기와 byte-bank ISA interpreter**이다.
Q/K/V·출력 projection, 중간 양자화, QK, Softmax, PV까지 포함한다.
현재 검증된 quantizer RTL용 ISA와 별도 프로파일이며, 이 프로그램을 기존 RTL에
그대로 넣어 실행할 수는 없다. 새 연산 엔진과 controller 생성의 입력 명세이다.
기존 검증본은 `../attention_int4_noscale_zcu104_r1/`에 보존한다.

## 전체 명령 흐름

기본 예제는 token=3, input=33, head=2, head_dim=16, output=33이다.
21개 명령의 실제 listing은 `programs/prefill/program.asm`에 있다.

```text
MM2S x, wq, wk, wv, wo, mask             # 각각 하나의 명령: 6개
QUANTIZE x4 <- x                        # token별 BF16 scale
PROJECT qfp <- x4, wq
QUANTIZE q <- qfp                       # 전체 token feature에 공통 scale
PROJECT kfp <- x4, wk
QUANTIZE k <- kfp                       # token/head별 scale
PROJECT vfp <- x4, wv
QUANTIZE v <- vfp                       # token/head별 scale
QK scores <- q, k                       # INT32 dot, scale 및 1/sqrt(head_dim)
SOFTMAX probabilities <- scores, mask   # causal/padding, stable FP32, BF16 저장
PV context <- probabilities, v         # dequantized V, FP32 누산 및 head 연결
QUANTIZE context4 <- context            # token별 scale
PROJECT output_fp <- context4, wo
QUANTIZE output4 <- output_fp           # token별 scale
S2MM output4                           # INT4와 BF16 scale 함께 저장
END
```

Weight의 group-32 양자화는 static weight export 단계에서 수행한다. 실행 중 PS가
수행하는 일은 descriptor 설정, 명령과 입력의 전송, 결과 수집이다. Projection,
양자화, Softmax 등의 실행 중 수치 연산은 모두 ISA compute 명령에 있다.

## 수치 및 memory 규칙

- INT4는 symmetric `[-7,7]`, zero-point=0, `-8`은 예약값이다.
- Activation/Q/context/output scale은 token별 BF16이다. Q는 head 전체에 하나의
  scale을 공유한다. K/V는 각각 token/head별 BF16 scale이다.
- Weight scale은 output row별 input-axis group-32 BF16이며 tail group도 처리한다.
- Quantizer는 maxabs/7을 BF16 ties-to-even으로 반올림하고 최소 normal로 clamp한다.
  zero row scale은 1이다. INT4 반올림도 ties-to-even이다.
- Projection은 group마다 INT32 partial, scale 적용과 group 합산은 unfused FP32다.
  QK는 INT32 dot 뒤 BF16 scales와 FP32 `1/sqrt(head_dim)`을 적용한다.
- Softmax는 max subtraction, FP32 exponential 및 key 순서의 FP32 합산을 사용하고
  확률을 BF16으로 저장한다. 전부 masked면 확률과 context가 0이다.
- PV는 BF16 probability × dequantized INT4 V, key 순서의 FP32 누산이다.
  PV의 곱셈을 INT4×INT4로 취급하지 않는다.
- 각 tensor는 별도 logical bank를 가진다. INT4는 low nibble 먼저 연속 packing한다.
  INT4 data 뒤 16-byte 경계에 BF16 scale 배열을 놓고 전체 DMA 크기도 16-byte로
  올림한다. FP32/BF16은 little-endian, 마지막 data nibble과 padding은 0이다.
- Compute operand에는 DDR 주소나 raw bank offset이 없다. tensor 시작점은 bank
  offset 0이며 shape/format/scale 위치/capacity는 descriptor table로 정한다.
  해당 table은 program 시작 전에 고정되어야 하며 실행 중 수정할 수 없다.
- 현재 예제는 19개 resident bank를 사용한다. capacity는 descriptor에 정확히
  산출하지만 실제 FPGA memory 예산/tiling 가능성은 아직 검증하지 않았다.

## ISA encoding

128-bit word의 field 배치는 `isa_spec.json`에 있다.
`opcode[127:120], dst[119:112], src0[111:104], src1[103:96],
descriptor[95:64], immediate[63:0]`이다. 명령 binary는 word별 little-endian,
`.mem`은 word별 32자리 hex이다. tensor descriptor index는 bank ID와 같다.

MM2S는 dst, S2MM은 src0를 사용하며 descriptor가 같은 bank를 지정한다.
DMA byte count는 descriptor capacity이고 immediate는 16-byte aligned DDR 주소다.
QUANTIZE는 dst/src0, 나머지 compute는 dst/src0/src1을 사용한다.
Compute immediate와 사용하지 않는 operand는 0, END의 모든 field는 0이다.
Compute는 source와 destination을 alias할 수 없다.

헤드 수, head dimension, query index 목록, causal 여부는 program context이다.
Mask는 MM2S로 적재한 U8 bank이며 1=valid, 0=masked이다. 이것과 descriptor table은
필수 ISA 설정 ABI이다. controller/descriptor ROM의 RTL은 앞으로 생성해야 한다.

모든 명령은 순차 실행되고 현재 명령의 완료 후 다음 명령으로 진행한다.
하드웨어 completion은 **모든 read response 처리와 마지막 write 수락 후** 발행해야
하며, controller는 그때 ownership을 해제한다. Interpreter는 atomic 명령 단위로
이를 모델링한다. read latency, backpressure, ownership 해제의 cycle 검증은 아니다.

## 생성과 실행

repository root에서:

```sh
python designs/attention_w4a4kv4_bf16scale_isa_r1/isa_program.py --out /tmp/attention-program
python designs/attention_w4a4kv4_bf16scale_isa_r1/isa_program.py --replay /tmp/attention-program
python -m unittest discover -s designs/attention_w4a4kv4_bf16scale_isa_r1 -p 'test_*.py' -v
```

`--tokens`, `--inputs`, `--heads`, `--head-dim`, `--outputs`, `--noncausal`,
`--queries`로 프로그램을 바꿀 수 있다. 예제 DDR 입력은 고정 seed의 synthetic data다.
실제 tensor는 Python API `prepare(config, x, wq, wk, wv, wo, mask)`로 export한다.

출력에는 `program.mem`, `program.bin`, `program.asm`, decoded listing,
`descriptor_table.json`, 주소별 DDR input binary, 최종 INT4+scale expected binary,
reference FP32 inputs, source/artifact SHA256 manifest가 포함된다.
저장된 binary를 다시 디코딩하여 실행하고 expected output과 byte 단위로 비교한다.

## 검증 범위와 남은 작업

8개 self-checking 테스트가 INT4/scale/BF16 probability/FP32 output을 기존 full
Attention reference와 exact bits로 비교한다. Interpreter의 QK·Softmax·PV loop와
명령 scheduling은 별도 구현이며 quantization/projection arithmetic primitive는
기존 reference를 재사용한다. 이는 새 RTL datapath의 독립 검증 결과가 아니다.

causal 및 noncausal, padding/all-masked, query 순서·중복·last-token, zero logits,
group-32 tail, 257-element activation row, binary replay, invalid instruction,
미초기화 bank, DMA extent, descriptor/scale 오류를 검사한다.

기존 QUANTIZE RTL은 단일 row MAX256 및 기존 3-bank ISA만 검증되었다. 새 QUANTIZE
명령은 tensor 여러 row를 처리하는 상위 엔진을 정의하며 257 이상 row도 interpreter
규칙으로만 지원한다. token 전체 scale을 보존해야 하므로 여러 chunk를 독립 양자화하여
대체할 수 없다. PROJECT/QK/SOFTMAX/PV RTL과 새 ISA controller는 미구현이다.

본 프로그램은 일반 MHA의 지정 query 조회를 제공한다. 마지막 token 예제도 K/V를
다시 projection하며 persistent KV cache append/read를 구현하지 않는다. bias, RoPE,
GQA, LayerNorm, 실제 모델 정확도, Softmax hardware approximation, routed timing,
보드 실행은 범위 밖이다. 현재 프로파일은 shared whole-model ISA gate의 PASS를
주장하지 않는다. 차후 실제 memory 예산과 descriptor interface를 확정한 뒤 RTL을
생성하고 기존 공통 completion 규칙과 함께 검증해야 한다.
