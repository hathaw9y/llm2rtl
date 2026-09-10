# fpga-pruning 명세서

희소 정책·형식·실행 비용

- 기준: 2026-09-08 프로젝트 지침
- 원본: [SKILL.md](../../skills/fpga-pruning/SKILL.md)
- 문서 성격: 현재 Skill의 동작 명세이며, 아래 사례는 적용 예시로 실제 검증 결과가 아니다.

## 1. 목적과 적용 조건

weight/block/token/head/attention sparsity를 FPGA 실행에 매핑한다. pruning이 명세에 있거나 설계 후보로 평가될 때 적용한다.

## 2. 입력과 선행 조건

pruned 대상·density·selection 시점, checkpoint·calibration/retraining, task-quality budget, prefill/decode, dense baseline.

## 3. 상세 처리 절차

1. dense baseline과 가능한 structured/balanced 및 adaptive 후보를 비교한다.

2. 값·index·pointer·mask·header·padding·scale·복제 buffer bytes를 합산한다.

3. selector/sorter/decoder/merge cycle·lane 불균형·burst 효율·post-route clock을 모델링한다.

4. block shape·index width·end marker·order·top-k tie·all-pruned·logical token/head map을 고정한다.

5. dense masked computation과 sparse 결과를 비교한다.

6. 실효 density·metadata ratio·bandwidth·latency·energy 및 모델 품질로 최종 이득을 평가한다.

## 4. 출력과 산출물

pruning semantics, sparse-format 계약, 후보 비교와 memory/compute/control 비용, schedule·품질·directed tests·E2E gates.

파일명은 원본 Skill과 작업 패킷의 지정에 따른다. 산출물 목록은 생성 의무/형식을 설명하며 기존 파일 존재를 주장하지 않는다.

## 5. 완료 및 검증 기준

values+metadata+padding이 dense bytes보다 적고, 생략된 연산/전송이 selector·routing·merge·낮은 clock 비용보다 커야 한다. logical identity와 causal/positional 의미를 유지해야 한다.

## 6. 책임 경계와 실패 처리

weight sparsity를 dense attention/KV 작업 감소로 간주하지 않는다. kernel speedup만으로 전체 inference 개선을 주장하지 않는다.

## 7. 연계 Skills

- [fpga-dsp-packing](fpga-dsp-packing.md)
- [fpga-2d-systolic-array](fpga-2d-systolic-array.md)
- [fpga-quantization](fpga-quantization.md)
- [fpga-softmax](fpga-softmax.md)
- [fpga-vivado](fpga-vivado.md)

## 8. 적용 예시

token pruning으로 압축된 index를 다음 layer와 KV/position에서 원래 token으로 복원할 수 있는 map 계약을 검증한다.

## 9. 현재 적용 시 유의점

empty/full block·잘못된/중복 index·tail·tie·all-pruned·stall을 포함한다. dense와 pruned checkpoint 품질은 각각 기록한다.

[전체 Skill 명세 목차](../skills_specification.md) · [공통 계약과 운영 규칙](../skills_overview.md)

