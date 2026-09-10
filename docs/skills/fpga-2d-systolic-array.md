# fpga-2d-systolic-array 명세서

2차원 배열과 데이터플로 설계

- 기준: 2026-09-08 프로젝트 지침
- 원본: [SKILL.md](../../skills/fpga-2d-systolic-array/SKILL.md)
- 문서 성격: 현재 Skill의 동작 명세이며, 아래 사례는 적용 예시로 실제 검증 결과가 아니다.

## 1. 목적과 적용 조건

Transformer의 GEMM/GEMV와 attention 연산을 FPGA 배열에 배치한다. PE 크기, stationary 방식, 협력·연쇄 배열, tiling 또는 prefill/decode 활용률을 결정할 때 적용한다.

## 2. 입력과 선행 조건

모든 행렬 shape와 batch/context, precision·sparsity, target part/clock, usable on-chip bytes, sustained external bandwidth.

## 3. 상세 처리 절차

1. Prefill GEMM과 batch-1 decode GEMV/skinny GEMM을 분리해 주요 workload를 확정한다.

2. 기본 output/weight-stationary 배열과 workload별 대안을 적어도 하나 비교한다.

3. 공간 occupancy와 K reduction, fill/drain, tail, 전송·offload·mode switch cycle을 계산한다.

4. Q/K/V/score/probability/head/FFN의 실제 저장·생산 순서를 고정한다.

5. PE 연산·누산 폭·bank/stream·stall·drain·reset·모드 전환 계약을 작성한다.

6. bit accuracy와 schedule 검증 후 대상 클럭의 OOC 및 필요한 물리 증거를 확인한다.

## 4. 출력과 산출물

가정·baseline·후보 비교, 선택 dataflow, cycle/capacity/bandwidth/resource 추정, tensor layout schedule, interface와 test gates.

파일명은 원본 Skill과 작업 패킷의 지정에 따른다. 산출물 목록은 생성 의무/형식을 설명하며 기존 파일 존재를 주장하지 않는다.

## 5. 완료 및 검증 기준

주요 실행 모드에서 실효 활용률과 데이터 공급을 설명해야 한다. Fusion은 row 또는 online Softmax 상태와 producer-consumer 순서를 증명해야 한다.

## 6. 책임 경계와 실패 처리

대부분 idle인 정사각 배열, 비용에 반영하지 않은 transpose buffer, metadata/routing으로 이득이 사라지는 sparse 구조를 거부한다. 모듈 OOC를 보드 signoff로 확대하지 않는다.

## 7. 연계 Skills

- [fpga-dsp-packing](fpga-dsp-packing.md)
- [fpga-adder-tree](fpga-adder-tree.md)
- [fpga-softmax](fpga-softmax.md)
- [fpga-pruning](fpga-pruning.md)
- [fpga-quantization](fpga-quantization.md)
- [fpga-ddr-pingpong-residency](fpga-ddr-pingpong-residency.md)
- [fpga-vivado](fpga-vivado.md)

## 8. 적용 예시

decode의 M=1 workload에 큰 정사각 배열과 partitioned 구성을 비교해 실제 유효 MAC/cycle 및 입력 공급 비용을 제시한다.

## 9. 현재 적용 시 유의점

기본 output-stationary occupancy는 min(R,Mt)×min(C,Nt)/(R×C)이며 전체 latency에는 전송·stall·fill/drain을 더한다. paper-reported/derived/measured/assumption을 구분한다.

[전체 Skill 명세 목차](../skills_specification.md) · [공통 계약과 운영 규칙](../skills_overview.md)

