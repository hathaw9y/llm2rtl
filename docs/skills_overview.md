# Skills 공통 계약과 운영 규칙

각 Skill의 상세 입력·처리 절차·산출물·완료 기준은
[개별 Skill 명세 목차](skills_specification.md)에서 확인한다.
이 문서는 공통 역할·계약·상태·Evidence와 현재 연결상의 유의점을 보존한다.

- 기준일: 2026-09-08
- 대상: 현재 저장소 `skills/`에 포함된 24개 `SKILL.md`
- 목적: 프레임워크를 실행하는 LLM의 역할, Skill 선택, 입력·산출물, 검증과 인계 조건 정의
- 범위: 현재 지침을 설명하는 명세. 실제 모델 구현·합성·보드 검증 완료를 증명하는 보고서는 아니다.

## 1. Skills의 실행 의미

Skill은 LLM이 읽고 적용하는 작업 지침이다. 그 자체가 RTL 생성 함수,
자동 검사 프로그램 또는 독립 실행 에이전트는 아니다. LLM이 입력 명세와
관련 Skills를 해석해 설계 결정을 내리고 코드를 작성하며 도구를 실행한다.

한 작업에는 역할 Skill, 전문 설계 Skill, RTL·도구 Skill을 함께 적용할 수
있다. 여러 Skill 적용과 여러 에이전트의 병렬 실행은 별개의 개념이다.
전문 Skills는 해당 설계 문제에 필요한 것만 선택한다.

프로젝트 Skill의 원본은 `skills/<name>/SKILL.md`이다. 실행 환경에는
`~/.codex/skills/`에 동기화된 사본을 사용한다. `agents/openai.yaml`은
있는 경우 UI 이름·설명·호출 예시를 제공하며 설계 계약을 대신하지 않는다.
지침의 참조 문서·스크립트는 해당 Skill이 지정한 작업에서 사용한다.

## 2. 역할과 책임

| 주체 | 소유하는 작업 | 책임 경계 |
|---|---|---|
| 부모 LLM | 입력 해석, 설계 선택, 모듈 패킷, 작업 배정, 상태·재시도·진행 판단 | RTL을 직접 작성하지 않는다. |
| 구현 하위 에이전트 | 배정된 모듈 코드, 테스트, 자체 검증 | 부모 상태나 독립 감사 결과를 수정하지 않는다. |
| 독립 검증 하위 에이전트 | 요구사항·소스·실행 증거 감사 | RTL·테스트·계약을 직접 고쳐 통과시키지 않는다. |
| 통합 하위 에이전트 | 검증된 자식 연결, FSM·어댑터·버퍼 | 자식 구현을 임의로 변경하거나 검증 범위를 확대하지 않는다. |
| 보드 담당 에이전트 | 보드 구성, 제약, 빌드·산출물 검증 | 부분 구성의 빌드 성공을 전체 모델 완료로 바꾸지 않는다. |
| 사용자 | 실제 FPGA 적재·실행·결과 전달 | 실물 검증 결과 전에는 해당 체크포인트가 완료되지 않는다. |

## 3. 공통 입력과 계약

모델의 연산 그래프·차원·가중치 layout, 수치 정책, 실행 범위와 FPGA의
정확한 part·자원·클럭·메모리·호스트 인터페이스가 설계 입력이다.
FPGA 전체 용량과 현재 모듈 또는 프로젝트 예산을 구분한다.
불명확한 조건이 모듈 경계나 검증 기준을 바꾸면 부모가 확인한다.

작업 패킷은 기능, 작업 범위, 인터페이스, 수치·메모리·cycle 계약,
자원·성능 목표, 허용 파라미터, 의존성, 필수 검증과 완료 범위를 전달한다.
전문 Skill은 선택 방법을 제공하고, 이번 설계의 구체적 값은 패킷에 기록한다.

이 저장소의 공통 경계는 다음 문서를 따른다.

| 경계 | 프로젝트 계약 |
|---|---|
| 요청·완료·해제 | [공통 HDL 인터페이스](hdl_module_interface_contract.md) |
| 타일·DDR·로컬 주소 책임 | [address_ownership.json](../contracts/address_ownership.json) |
| 스케줄러의 실제 반복·제어 책임 | [model_scheduler_role.json](../contracts/model_scheduler_role.json) |
| 로컬 메모리 읽기 지연 | [native_memory_timing.json](../contracts/native_memory_timing.json) |
| 메모리 분류·소유권 | [memory_ownership.json](../contracts/memory_ownership.json) |
| 별도 IP 셀로 구성할 역할 | [block_design_layout.json](../contracts/block_design_layout.json) |

