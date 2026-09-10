# fpga-softmax 명세서

안정적 Softmax와 fused attention 정규화

- 기준: 2026-09-08 프로젝트 지침
- 원본: [SKILL.md](../../skills/fpga-softmax/SKILL.md)
- 문서 성격: 현재 Skill의 동작 명세이며, 아래 사례는 적용 예시로 실제 검증 결과가 아니다.

## 1. 목적과 적용 조건

stable multi-pass, online/tiled, quantized 또는 approximate Softmax의 수치·저장·스케줄을 설계한다.

## 2. 입력과 선행 조건

row axis/length, 1/sqrt(dk) scale, causal/padding·all-masked 정책, 입출력 형식·오차, tile 순서·throughput·memory·clock.

## 3. 상세 처리 절차

1. mask 적용 후 row maximum을 사용하는 stable Softmax reference를 고정한다.

2. multi-pass, online/fused, quantized/approximate 후보를 비교한다.

3. online 방식은 max 갱신 때 denominator와 fused weighted-V accumulator의 재스케일 recurrence를 증명한다.

4. exp·sum·reciprocal·normalization/replay·FIFO·tail·backpressure 비용을 계산한다.

5. LUT/PWL domain·coefficient·clipping·underflow·rounding·범위 밖 동작을 정의한다.

6. equal/dominant logits·all-masked·causal/tail·running max 변화와 probability/row sum/attention 출력을 검증한다.

## 4. 출력과 산출물

방정식·형식, recurrence/pass schedule, 저장·cycle/resource 추정, 근사 오차·interface 계약, directed tests와 model-quality gates.

파일명은 원본 Skill과 작업 패킷의 지정에 따른다. 산출물 목록은 생성 의무/형식을 설명하며 기존 파일 존재를 주장하지 않는다.

## 5. 완료 및 검증 기준

독립 tile normalization이 전체 row semantics를 깨지 않아야 한다. online 상태·mask·생산 순서·정확도와 capacity가 모두 증명되어야 한다.

## 6. 책임 경계와 실패 처리

전체 NxN score buffer의 용량을 생략하지 않는다. random 함수 테스트만으로 base-2/PWL 모델 정확도나 fusion overlap을 주장하지 않는다.

## 7. 연계 Skills

- [fpga-2d-systolic-array](fpga-2d-systolic-array.md)
- [fpga-quantization](fpga-quantization.md)
- [fpga-adder-tree](fpga-adder-tree.md)
- [fpga-layernorm-gelu](fpga-layernorm-gelu.md)
- [fpga-vivado](fpga-vivado.md)

## 8. 적용 예시

두 번째 tile의 maximum이 더 커지는 입력으로 이전 denominator와 V 누산값이 함께 보정되는지 확인한다.

## 9. 현재 적용 시 유의점

경계 벡터 테스트 외에도 대상 모델의 실제 품질 기준이 필요하다. 대체 exponential base는 명시적 모델 근사다.

[전체 Skill 명세 목차](../skills_specification.md) · [공통 계약과 운영 규칙](../skills_overview.md)

