# fpga-ddr-pingpong-residency 명세서

상주·타일 축소·이중 버퍼 결정

- 기준: 2026-09-08 프로젝트 지침
- 원본: [SKILL.md](../../skills/fpga-ddr-pingpong-residency/SKILL.md)
- 문서 성격: 현재 Skill의 동작 명세이며, 아래 사례는 적용 예시로 실제 검증 결과가 아니다.

## 1. 목적과 적용 조건

packed-byte 용량과 실측 전송/계산 시간을 바탕으로 residency 또는 streaming 정책을 비교한다.

## 2. 입력과 선행 조건

tensor shape·bitwidth·정렬·metadata·수명·재사용·random access; 사용 가능한 BRAM/URAM, sustained bandwidth·latency·compute time와 baseline.

## 3. 상세 처리 절차

1. 모든 tensor·scale·mask·index 및 복제 buffer를 실제 packed bytes로 계산한다.

2. 원본 scripts/capacity_overlap.py의 config와 결과를 남긴다.

3. resident, 단일 reduced tile, pingpong 후보의 capacity·serial service·prefetch 부등식을 비교한다.

4. bank의 FREE/FILLING/READY/ACTIVE/DRAINING/FAULT와 epoch·tile identity를 정의한다.

5. stream TKEEP/TLAST·stall 안정성, status와 payload 양쪽 완료, 주소 범위와 owner 변경 barrier를 계약화한다.

6. tail·error·cancel·retry·no-touch·동시 mover/compute를 검증하고 OOC/route·실측 baseline을 다시 비교한다.

## 4. 출력과 산출물

계산기 입력/출력, memory/stream/bank 계약, resident/reduced/pingpong/measure 결정, 테스트·resource/timing와 baseline 비교.

파일명은 원본 Skill과 작업 패킷의 지정에 따른다. 산출물 목록은 생성 의무/형식을 설명하며 기존 파일 존재를 주장하지 않는다.

## 5. 완료 및 검증 기준

resident_bytes + 2×streamed_tile_bytes ≤ usable_bytes를 만족해야 한다. serial mover는 매 tile의 latency + bytes/bandwidth를 compute 시간과 비교한다. 측정이 부족하면 measure로 남긴다.

## 6. 책임 경계와 실패 처리

peak DDR bandwidth를 실측으로 대체하지 않는다. prefetch distance로 느린 serial service rate를 해결했다고 주장하지 않는다. active bank 덮어쓰기와 과거 completion 재사용을 막는다.

## 7. 연계 Skills

- [parent-module-decomposition](parent-module-decomposition.md)
- [fpga-2d-systolic-array](fpga-2d-systolic-array.md)
- [fpga-quantization](fpga-quantization.md)
- [fpga-vivado](fpga-vivado.md)
- [hdl-integration-verification](hdl-integration-verification.md)

## 8. 적용 예시

weight tile 두 개는 들어가지만 scale buffer 포함 시 넘치면 pingpong 대신 reduced 또는 다른 tile 크기를 비교한다.

## 9. 현재 적용 시 유의점

project 주소 계약에서는 scheduler의 타일 DDR 주소 결정과 mover의 직접 beat/word 진행을 구분한다. 원본의 포괄적인 mover 주소 소유 표현은 이 경계를 명시해 적용한다.

지원 자료: [bank/stream 계약](../../skills/fpga-ddr-pingpong-residency/references/contracts.md), [계산기](../../skills/fpga-ddr-pingpong-residency/scripts/capacity_overlap.py), [계산기 테스트](../../skills/fpga-ddr-pingpong-residency/scripts/test_capacity_overlap.py).

[전체 Skill 명세 목차](../skills_specification.md) · [공통 계약과 운영 규칙](../skills_overview.md)