DDR↔로컬 메모리 이동은 제공 DataMover Engine과 vendor AXI DataMover·adapter를 사용한다. 연산 IP는
로컬 메모리에 접근하고 스케줄러가 반복·뱅크·필요한 전송을 제어한다.
상주·스트리밍 선택과 상주 범위는 메모리 계획에 명시하며, 스케줄러 소유를
매 타일 DDR 재적재로 해석하지 않는다.

새 작업 제어는 `start` 유지 → `done` 확인 → `start` 해제 → `done` 해제
확인 순서다. `busy`는 선택 상태다. 기존 pulse 방식 IP의 계약·RTL·증거를
문서만 바꿔 호환 처리하지 않고, 검증된 어댑터 또는 RTL 변경으로 연결한다.

## 4. Skill 목록과 개별 명세

각 항목의 링크는 실제 지침 원본이다. 아래 산출물은 해당 작업의 범위에
맞게 생성하며, 문서에 파일명이 있다는 이유만으로 기존 파일 존재를 뜻하지 않는다.

### 4.1 부모 조율과 점진적 확장 — 3개

| Skill / 적용 조건 | 입력 | 처리·출력 | 진행 조건 및 인계 |
|---|---|---|---|
| [multi-agent-hdl-generation](../skills/multi-agent-hdl-generation/SKILL.md) — 모델→HDL 작업 조율 | 사용자 목표, 모델·하드웨어 명세, 현재 작업 상태 | 역할별 Skill 라우팅, 하위 에이전트 배정, 의존 wave, 부모 feedback·retry·spawn ledger 관리 | 의존 검증 통과 후 다음 wave. 누락된 역할 Skill은 생성·검증·동기화 후 배정. |
| [parent-module-decomposition](../skills/parent-module-decomposition/SKILL.md) — 입력 해석·아키텍처·모듈 경계 정의 | 모델 코드·config·수치 정책·보드·방법론 | `model_graph.json`, 필수 `module_mapping.json`, compute/execution/memory/control 4축, 계약 트리, 모듈 패킷 | 계획 참조와 의미를 검토한 뒤 계약 작성. 입력 불명확 시 확인. 통합 전 자식 경계·현재 OOC·실제 지원 범위를 검토. |
| [fpga-incremental-bringup](../skills/fpga-incremental-bringup/SKILL.md) — 최소 가속기부터 누적 확장 | 검토된 `model_graph.json`·`module_mapping.json`, 전체 목표, 보드·수치 명세, 이전 통과 구성 | 매핑을 경로·해시로 참조하는 `bringup.json`, 단계별 coverage·회귀·자원 계획, 기준 버전 보존 | 계획/계약 gate와 이번 누적 구성의 도구 검증·보드 빌드·사용자 실물 확인 후 다음 의존 단계 진행. |

부모는 특정 모델에 무관하게 GEMM을 무조건 첫 모듈로 고정하지 않는다.
첫 단계는 실제 입력→연산→출력 검증이 가능한 최소 구성으로 선정한다.
매핑을 구성·검토한 뒤 사용자에게 요약과 정확한 파일·해시를 제시하고
`awaiting_user_mapping_approval`에서 기다린다. Parent 자체 검토는 사용자 승인이
아니며, 별도 `module_mapping_approval.json`에 실제 결정을 기록하기 전에는 bring-up
초안 생성·구현 계약 freeze·구현 배정을 하지 않는다. 승인 후 `--before-bringup`을
통과해야 계획을 처음 생성한다. 승인 후 매핑 변경은 다시 확인받는다.
재귀 분해는 구현 패킷의 허용 정책에 따르며 독립 검증 역할에 자동 전파하지 않는다.

### 4.2 구현·검증·통합 — 8개

