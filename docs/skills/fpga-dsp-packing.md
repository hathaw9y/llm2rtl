# fpga-dsp-packing 명세서

DSP 필드 packing과 cascade

- 기준: 2026-09-08 프로젝트 지침
- 원본: [SKILL.md](../../skills/fpga-dsp-packing/SKILL.md)
- 문서 성격: 현재 Skill의 동작 명세이며, 아래 사례는 적용 예시로 실제 검증 결과가 아니다.

## 1. 목적과 적용 조건

하나의 DSP에 복수 저정밀 곱셈/MAC을 배치하는 방식을 증명·구현·검증한다. DSP 공유, 부호 보정, guard, 추출, cascade가 설계 문제일 때 적용한다.

## 2. 입력과 선행 조건

정확한 DSP generation과 primitive port/cascade widths·register mode; operand signedness/width, 공유 operand, 누산 길이, 배열 schedule·target clock.

## 3. 상세 처리 절차

1. 직접 곱셈, packed product, bit-split, cascade 후보를 유효 sustained MAC/s로 비교한다.

2. packed bit-field offset·sign extension·correction·guard·extraction 위치를 도식화한다.

3. 곱의 분리뿐 아니라 누산 carry가 인접 필드에 침범하지 않는 최대 길이를 증명한다.

4. broadcast/FIFO/reorder/crossbar/merge와 correction의 자원·지연 비용을 계산한다.

5. 각 lane을 독립 full-width arithmetic과 비교하는 directed/random 테스트를 수행한다.

6. 합성 primitive mode와 실제 배치·cascade·congestion·clock을 확인한다.

## 4. 출력과 산출물

primitive 설정, bit-field 배치, 수학적 보정·guard 증명, 안전 누산 bound, feed/extraction 구조, 테스트와 resource/timing 비교.

파일명은 원본 Skill과 작업 패킷의 지정에 따른다. 산출물 목록은 생성 의무/형식을 설명하며 기존 파일 존재를 주장하지 않는다.

## 5. 완료 및 검증 기준

최소 음수·최대 양수·모든 부호·zero·safe-bound 초과·tail·stall·precision 전환이 일치해야 한다. 실제 비용 후 packing 이득이 유지되어야 한다.

## 6. 책임 경계와 실패 처리

다른 DSP 세대의 offset을 복사하거나 곱셈만 검사해 MAC도 안전하다고 주장하지 않는다. 모드 전환은 drain 경계를 요구한다.

## 7. 연계 Skills

- [fpga-adder-tree](fpga-adder-tree.md)
- [fpga-quantization](fpga-quantization.md)
- [fpga-2d-systolic-array](fpga-2d-systolic-array.md)
- [fpga-systemverilog](fpga-systemverilog.md)
- [fpga-vivado](fpga-vivado.md)

## 8. 적용 예시

INT4 두 lane의 공통 operand packing을 제안할 때 최솟값 부호 보정과 누산 후 필드 분리를 테스트한 뒤 DSP mapping을 확인한다.

## 9. 현재 적용 시 유의점

코드의 곱셈 연산자나 의도한 DSP 수는 실제 inference의 증거가 아니다. 활성 run의 hierarchy/report를 사용한다.

[전체 Skill 명세 목차](../skills_specification.md) · [공통 계약과 운영 규칙](../skills_overview.md)

