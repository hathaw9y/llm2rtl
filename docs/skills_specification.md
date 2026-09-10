# 개별 Skill 명세서

기준일: 2026-09-08. 현재 프로젝트 `skills/`의 24개 Skill을 각각 독립 문서로 명세한다.

각 문서는 목적·적용 조건, 입력·선행 조건, 상세 처리 절차, 산출물,
완료·검증 기준, 책임 경계·실패 처리, 연계 Skills, 적용 예시와 유의점을 포함한다.
원본 Skill의 실행 지침을 설명하는 문서이며 Skill 수정이나 실제 보드 검증 결과가 아니다.
시스템 `skill-creator`는 외부 의존성이므로 프로젝트 24개 목록에 포함하지 않는다.

- [프레임워크 전체 실행 방식](../README.md)
- [공통 계약·상태·Evidence 및 기존 유의점](skills_overview.md)
- [공통 HDL 인터페이스 계약](hdl_module_interface_contract.md)

## 부모 조율과 사용자 검증

| 개별 명세서 | 담당 기능 | 원본 |
|---|---|---|
| [multi-agent-hdl-generation](skills/multi-agent-hdl-generation.md) | 부모 에이전트의 작업 조율 | [SKILL.md](../skills/multi-agent-hdl-generation/SKILL.md) |
| [parent-module-decomposition](skills/parent-module-decomposition.md) | 입력 해석과 모듈 계약 분해 | [SKILL.md](../skills/parent-module-decomposition/SKILL.md) |
| [fpga-incremental-bringup](skills/fpga-incremental-bringup.md) | 핵심 구성부터 누적 확장 | [SKILL.md](../skills/fpga-incremental-bringup/SKILL.md) |
| [fpga-hardware-validation](skills/fpga-hardware-validation.md) | 사용자 FPGA 테스트 인계와 결과 분석 | [SKILL.md](../skills/fpga-hardware-validation/SKILL.md) |

## 모듈 구현·검증·통합

| 개별 명세서 | 담당 기능 | 원본 |
|---|---|---|
| [hdl-module-implementation](skills/hdl-module-implementation.md) | 제한된 HDL 모듈 구현 | [SKILL.md](../skills/hdl-module-implementation/SKILL.md) |
| [hdl-module-verification](skills/hdl-module-verification.md) | 독립 모듈 감사 | [SKILL.md](../skills/hdl-module-verification/SKILL.md) |
| [hdl-integration-agent](skills/hdl-integration-agent.md) | 검증된 자식의 통합 구현 | [SKILL.md](../skills/hdl-integration-agent/SKILL.md) |
| [hdl-integration-verification](skills/hdl-integration-verification.md) | 독립 통합 감사 | [SKILL.md](../skills/hdl-integration-verification/SKILL.md) |
| [hdl-generation-verification](skills/hdl-generation-verification.md) | 재사용 HDL 생성·검증의 포괄 절차 | [SKILL.md](../skills/hdl-generation-verification/SKILL.md) |
| [hdl-kernel-contract-gates](skills/hdl-kernel-contract-gates.md) | 조합 가능한 커널의 검증 기준 | [SKILL.md](../skills/hdl-kernel-contract-gates/SKILL.md) |

## 전문 설계

| 개별 명세서 | 담당 기능 | 원본 |
|---|---|---|
| [fpga-2d-systolic-array](skills/fpga-2d-systolic-array.md) | 2차원 배열과 데이터플로 설계 | [SKILL.md](../skills/fpga-2d-systolic-array/SKILL.md) |
| [fpga-dsp-packing](skills/fpga-dsp-packing.md) | DSP 필드 packing과 cascade | [SKILL.md](../skills/fpga-dsp-packing/SKILL.md) |
| [fpga-adder-tree](skills/fpga-adder-tree.md) | 축약 네트워크의 폭과 pipeline | [SKILL.md](../skills/fpga-adder-tree/SKILL.md) |
| [fpga-quantization](skills/fpga-quantization.md) | 수치 형식과 tensor 변환 계약 | [SKILL.md](../skills/fpga-quantization/SKILL.md) |
| [fpga-ddr-pingpong-residency](skills/fpga-ddr-pingpong-residency.md) | 상주·타일 축소·이중 버퍼 결정 | [SKILL.md](../skills/fpga-ddr-pingpong-residency/SKILL.md) |
| [fpga-softmax](skills/fpga-softmax.md) | 안정적 Softmax와 fused attention 정규화 | [SKILL.md](../skills/fpga-softmax/SKILL.md) |
| [fpga-layernorm-gelu](skills/fpga-layernorm-gelu.md) | 정규화와 비선형 vector pipeline | [SKILL.md](../skills/fpga-layernorm-gelu/SKILL.md) |
| [fpga-pruning](skills/fpga-pruning.md) | 희소 정책·형식·실행 비용 | [SKILL.md](../skills/fpga-pruning/SKILL.md) |

## RTL·도구·보드

| 개별 명세서 | 담당 기능 | 원본 |
|---|---|---|
| [fpga-systemverilog](skills/fpga-systemverilog.md) | SystemVerilog RTL·테스트벤치 작성 규칙 | [SKILL.md](../skills/fpga-systemverilog/SKILL.md) |
| [fpga-vivado](skills/fpga-vivado.md) | Vivado 실행과 도구 증거 | [SKILL.md](../skills/fpga-vivado/SKILL.md) |
| [hdl-vivado-timing-closure](skills/hdl-vivado-timing-closure.md) | setup·hold·pulse-width 진단과 수정 루프 | [SKILL.md](../skills/hdl-vivado-timing-closure/SKILL.md) |
| [hdl-board-wrapper-signoff](skills/hdl-board-wrapper-signoff.md) | 보드 wrapper와 Block Design 구성·감사 | [SKILL.md](../skills/hdl-board-wrapper-signoff/SKILL.md) |
| [fpga-board-build-signoff](skills/fpga-board-build-signoff.md) | 빌드 재현성과 배포 산출물 일치 | [SKILL.md](../skills/fpga-board-build-signoff/SKILL.md) |
| [zcu104-xczu7ev-hardware](skills/zcu104-xczu7ev-hardware.md) | ZCU104 장치·clock·보드 제약 | [SKILL.md](../skills/zcu104-xczu7ev-hardware/SKILL.md) |

## 유지보수

Skill을 변경할 때 해당 개별 문서의 입력·절차·판정·연계도 함께 갱신한다.
새 Skill을 추가하면 개별 명세서와 이 목차에 모두 등록한다. 원본과 설명이
충돌하면 문서만으로 검증 조건을 완화하지 말고 활성 프로젝트 계약과 원본을
대조해 차이를 해결한다. 적용 예시는 실제 실행 증거와 구분한다.