| Skill / 적용 조건 | 입력 | 처리·출력 | 진행 조건 및 인계 |
|---|---|---|---|
| [hdl-module-implementation](../skills/hdl-module-implementation/SKILL.md) — 하나의 제한된 모듈 구현 | 모듈 패킷·계약·수정 범위 | RTL, golden, TB, 실행 로그, `kernel_report.json`, `subagent_result.json`, 실제 데이터패스 OOC 보고서 | 자체 검증 후 독립 module verification에 인계. 계약 약화·타 역할 파일 수정 금지. |
| [hdl-module-verification](../skills/hdl-module-verification/SKILL.md) — 독립 모듈 감사 | 정확한 DUT·소스 해시·파라미터, 계약, TB·golden·raw log·OOC | 요구사항별 증거 연결, source closure·수치·프로토콜·자원 감사, `module_verification_report.json` | `passed/failed/blocked`, findings·promotion eligibility. 증거 누락은 통과가 아니다. |
| [hdl-integration-agent](../skills/hdl-integration-agent/SKILL.md) — 검증된 자식의 누적·계층 통합 | 통과한 자식 계약·해시·설정·검증 범위 | 부모 FSM, 허용된 어댑터·버퍼·라우팅, 통합 RTL·TB·golden, 자식 식별 기록 | 실제 자식 자체 테스트 통과 후 독립 통합 감사. 자식 변경 시 관련 검증 갱신. |
| [hdl-integration-verification](../skills/hdl-integration-verification/SKILL.md) — 독립 통합 감사 | 통합 소스·테스트·자식 결과·하드웨어 명세 | 동적 호출·payload·metadata·반복·stall 확인, `integration_verification_report.json`, `integration_synthesis_report.json` | 자식 OOC만으로 통합 합성을 대체하지 않는다. 계약에서 route가 필요하면 routed 증거 요구. |
| [hdl-generation-verification](../skills/hdl-generation-verification/SKILL.md) — 보드 통합 전 재사용 HDL의 포괄적 생성·검증 | 기능·수치·cycle·메모리 계약과 source roots | 계약 기반 재사용, transitive source closure, 단위→경계→실제 이웃 연동 테스트, 재사용 가능한 integration packet | 보드 배포 판정은 하지 않는다. 역할 분리 흐름에서는 이 포괄 지침이 독립 감사를 대체하지 않는다. |
| [hdl-kernel-contract-gates](../skills/hdl-kernel-contract-gates/SKILL.md) — 커널의 조합 가능성·주장 범위 검사 | 커널 계약·RTL·검증 결과 | 공통 포트·packing·클럭·수치·실제 payload·report 필드와 실패 패턴 검사 | scaffold/fixture/target을 구분. sim-only 또는 누락된 필수 증거로 상위 통합 승격 금지. |
| [fpga-systemverilog](../skills/fpga-systemverilog/SKILL.md) — RTL·TB 작성/정적 검토 | 기능·인터페이스·리셋·지연·수치 계약 | 명시적 폭·signedness, sequential/combinational 규칙, valid/ready, 메모리와 self-checking TB, static review | 코드 검토만으로 합성·타이밍·DSP/BRAM 결과를 주장하지 않는다. 도구 작업은 fpga-vivado와 조합. |
| [hdl-vivado-timing-closure](../skills/hdl-vivado-timing-closure/SKILL.md) — 타이밍 실패 분석·수정 경로 | 현재 source/top/part/clock의 timing report, 허용 tuning | setup·hold·pulse-width 분리 판정, 단계 식별, 파이프라인·fanout·물리 문제의 담당자 재배정 | 실제 목표 클럭·slack·실패 endpoint를 확인. 독립 감사자는 진단하고 구현 담당자가 수정. |

`hdl-generation-verification`은 범용 모듈 작업 절차이고,
`hdl-module-implementation`과 `hdl-module-verification`은 구현·독립 감사를
분리하는 역할 지침이다. 같은 의미의 보고서를 불필요하게 복제하기보다
패킷에서 필요한 파일과 역할을 지정한다. 구현 에이전트의 자체 검증은
독립 검증 완료와 구분한다.

### 4.3 전문 아키텍처·수치·메모리 설계 — 8개

