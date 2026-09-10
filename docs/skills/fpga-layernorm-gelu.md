# fpga-layernorm-gelu 명세서

정규화와 비선형 vector pipeline

- 기준: 2026-09-08 프로젝트 지침
- 원본: [SKILL.md](../../skills/fpga-layernorm-gelu/SKILL.md)
- 문서 성격: 현재 Skill의 동작 명세이며, 아래 사례는 적용 예시로 실제 검증 결과가 아니다.

## 1. 목적과 적용 조건

LayerNorm과 GELU 및 공유 nonlinear vector engine을 설계한다. 정규화 reduction, reciprocal sqrt, LUT/PWL, replay와 rate matching 결정에 적용한다.

## 2. 입력과 선행 조건

normalized axis/vector length, GELU domain, epsilon·gamma/beta 형식, 입력/출력 정밀도, throughput·buffer·producer/consumer order·target.

## 3. 상세 처리 절차

1. LayerNorm의 two-pass, sum/sum-of-squares, Welford, segmented/look-ahead 후보를 비교하고 replay 방법을 정의한다.

2. GELU의 LUT/PWL/polynomial, 전용/공유 vector engine과 clipping을 비교한다.

3. 모든 중간 폭·반올림·saturation·reciprocal·rsqrt 경계를 도출한다.

4. 인접 matrix engine과 buffer·mode switch·layout/precision 전환 비용을 포함해 rate를 맞춘다.

5. constant·large-offset near-constant·최대 분산·길이1·tail·계수 극값·근사 경계를 검증한다.

6. calibration 수치 오차와 모델 품질을 보고 후보를 합성·timing으로 비교한다.

## 4. 출력과 산출물

수식·format, 후보 비교, pipeline·buffer/replay schedule, width/error analysis, cycle/II/resource, interface·test/gates.

파일명은 원본 Skill과 작업 패킷의 지정에 따른다. 산출물 목록은 생성 의무/형식을 설명하며 기존 파일 존재를 주장하지 않는다.

## 5. 완료 및 검증 기준

분산 cancellation과 overflow를 구분하고 전체 domain의 근사 동작을 정의해야 한다. 공유 경로의 전환 비용이 성능 이득을 지우지 않는지 확인한다.

## 6. 책임 경계와 실패 처리

작은 음수 variance clamp로 overflow를 숨기지 않는다. LayerNorm overlap이나 FFN streaming을 dependency·backpressure 증거 없이 주장하지 않는다.

## 7. 연계 Skills

- [fpga-adder-tree](fpga-adder-tree.md)
- [fpga-quantization](fpga-quantization.md)
- [fpga-2d-systolic-array](fpga-2d-systolic-array.md)
- [fpga-systemverilog](fpga-systemverilog.md)
- [fpga-vivado](fpga-vivado.md)

## 8. 적용 예시

near-constant 큰 입력 벡터에서 E[x²]−E[x]² 방식과 two-pass 방식의 수치 안정성을 비교해 pipeline을 선택한다.

## 9. 현재 적용 시 유의점

이 Skill 이름과 본문은 LayerNorm/GELU 중심이다. RMSNorm·SiLU에는 별도 연산 방정식과 기존 IP 계약을 확인해야 한다.

[전체 Skill 명세 목차](../skills_specification.md) · [공통 계약과 운영 규칙](../skills_overview.md)

