# fpga-systemverilog 명세서

SystemVerilog RTL·테스트벤치 작성 규칙

- 기준: 2026-09-08 프로젝트 지침
- 원본: [SKILL.md](../../skills/fpga-systemverilog/SKILL.md)
- 문서 성격: 현재 Skill의 동작 명세이며, 아래 사례는 적용 예시로 실제 검증 결과가 아니다.

## 1. 목적과 적용 조건

합성 가능한 RTL 구조, 수치 폭, cycle·memory·stream semantics와 self-checking TB 품질을 담당한다.

## 2. 입력과 선행 조건

functional/interface/numeric 계약, primary clock/reset, target latency·II·backpressure, memory read/write semantics와 parameter 범위.

## 3. 상세 처리 절차

1. logic/always_ff/always_comb 등 기본 구조와 공통 clock/reset·port naming을 적용한다.

2. sequential nonblocking과 combinational blocking/default assignment를 구분하고 latch·multi-driver를 검사한다.

3. constant·cast·signed extension·product/accumulator/address 폭을 명시한다.

4. payload와 valid/tag/scale/mask를 같은 transaction으로 pipeline하고 stall 안정성을 정의한다.

5. memory width/depth/bank·read latency·read-during-write·byte enable·ownership을 구현한다.

6. reset·extrema·tail·stall·반복·timeout·자동 비교와 명확한 PASS/FAIL을 갖는 TB를 작성한다.

## 4. 출력과 산출물

RTL/TB 변경, interface/cycle·numeric-width 결정, latency/II, static review, 실제 실행한 테스트와 잔여 위험 요약.

파일명은 원본 Skill과 작업 패킷의 지정에 따른다. 산출물 목록은 생성 의무/형식을 설명하며 기존 파일 존재를 주장하지 않는다.

## 5. 완료 및 검증 기준

조합 default·reset·illegal-state recovery·signedness·metadata 정렬·memory 계약과 self-checking TB를 만족해야 한다. 시뮬레이션 결과는 실제 도구 실행으로 확인한다.

## 6. 책임 경계와 실패 처리

정적 코드 검토로 timing closure나 DSP/BRAM inference를 주장하지 않는다. DUT closure에 simulation-only 동작을 넣지 않는다. Xilinx 실행·매핑 증거는 fpga-vivado 소유다.

## 7. 연계 Skills

- [fpga-vivado](fpga-vivado.md)
- [hdl-kernel-contract-gates](hdl-kernel-contract-gates.md)
- [hdl-vivado-timing-closure](hdl-vivado-timing-closure.md)
- [fpga-quantization](fpga-quantization.md)
- [fpga-adder-tree](fpga-adder-tree.md)

## 8. 적용 예시

multiplier stage를 추가할 때 data뿐 아니라 valid·scale·mask도 같은 cycle만큼 이동시키고 stall에서 안정적인지 검사한다.

## 9. 현재 적용 시 유의점

기본 reset은 aresetn active-low synchronous이며 IP/CDC/보드 계약이 달리 요구하면 명시한다. 일반 FSM 예제를 공통 held-done 프로토콜의 완성 구현으로 복사하지 않는다.

[전체 Skill 명세 목차](../skills_specification.md) · [공통 계약과 운영 규칙](../skills_overview.md)