| Skill / 적용 조건 | 입력 | 처리·출력 | 핵심 판정 |
|---|---|---|---|
| [fpga-2d-systolic-array](../skills/fpga-2d-systolic-array/SKILL.md) — GEMM/GEMV·attention 배열 | 행렬 shape, prefill/decode, 정밀도·대역폭·용량 | baseline/대안 비교, PE 형태·stationary 정책, fill/drain·tail·전송 cycle, tensor layout·인터페이스 | peak TOPS보다 실제 활용률. fusion은 producer/consumer 순서·Softmax 상태·buffer 증명 필요. |
| [fpga-dsp-packing](../skills/fpga-dsp-packing/SKILL.md) — DSP 내부 복수 저정밀 연산 | 정확한 DSP 세대·폭·signedness·누산 길이 | field 배치·부호 보정·guard·추출 증명, 급지·merge 비용, bit-exact 테스트와 mapping 증거 | 곱만이 아닌 누산 carry까지 검증. 보정·라우팅·클럭 비용 후 유효 이득 비교. |
| [fpga-adder-tree](../skills/fpga-adder-tree/SKILL.md) — reduction·부분합 | 피연산자·최대 reduction·정밀도·목표 cycle | balanced/cascade/segmented/folded 비교, 폭·overflow 증명, pipeline·II·metadata 정렬 | 극값·tail·stall·flush 검증. wrap은 명시적 modular 계약에서만 허용. |
| [fpga-quantization](../skills/fpga-quantization/SKILL.md) — tensor 수치 형식과 변환 | tensor·scale·zero-point·calibration·품질 예산 | 형식 표, quant/dequant/requant 방정식, 누산·오차·메모리 비용, bit-exact reference·모델 품질 기준 | W4A8 같은 라벨만으로 계약 불충분. metadata·변환 비용과 정밀도 경계 포함. |
| [fpga-ddr-pingpong-residency](../skills/fpga-ddr-pingpong-residency/SKILL.md) — 상주·축소 타일·ping-pong 선택 | packed tensor bytes·수명·재사용, 용량, 실측 대역폭·전송 지연·compute 시간 | capacity/overlap 계산, resident/reduced/pingpong/measure 판단, bank 소유권·stream 계약 | duplicate buffer·scale·정렬 포함. active bank 덮어쓰기 금지. 실측 누락을 overlap 통과로 처리하지 않음. |
| [fpga-softmax](../skills/fpga-softmax/SKILL.md) — stable/online/fused/approximate Softmax | row 길이·mask·scale·정밀도·허용 오차·생산 순서 | pass 또는 running-state recurrence, max/sum/V 재스케일, LUT·reciprocal·저장·오차·테스트 | 타일별 독립 정규화 금지. all-masked·tail·running max 변화와 실제 모델 품질 확인. |
| [fpga-layernorm-gelu](../skills/fpga-layernorm-gelu/SKILL.md) — LayerNorm·GELU·공유 nonlinear 경로 | axis·길이·epsilon·gamma/beta·domain·입출력 정밀도 | two-pass/Welford 등과 LUT/PWL 비교, replay·buffer·폭·오차·rate matching | 분산 cancellation·근사 domain·경계 검증. RMSNorm·SiLU에는 해당 연산 계약을 별도로 확인. |
| [fpga-pruning](../skills/fpga-pruning/SKILL.md) — sparse 실행 선택 | pruning 대상·density·품질·실행 모드 | dense 대비 sparse format·index·selector·lane·비용·품질·schedule 비교 | metadata·padding·selection·낮아진 클럭까지 포함한 실제 절감. 논리 token/head identity 보존. |

논문 수치, 계산 결과, 측정 결과와 가정은 구분한다. 전문 Skill의 후보
비교는 설계 판단 자료이며 최종 선택한 값과 근거는 해당 모델 계약에 남긴다.
보드나 특정 예제의 PE 크기를 다른 설계의 고정값으로 전파하지 않는다.

### 4.4 도구·보드·사용자 실물 검증 — 5개

