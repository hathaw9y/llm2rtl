# Runtime GEMM/NON_GEMM trace

이 frontend는 모델을 실제로 한 번 실행하면서 PyTorch dispatcher 연산을 관찰한다. 모델
이름이나 Transformer 구조를 가정하지 않고 matrix 연산과 그 사이의 미해석 영역만
구분한다.

```text
actual Python execution
  → NON_GEMM region
  → GEMM event
  → NON_GEMM region
  → GEMM event
```

`GEMM`은 수학적 분류일 뿐 현재 FPGA GEMM executor가 해당 dtype, layout, shape 또는 operand
종류를 지원한다는 주장이 아니다. 모든 GEMM event의 `hardware_mapping`과 모든 NON_GEMM
region의 `mapping_status`는 처음에 `UNRESOLVED`다. Parent와 사용자가 실제 trace를 보고
module boundary와 fusion을 결정한 뒤 별도 capability 검사와 ISA validation을 수행한다.

## Factory protocol

CLI는 특정 모델 loader를 내장하지 않는다. `--factory PATH.py:function`의 함수가 다음
dictionary를 반환한다.

```python
{
    "model": torch.nn.Module,
    "args": tuple,
    "kwargs": dict,
    "metadata": dict,
}
```

실행 예시는 다음과 같다.

```bash
conda run --no-capture-output -n shmin python \
  scripts/trace_runtime_gemm_regions.py \
  --factory examples/trace_runners/llama32_1b_prefill.py:build_case \
  --output /tmp/llama32_1b_prefill_t4_runtime_trace.json
```

출력 파일은 exclusive-create로 열기 때문에 기존 결과를 덮어쓰지 않는다. 같은 경로가
이미 있으면 실행은 실패한다. `--include-raw-events`를 지정하면 collapse 전 dispatcher
event도 함께 기록한다.

## 제한

- trace는 지정된 입력으로 실제 관찰한 한 경로만 증명한다.
- eager attention과 fused SDPA는 서로 다른 dispatcher event를 만들 수 있으므로 실행
  metadata에 attention 구현을 기록한다.
- custom matrix operator는 자동 분류되지 않을 수 있다. 검토 후 `--gemm-op NAME`으로
  명시적으로 추가한다.
- 이 단계는 semantic name, opcode, bank, quantization fusion 또는 RTL module을 확정하지
  않는다.
