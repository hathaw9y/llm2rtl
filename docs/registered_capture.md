# Registered capture 공통 모듈

`ip/infrastructure/utils/registered_capture.sv`는 CE 판단 결과와 packet을 함께 저장하고,
다음 edge에서 등록된 CE의 Q로 output register를 갱신한다. 최종 CE 뒤에 조건을
다시 붙이지 않는 구조를 재사용하기 위한 모듈이다. 계산·ownership·routing은 호출자의 역할이다.
실제 연결 예시는 [registered_capture_example.sv](../ip/infrastructure/examples/registered_capture_example.sv)다.

## 포트와 parameter

| 항목 | 의미 |
| --- | --- |
| `aclk` | 단일 동기 클럭 |
| `aresetn` | active-low synchronous reset; 준비 data, CE, output data, valid 모두 초기화 |
| `capture_i` | 이 edge에서 실제 수락된 packet의 사건. 지속되는 요청 level을 그대로 연결하지 않는다 |
| `data_i` | data와 실제 사용하는 transaction·generation·index·mask 등 metadata를 묶은 packet |
| `data_o` | 마지막으로 capture한 packet. Bubble에서는 유지 |
| `valid_o` | 해당 packet의 유효 사건을 알리는 1-cycle pulse |
| `DATA_WIDTH` | 양의 packet 폭; 기본 32 |
| `GROUP_WIDTH` | CE 하나가 제어하는 data bit 수; 1~32, 기본 32 |
| `USE_XILINX_FDRE` | 기본 1: 실제 FDRE로 CE Q→CE 연결 보장. 0: portable 기능 구현 |

## Sampling edge와 처리량

| Edge | 동작 |
| --- | --- |
| E0 | `capture_i`와 `data_i`를 샘플하여 prepared packet, 그룹별 CE, pending valid를 저장 |
| E1 | 이전 CE Q로 prepared packet을 output에 저장. **Edge 이후** `data_o`·`valid_o`가 E0 packet을 표시 |
| E2 | 같은 클럭의 downstream register가 E1 이후에 표시된 output을 샘플 |

E0→E1은 한 주기의 지연이며 준비·출력 두 register 경계가 있다. II=1로 매 cycle
새 packet을 수락할 수 있다. `valid_o`는 ready/valid의 보존되는 요청이 아니다.
연속 요청은 연속 pulse이며, `capture_i=0`이면 다음 output valid가 0이고 data는 유지된다.
Reset edge에서는 이전 pending packet도 폐기된다. 별도 cancel 포트는 없다.

## 연결할 때 확인할 사항

- Bank 응답의 실제 data·valid·metadata가 정렬된 edge에서 수락 사건을 만든다.
  읽기 발행 사건을 응답 지연 없이 `capture_i`로 사용하지 않는다. 이 모듈의 지연은
  `BANK_RD_LATENCY` 이후의 별도 operand 경계로 계산한다.
- Bank·role·generation·주소·commit·준비 범위 검사와 write 안전 차단은 호출자가 유지한다.
  과거의 허용 결과가 capture 때까지 유효한지 구조 계약에 기록한다.
- Stall/ready 기능이 없으므로 발행 전에 반환 저장 공간과 outstanding credit을 예약한다.
  Downstream이 멈출 수 있으면 별도 buffer가 pulse를 포착해야 한다. 수락한 packet을 버리거나 덮어쓰지 않는다.
- Reset/cancel 및 마지막 read 이후 응답·operand·core·최종 write drain은 호출자가 설계한다.
  한 capture pulse만으로 작업 완료나 bank 해제를 결정하지 않는다.
- 기존 core 입력 register가 같은 의무를 충족하면 그 대응을 명시한다. 중복 register를 자동으로 추가하지 않는다.
- Strict backend는 실제 `unisims_ver` 라이브러리가 필요하다. Portable backend의 기능 PASS를
  실제 Q→CE 배선 보장으로 해석하지 않는다. 연결 후 최종 netlist에서 CE·data D·reset을 다시 확인한다.

Strict backend는 필요한 CE 및 출력 FDRE를 좁은 범위로 보호한다. 사용하지 않는 packet
bit도 유지하므로 필요한 field만 포함한다. 폭 W, 그룹 수 G이면 FF 예산은 `2W+G+2`다.
136-bit 예시는 G=5, 279 FF이며, 단독 utility가 전체 연결의 타이밍을 보장하지 않는다.

## 검증과 증거

```bash
python3 scripts/infrastructure_sources.py --profile registered_capture --check
python3 scripts/run_registered_capture_checks.py --help
python3 scripts/run_infrastructure_sim.py --suite leaf --out /tmp/capture-leaf-NEW \
  --vivado-bin /tools/Xilinx/2025.2/Vivado/bin
```

[구조 계약](../designs/infrastructure_registered_capture_r1/structure_contract.json)과
[kernel report](../designs/infrastructure_registered_capture_r1/kernel_report.json)에 exact source와 증거가 있다.
두 backend의 폭 1/32/33/136/438, 연속·bubble·metadata·reset을 검증했다.
136-bit 실제 example의 Vivado 2025.2 / xczu7ev-ffvc1156-2-e / 5ns post-synthesis OOC는
WNS 3.558ns, WHS 0.088ns, WPWS 2.225ns이며 실패 endpoint와 내부 검사 문제가 0이다.
CE 그룹의 실제 data load는 32/32/32/32/8이고 prepared Q→output D 136개를 대조했다.
이는 OOC 증거이며 routed timing·보드·GEMM 연결의 검증은 별도로 필요하다.
Flow와 보고서 query 실패는 [실패 기록](../designs/infrastructure_registered_capture_r1/TIMING_ISSUES.md)에 보존했다.