| Skill / 적용 조건 | 입력 | 처리·출력 | 책임 경계 |
|---|---|---|---|
| [fpga-vivado](../skills/fpga-vivado/SKILL.md) — XSIM·합성·구현·IP·Tcl | tool version, part/top, sources, XDC, IP dependencies, 요청 단계 | compile/elaborate/sim/synth/route 실행과 원시 로그·timing·utilization·DRC·clock | 실제 실행·버전·단계를 기록. compile, sim, synth, route, board runtime을 혼동하지 않음. |
| [hdl-board-wrapper-signoff](../skills/hdl-board-wrapper-signoff/SKILL.md) — 보드 경계 구성·감사 | 검증된 통합, 보드 profile·주소·clock/reset·XDC·BD 정책 | 별도 셀의 PS/PL·Fabric·mover·compute·memory 연결, 정확한 routed wrapper의 `board_wrapper_report.json` | 구현과 독립 감사 결과 구분. matched deployment artifact 최종 판정은 다음 Skill로 인계. |
| [fpga-board-build-signoff](../skills/fpga-board-build-signoff/SKILL.md) — 재현 가능한 빌드·패키징 | 검증 소스·설정·정확한 보드·도구·resource/timing 기준 | readiness, fresh run, stage별 report 검사, BIT/HWH/XSA 일치, manifest·분류·게시 | 이전 build의 증거 상속 금지. 실패 run 보존, production/diagnostic 구분. 실물 실행 통과를 뜻하지 않음. |
| [zcu104-xczu7ev-hardware](../skills/zcu104-xczu7ev-hardware/SKILL.md) — ZCU104 대상 작업 | xczu7ev-ffvc1156-2-e, 실제 설정·예산·clock·memory | 장치 inventory, PS/PL/DDR 조건, 목표 clock·실제 runtime clock·DRC·증거 기준 | 다른 보드에 적용하지 않는다. 특정 WS32 DSP floor는 Skill의 조건부 구성에 한정. |
| [fpga-hardware-validation](../skills/fpga-hardware-validation/SKILL.md) — 사용자 보드 테스트 인계·결과 해석 | 정확한 stage/build, matched artifacts, driver·memory map, golden·오차 기준 | `hardware_test_handoff.md`, 입력·script/notebook·golden·timeout·결과 수집, `hardware_validation_report.json` | 사용자만 보드 적재·실행. 원시 결과 검토와 사용자 진술을 구분. 부모가 단계 acceptance 결정. |

빌드 Skill의 원자적 산출물 게시와 하드웨어 Skill의 사용자 FPGA 실행은
별개의 작업이다. 파일 생성 성공이나 다운로드 성공만으로 연산의 정확성을
판정하지 않는다. 실물 검증은 실제 DataMover Engine 경로와 payload 비교,
반복 실행 및 현재 단계의 회귀를 대상으로 한다.

## 5. 단계별 Skill 조합과 제어 흐름

| 단계 | 기본 Skill | 조건부 추가 | 다음 단계에 넘기는 것 |
|---|---|---|---|
| 입력·구조 분석 | multi-agent-hdl-generation + parent-module-decomposition | hardware profile, 필요한 전문 설계 Skills | model_graph.json, 필수 module_mapping.json |
| 핵심 선정·확장 계획 | fpga-incremental-bringup | 전문 설계 Skills | 매핑을 참조하는 bringup.json, 계획 검사 후 단계별 계약·체크포인트 |
| 이번 단계 모듈 구현 | hdl-module-implementation | systemverilog, kernel gates, vivado, 해당 전문 Skills | 코드와 자체 검증 증거 |
| 독립 모듈 감사 | hdl-module-verification | systemverilog, kernel gates, vivado, timing 진단 | 승격 가능 여부와 findings |
| 누적 통합 | hdl-integration-agent | systemverilog, kernel gates, vivado | 실제 자식이 연결된 통합 구성 |
| 독립 통합 감사 | hdl-integration-verification | systemverilog, kernel gates, vivado, timing closure | 현재 소스의 통합 검증 결과 |
| 보드 구성·빌드 | hdl-board-wrapper-signoff → fpga-board-build-signoff | hardware profile, systemverilog, vivado, timing closure | 현재 단계 범위의 matched artifacts |
| 사용자 테스트 | fpga-hardware-validation | hardware profile | 정확한 빌드에 대한 사용자 결과·분석 |
| 단계 수락·반복 | fpga-incremental-bringup + 부모 router | 실패 소유자 Skill | 기준 버전 보존 또는 수정·재검증 |

```text
모델 + FPGA + 실행/수치 조건
  → 부모: model_graph → module_mapping → 사용자 승인 대기·기록
  → 생성 전 승인 gate → bringup 생성·검토 → 계획·승인 검사 → 단계별 계약
  → 이번 단계 코드 생성 → 독립 검증 → 누적 통합 → 독립 검증
  → 현재 단계 보드 빌드 → 사용자 테스트 인계
  → 사용자 결과 대기
      ├─ 통과: 기준 버전 보존 → 다음 모듈 추가
      ├─ 실패: 담당 구현/통합/빌드로 반환 → 새 빌드·재검증
      └─ 불완전: 결과 확인, 의존 단계 진행 보류
```

