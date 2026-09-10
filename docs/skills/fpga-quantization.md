# fpga-quantization 명세서

수치 형식과 tensor 변환 계약

- 기준: 2026-09-08 프로젝트 지침
- 원본: [SKILL.md](../../skills/fpga-quantization/SKILL.md)
- 문서 성격: 현재 Skill의 동작 명세이며, 아래 사례는 적용 예시로 실제 검증 결과가 아니다.

## 1. 목적과 적용 조건

가중치·activation·KV·중간값의 수치 정책과 변환을 정의한다. bitwidth, mixed/progressive precision, scales/zero-points 및 모델 품질을 비교할 때 적용한다.

## 2. 입력과 선행 조건

tensor 목록과 floating reference, calibration 데이터, W/A/KV·nonlinear 후보 형식, quality budget, prefill/decode 및 하드웨어 조건.

## 3. 상세 처리 절차

1. 각 tensor의 signedness·encoding·width·scale granularity·clipping·metadata를 수집한다.

2. 관련 uniform, row-wise mixed, progressive, integerized-float 대안을 비교한다.

3. 비대칭 extrema·zero-point 항을 포함해 product/accumulator 범위를 증명하고 partial sums의 공통 scale을 정의한다.

4. packing·정렬·scale/index metadata·변환 로직·lane imbalance 비용을 계산한다.

5. 각 quantize/dequantize/requantize 경계를 bit-exact software로 모델링한다.

6. calibration·extrema·round halfway·saturation·scale 전환·tail을 검사하고 layer 및 최종 task quality를 평가한다.

## 4. 출력과 산출물

tensor-format 표, 변환 방정식·폭/오차 증명, 후보 비교, byte/resource/bandwidth 모델, calibration/test 계획과 품질 기준.

파일명은 원본 Skill과 작업 패킷의 지정에 따른다. 산출물 목록은 생성 의무/형식을 설명하며 기존 파일 존재를 주장하지 않는다.

## 5. 완료 및 검증 기준

수치 경계가 완전하며 clipping·scale·product·accumulation·requantization·근사 오차를 구분해야 한다. 메타데이터와 변환 비용 후 이득 및 품질 조건을 충족해야 한다.

## 6. 책임 경계와 실패 처리

W4A8 라벨만으로 구현 계약을 확정하지 않는다. mixed precision의 overhead 또는 progressive retry·worst-case latency가 불명확하면 선택을 확정하지 않는다.

## 7. 연계 Skills

- [fpga-dsp-packing](fpga-dsp-packing.md)
- [fpga-adder-tree](fpga-adder-tree.md)
- [fpga-pruning](fpga-pruning.md)
- [fpga-softmax](fpga-softmax.md)
- [fpga-layernorm-gelu](fpga-layernorm-gelu.md)
- [fpga-ddr-pingpong-residency](fpga-ddr-pingpong-residency.md)

## 8. 적용 예시

INT4 weight와 FP16 group scale의 합성 방식에 대해 group partial sum을 어떤 정밀도로 정렬·누산하고 어디서 FP16으로 반올림할지 고정한다.

## 9. 현재 적용 시 유의점

모델 품질 데이터가 없으면 근사 형식의 E2E 정확도를 입증했다고 하지 않는다. 연산 함수 오차와 모델 품질은 별도 검증이다.

[전체 Skill 명세 목차](../skills_specification.md) · [공통 계약과 운영 규칙](../skills_overview.md)

