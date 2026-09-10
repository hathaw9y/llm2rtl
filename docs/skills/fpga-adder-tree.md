# fpga-adder-tree 명세서

축약 네트워크의 폭과 pipeline

- 기준: 2026-09-08 프로젝트 지침
- 원본: [SKILL.md](../../skills/fpga-adder-tree/SKILL.md)
- 문서 성격: 현재 Skill의 동작 명세이며, 아래 사례는 적용 예시로 실제 검증 결과가 아니다.

## 1. 목적과 적용 조건

dot product reduction 및 partial sum 네트워크를 설계한다. balanced/segmented tree, DSP cascade, carry-save, folded reduction이나 누산 폭·valid 정렬 문제에 적용한다.

## 2. 입력과 선행 조건

operand·product format, signedness·zero point, 최대 term 수, output 형식, target clock·throughput·backpressure.

## 3. 상세 처리 절차

1. balanced registered tree, DSP cascade, segmented+final accumulator, folded 후보를 비교한다.

2. two's-complement 비대칭 최솟값까지 포함해 정확한 product/partial/final bound를 계산한다.

3. round/truncate/saturate/requantize와 packed-lane extraction 위치를 고정한다.

4. 목표 clock에 맞게 stage를 나누고 valid·mask·scale·tail metadata를 정렬한다.

5. extrema·상쇄·overflow 경계·합법 tail·flush·stall을 검증한다.

6. OOC 자원·timing으로 LUT/DSP/hybrid 매핑과 fanout·물리 경로를 평가한다.

## 4. 출력과 산출물

reduction 방정식, 폭 도출, topology 비교, pipeline/latency/II 계약, directed tests/assertions와 synthesis/timing 기준.

파일명은 원본 Skill과 작업 패킷의 지정에 따른다. 산출물 목록은 생성 의무/형식을 설명하며 기존 파일 존재를 주장하지 않는다.

## 5. 완료 및 검증 기준

최대·최소 범위와 모든 합법 tail에서 정의된 수치 정책을 만족해야 한다. 데이터와 sideband의 cycle 정렬 및 목표 timing을 확인해야 한다.

## 6. 책임 경계와 실패 처리

알고리즘이 요구하지 않는 wraparound를 허용하지 않는다. 논리적으로 balanced라고 물리 timing이 맞는 것으로 취급하지 않는다.

## 7. 연계 Skills

- [fpga-dsp-packing](fpga-dsp-packing.md)
- [fpga-quantization](fpga-quantization.md)
- [fpga-systemverilog](fpga-systemverilog.md)
- [fpga-vivado](fpga-vivado.md)
- [hdl-vivado-timing-closure](hdl-vivado-timing-closure.md)

## 8. 적용 예시

32개 signed product를 단계별 local tree로 줄이고 최종 accumulator에 연결하면서 mask와 scale pipeline도 같은 지연으로 맞춘다.

## 9. 현재 적용 시 유의점

폭 산정은 단순 log2 growth 공식으로 끝내지 않고 실제 operand extrema와 association을 확인한다.

[전체 Skill 명세 목차](../skills_specification.md) · [공통 계약과 운영 규칙](../skills_overview.md)