작업별 독립 모듈 구현은 의존성이 없고 부모 정책이 허용하면 병렬화할 수 있다.
사용자 검증 전 다음 누적 단계로의 의존 구현은 진행하지 않는다.
부분 단계의 보드 빌드는 허용되지만 전체 모델용 child readiness와 최종
coverage 요건을 면제하지 않는다.

## 6. 산출물과 Evidence 계약

Evidence는 독립적인 마지막 단계가 아니라 각 작업에서 남기는 증거다.
모든 pass는 source/configuration, top, part, clock, tool/run, coverage를
식별해야 한다. 현재 산출물의 해시가 달라지면 영향을 받는 검증을 갱신한다.

| 산출물 | 작성 주체 | 핵심 내용 |
|---|---|---|
| module/interface/memory 계약 | 부모·명시적으로 허용된 분해 에이전트 | 기능, 포트·cycle·수치, 소유권, 변경 범위, 검증 |
| kernel_report.json | 구현 담당 | 실제 구현·실행 결과, scope·누락·위험 |
| subagent_result.json | 하위 담당 | 변경 파일, 명령, 증거, 실패·재시도 제안 |
| module_ooc_synthesis_report.json | 구현/지정된 도구 담당 | 현재 real datapath의 OOC·자원·timing 단계 |
| module_verification_report.json | 독립 검증 | passed/failed/blocked, findings, promotion eligibility |
| integration_verification_report.json | 독립 통합 검증 | 자식 identity, 동적 연결, payload·회귀, 결과 |
| integration_synthesis_report.json | 통합 검증 | 통합 top의 synth/요구된 implementation 증거 |
| board_wrapper_report.json | 보드 구성/감사 담당 | BD·clock/reset·주소·DDR·route 및 범위 |
| hardware_test_handoff.md | 사용자 테스트 인계 담당 | artifact·환경·실행법·입력·golden·반환 자료 |
| hardware_validation_report.json | 사용자 결과 분석 담당 | build/test identity, 사용자 결과, 실제 비교·제한 |
| parent_loop_state/feedback_packet/retry_plan | 부모 | 현재 단계, 작업 배정, 결과, 재시도·차단 조건 |
| hdl_subagent_spawn_ledger.json | 부모 | 에이전트 배정·증거 추적 |

동등한 기존 파일 경로는 패킷에서 명시해 사용할 수 있다. 보고서 형식이
같다는 이유로 다른 소스나 다른 실행의 결과를 합쳐 하나의 pass로 만들지 않는다.

## 7. 상태 전이와 사용자 체크포인트

누적 단계의 상태는 `planned → implementing → tool_verification → building
→ awaiting_user_hardware_validation → accepted`로 관리하며 실패·환경 문제는
`failed` 또는 `blocked`로 기록한다. 세부 상태의 소유자는 부모다.

사용자 테스트 보고서는 대기 후 `passed`, `failed`, `incomplete`로 분류한다.
`passed` 결과와 필수 확인 조건이 충족되면 부모가 단계를 `accepted`로 바꾼다.

- `user_attestation`: 사용자가 정확한 빌드의 필수 테스트 통과를 확인했지만 원시 출력은 검토하지 않은 경우.
- `user_run_with_reviewed_outputs`: 사용자가 실행한 원시 출력을 실제로 비교한 경우.

패킷이 원시 증거를 요구하면 사용자 진술만으로 해당 조건을 충족시키지 않는다.
침묵·시간 경과·bitstream 생성·시뮬레이션 통과는 실물 확인을 대신하지 않는다.
사용자가 실행하는 절차이므로 LLM이 보드에 접속하거나 적재·리셋·실행하지 않는다.

## 8. 실패 처리와 Skill 유지보수

