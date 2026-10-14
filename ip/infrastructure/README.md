# 공통 infrastructure

현재 공통 RTL 15개의 경로·해시·의존성과 빌드 profile은
[`sources.json`](sources.json)에 있다. 원본 참조 폴더와 참조 전용 index·검사기는 삭제했다.
레퍼런스의 `mm2s_engine.sv`·`s2mm_engine.sv`와 필수 `config_pkg.sv`는
`datamover/`에 유지한다. 두 engine은 bank에 직접 연결하며 기존 FIFO·pipeline을 사용한다.
설정 package의 모델별 기본값은 새 W4A4KV4 설계의 확정 계약이 아니다.
모델별 controller·DMA·bank 연결·연산 engine은 해당 설계의 계약과 검증이 필요하다.

## 남아 있는 공통 RTL

| 폴더 | RTL 수 | 내용 |
| --- | ---: | --- |
| `bank/` | 8 | BRAM/URAM, memories, 중재, 기존 ownership/router |
| `datamover/` | 3 | 레퍼런스 MM2S/S2MM engine과 config package |
| `controller/` | 1 | 기존 controller 호환 코드 |
| `utils/` | 3 | FIFO, pipeline, registered capture |

활성 소스는 15개이며 7개 profile이 `sources.json`에 있다.
기존 별도 모듈 5개와 종속 DMA RTL 4개, 기존 작성 템플릿 6개는 활성 경로에서
삭제했다. 기존 `templates/` 폴더는 제거했다. `tb/`의 기존 테스트와 `contracts/`의 이전
계약은 호환 검증·동결 기록 확인용이다. 기존 generic channel·adapter·command queue는 활성 소스에서 제외한다.

Weight는 **여러 전송 포트로 stripe bank에 공급**한다.
포트 수·폭은 대상 하드웨어의 메모리 대역폭·계산 소비율·자원 예산에 맞춰 정한다.
포트별 stripe 연결과 결합 읽기 순서를 명시하고 필요한 stripe의 데이터 준비·전송 완료를 검증한다.
고정 4-port 구성은 요구하지 않는다. 모델별 연결은 새 revision에서 구현·검증한다.

## 새 설계에서 참조하는 방법

1. `sources.json`으로 활성 소스와 의존성을 확인한다.
2. DMA는 `datamover/mm2s_engine.sv`·`s2mm_engine.sv`의 bank 직접 연결과 FIFO·handshake·완료 처리를 읽는다.
3. Bank 모듈과 기존 controller의 실제 인터페이스·제약을 확인한다.
4. 사용할 파일마다 재사용·parameter 변경·수정·새 구현 여부와 근거를 기록한다.
5. 모델별 수정은 `designs/<new_revision>/`에 분리하고 새 구성으로 검증한다.

위 선택과 실제 연결·파이프라인·방향별 owner·Weight stripe 공급 방식은
새 revision의 `structure_contract.json`에 기록한다.
구현·검증 Agent는 같은 구조 계약을 읽고 의무별 구현 대응과 실제 RTL을 확인한다.
항목과 예시는 [구조 계약 지침](../../docs/structure_contract.md)을 따른다.

`config_pkg.sv`의 레퍼런스 모델 기본값과 기존 controller의 ISA를 새 모델의 확정 조건으로 복사하지 않는다.
활성 소스의 경로·해시·의존성과 재사용 결정을 구현·검증 Agent에 함께 전달한다.

구체적인 작성·검증 예시는 [설계 지침](../../docs/framework_workflow.md)의 1.1~1.3절을 따른다.
W4 데이터 전송, S2MM backpressure·읽기 지연, controller 응답 연결을 예로 든다.
예시의 주소·bank ID·폭·전송량은 새 모델의 확정 설정이 아니다.

각 executor의 bank 읽기는 요청 발행 → 응답 정렬 → operand register → 계산 core로 파이프라이닝한다.
`utils/pipeline.sv`로 고정 지연 제어 신호를 정렬하고 데이터·valid·metadata를 함께 전달한다.
Backpressure와 pending 응답은 별도 buffering·credit으로 처리한다.
`utils/registered_capture.sv`는 packet 준비와 등록된 CE로 operand를 포착하는 공통 경계다.
포트·E0/E1/E2 sampling·buffer 책임·FDRE/portable 선택은
[사용 지침](../../docs/registered_capture.md)과 `examples/registered_capture_example.sv`를 확인한다.
`registered_capture` profile로 해당 소스만 선택할 수 있다.
상세 기준은 [설계 지침 1.4절](../../docs/framework_workflow.md)을 따른다.

새 설계는 읽기·쓰기 소유권을 방향별로 분리한다.
`bank_ownership_table.sv`는 단일 exclusive primitive이므로 방향별 구현으로 그대로 사용할 수 없다.
모델별 bank subsystem에서 owner·engine 포트·mux·commit·memory 연결을 정의한다.
기존 JSON 계약·검사기는 호환 범위이며 새 방향별 계약의 검증을 대신하지 않는다.

## 검사와 빌드

```bash
python3 scripts/infrastructure_sources.py --check
python3 scripts/infrastructure_sources.py --profile banks --format filelist
python3 scripts/run_infrastructure_sim.py --suite all \
  --out /tmp/infrastructure-current-NEW \
  --vivado-bin /tools/Xilinx/2025.2/Vivado/bin
```

기본 공통 검증은 시뮬레이션 4건과 활성 전체 RTL 컴파일 1건이다.
소스 해시 검사와 공통 RTL 검증은 범위가 다르다.
새 모델의 수치·합성·timing·보드 검증 결과로 사용하지 않는다.

## 이전 코드의 호환 검증

삭제한 활성 파일의 원본은
[`archive/pre_reference_integrated_20261012`](archive/pre_reference_integrated_20261012/removal_manifest.json)에
정확한 바이트·해시로 보존한다. 이전 실험의 로그나 동결 계약은 다시 쓰지 않는다.
`migration.json`은 이전 경로를 같은 해시의 보존 파일로 연결한다.
과거 구조를 검증할 때만 다음과 같이 명시한다.

```bash
python3 scripts/infrastructure_sources.py --include-compatibility --check
python3 scripts/run_infrastructure_sim.py --include-compatibility --suite all \
  --out /tmp/infrastructure-compatibility-NEW \
  --vivado-bin /tools/Xilinx/2025.2/Vivado/bin
```

이전 호환 회귀에 두 capture backend를 포함하면 시뮬레이션 22건과 컴파일 1건이며 새 설계의 기본 구조가 아니다.
앞선 폴더 정리의 기록은 `archive/pre_physical_20261012/`에 별도로 남아 있다.
