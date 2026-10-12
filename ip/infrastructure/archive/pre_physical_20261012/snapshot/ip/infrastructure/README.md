# 공통 RTL 구성

이전 `SmolLM2_FPGA/pl/hdl`의 역할 구분을 따라 공통 RTL을 찾고 빌드하도록 정리했다.
현재 31개 원본 RTL의 코드·인터페이스·지연은 변경하지 않았다.

| 탐색 폴더 | 소스 수 | 역할 |
| --- | ---: | --- |
| [`rtl/bank`](rtl/bank) | 13 | BRAM/URAM, 중재, 소유권, 라우터, bank subsystem |
| [`rtl/datamover`](rtl/datamover) | 10 | 명령·상태 엔진, 큐, 채널, bank 어댑터 |
| [`rtl/controller`](rtl/controller) | 2 | sparse ISA dispatcher, native controller template |
| [`rtl/utils`](rtl/utils) | 5 | FIFO, pipeline, AXIS 폭 변환 |
| [`rtl/integration`](rtl/integration) | 1 | 기존 execution fabric 예제 |

역할 폴더의 `.sv`는 기존 패킷 `rtl/` 원본을 가리키는 상대 심볼릭 링크이다.
기존 계약·인덱스·검증 기록이 원본 경로를 사용하므로 원본 파일을 이동하지 않았다.
빌드에서는 [`sources.json`](sources.json)의 명시적인 원본 경로와 의존성을 사용한다.
탐색 링크는 소스 해시나 검증 증거의 기준 경로가 아니다.
원본과 링크를 동시에 컴파일하거나 infrastructure 전체를 재귀 glob으로 컴파일하지 않는다.

## 소스 목록과 빌드

저장소 루트에서 실행한다.

```bash
python3 scripts/infrastructure_sources.py --check
python3 scripts/infrastructure_sources.py --profile dma_integration --format filelist
python3 scripts/infrastructure_sources.py --profile native_bank_children --format tcl
python3 scripts/run_infrastructure_sim.py --suite all \
  --out /tmp/infrastructure-check-NEW \
  --vivado-bin /tools/Xilinx/2025.2/Vivado/bin
```

`--out`은 아직 없는 디렉터리여야 한다. 실행마다 원본 소스 해시, 도구 버전,
명령, 종료 코드, 소요 시간, 테스트 로그와 `result.json`을 저장한다.
`--suite leaf`는 지원 모듈·어댑터·라우터·컨트롤러 테스트와 전체 RTL 컴파일을,
`--suite integration`은 DataMover 및 기존 bank/fabric 통합 테스트를 실행한다.
테스트벤치는 기존 패킷의 것을 사용하며, native controller 검사용 파생 파일은
해당 실행 디렉터리에만 생성한다. 합성·배치배선은 이 명령의 범위에 포함하지 않는다.

| profile | 선택 범위 |
| --- | --- |
| `adapters`, `support`, `command_queue`, `engine` | DataMover의 개별 공통 모듈 |
| `dma_integration` | engine + enable/address 어댑터 + 중재 + XPM BRAM |
| `stream_adapters` | 별도 valid/ready bank 어댑터 |
| `ownership`, `port_router`, `sparse_router` | 기존 exclusive-owner 구성 |
| `dispatcher`, `controller` | 기존 dispatcher / native v4 controller |
| `native_bank_children` | 방향별 ownership/router/memory 자식 모듈 |
| `legacy_bank`, `legacy_fabric` | 기존 고정 bank/fabric 예제 |
| `all` | 31개 RTL의 컴파일 목록; 통합 top 선택용이 아님 |

의존성은 중복 없이 먼저 배치한다. 패키지는 사용하는 모듈보다 먼저 나온다.
소스 해시 변경, 잘못된 원본 경로, 중복 정의, 의존성 순환, 깨진 탐색 링크는 실패한다.
RTL을 의도적으로 수정하면 새 실행의 소스 목록과 증거를 함께 갱신해야 한다.
과거 실행의 계약·해시·로그는 현재 파일에 맞춰 덮어쓰지 않는다.

## 구성별 경계

- `mm2s_adapter`/`s2mm_adapter`는 파라미터형 enable/address bank 인터페이스이다.
  `mm2s_stream_bank_adapter`/`s2mm_stream_bank_adapter`는 고정 폭 valid/ready 인터페이스이다.
  두 종류의 어댑터를 서로 대체하지 않았다.
- 기존 `bank_subsystem`은 exclusive-owner 예제이다. native 자식 모듈과
  [`bank_subsystem_template`](bank_subsystem_template/README.md)은 읽기·쓰기 소유권을 구분한다.
  `native_bank_children`에는 설계별 생성 package/top을 추가해야 한다.
- `.sv.tpl`, TB, lint stub, `evidence/`의 캡처 소스는 공통 합성 소스 목록에서 제외한다.
  기존 패킷의 실행 스크립트와 생성 경로는 계속 사용할 수 있다.
- 이전 HDL의 모델 ISA·config에 의존하는 controller/DMA를 그대로 복사하지 않았다.
  현재 `pipeline.sv`도 이전 파일로 되돌리지 않았다.
- Smol W4A4KV4의 striped weight bank는 `designs/smollm2_135m_w4a4kv4_zcu104_r1`에 있다.
  공통 라이브러리로 승격하거나 기존 bank를 대체하지 않았다. 해당 모듈의 hold timing과
  DMA 연결 제한은 기존 보고서에 남아 있다.

이번 정리는 코드 조직과 빌드 경로에 관한 작업이다. 과거 라우터·합성·timing 보고서는
각각 기록된 소스 해시에 대한 결과이며, 현재 작업 트리의 정확성이나 timing 결과로
자동 재사용하지 않는다.

2026-10-12 검증에서 새 진입점은 자기검증 시뮬레이션 25건과 전체 RTL 컴파일 1건을
모두 통과했다. 기존/새 경로의 공통 15개 테스트 결과도 일치했다.
자세한 기록은 [정리 결과 보고서](evidence/cleanup_20261012_001/REPORT_KO.md)에 있다.