| 실패 분류 | 반환 대상 |
|---|---|
| 기능·수치·커널 프로토콜 | 해당 구현 담당 → hdl-module-verification |
| 부모 FSM·연결·adapter·memory 공유 | hdl-integration-agent → 독립 통합 검증 |
| setup/hold/pulse-width·fanout·congestion | hdl-vivado-timing-closure + 해당 구현/보드 담당 |
| source·IP·BIT/HWH/XSA 불일치 | 보드 구성 또는 fpga-board-build-signoff |
| 실물 결과의 build/입력 식별 불명확 | fpga-hardware-validation이 자료 확인 |
| 도구·필수 입력 누락 | 부모가 blocked 원인과 다음 행동 기록 |

재시도는 이전 통과 버전과 실패 증거를 보존하며 새로운 소스·build identity로
수행한다. 검증 담당은 기대값·허용 오차를 완화해 문제를 감추지 않는다.
설계별 수정은 모델/모듈 계약에 남기고 일반화 가능한 교훈만
`skill_update_candidate`로 부모에게 제안한다.

`skill-creator`는 역할 Skill 생성·수정·형식 검증에 사용하는 외부 시스템
Skill이며 프로젝트의 24개 목록에는 포함하지 않는다. 부모는 변경된 프로젝트
사본을 검증하고 실행 환경에 동기화한다. 버전이 다른 지침을 사용한 실행은
같은 설계 규칙을 적용했다고 자동 간주하지 않는다.

## 9. 지원 자료와 현재 연결상의 유의점

### 9.1 실제 제공되는 지원 자료

| Skill | 지원 자료 | 사용 시점 |
|---|---|---|
| fpga-ddr-pingpong-residency | [capacity_overlap.py](../skills/fpga-ddr-pingpong-residency/scripts/capacity_overlap.py), [test_capacity_overlap.py](../skills/fpga-ddr-pingpong-residency/scripts/test_capacity_overlap.py), [메모리 계약](../skills/fpga-ddr-pingpong-residency/references/contracts.md) | 용량·중첩 계산과 bank/stream 계약 |
| hdl-generation-verification | [verification-matrix.md](../skills/hdl-generation-verification/references/verification-matrix.md) | 테스트 계획·완료 범위 결정 |
| fpga-board-build-signoff | [failure-patterns.md](../skills/fpga-board-build-signoff/references/failure-patterns.md) | production packet 확정·실패 recovery 설계 |

### 9.2 명세가 구현 완료를 뜻하지 않는 부분

다음은 현재 지침·저장소를 읽을 때 구분해야 하는 사항이다.

1. 제공되지 않는 에이전트 runner 명령은 부모·timing Skills에서 제거했다.
   부모는 사용 환경의 에이전트 도구로 작업을 배정하고, timing 검증은 확정된
   모듈 packet에 명시된 실제 스크립트를 사용한다. 저장소의
   `scripts/design_contracts.py`는 계약 처리, `scripts/sync_project_skills.py`는
   Skill 동기화 도구이며 전체 E2E 실행기가 아니다.
2. 공통 프로젝트 handshake는 변경됐지만 기존 RTL은 자동 변경되지 않았다.
   재사용 시 개별 인터페이스와 현재 소스를 확인해야 한다.
3. 기존 variant 검사기의 GEMM 전체 차원·전역 주소 소유 조건은 현재
   스케줄러 원칙과 불일치한다. 본 명세는 해당 Python 검사기가 정리됐다는
   의미가 아니다.
4. DDR residency Skill에는 mover가 DDR 주소를 소유한다는 포괄 표현이 있다.
   프로젝트에서는 스케줄러의 타일별 주소 결정과 mover가 직접 구동하는
   beat/word 진행을 구분하므로 역할 패킷에 이 경계를 명시해야 한다.
5. 새 누적 bring-up 경로는 부분 단계의 bitstream을 허용한다. 기존 부모
   workflow의 full-target gate는 최종 모델 주장에 적용하며, 부분 단계의
   coverage를 전체 모델로 승격하는 근거로 사용하지 않는다.
6. Vivado Skill의 기본 버전은 2024.1이고 하드웨어 profile에는 실제 확인한
   다른 버전도 기록될 수 있다. 실행 패킷의 버전과 실제 도구·보고서를
   확인해야 하며 서로 다른 버전의 증거를 합치지 않는다.

이 문서의 역할·진행 조건은 Skill을 찾고 조합하는 기준이다. 세부 작업은
링크된 실제 Skill과 활성 프로젝트 계약을 함께 읽고 수행한다. 이후 Skills가
변경되면 이 목록·연계·입출력·유의점도 함께 갱신한다.
