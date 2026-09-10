# fpga-hardware-validation 명세서

사용자 FPGA 테스트 인계와 결과 분석

- 기준: 2026-09-08 프로젝트 지침
- 원본: [SKILL.md](../../skills/fpga-hardware-validation/SKILL.md)
- 문서 성격: 현재 Skill의 동작 명세이며, 아래 사례는 적용 예시로 실제 검증 결과가 아니다.

## 1. 목적과 적용 조건

정확한 빌드에 대한 테스트 자료를 제공하고 사용자가 반환한 결과를 해석한다. 실제 FPGA 적재·실행은 사용자가 수행한다.

## 2. 입력과 선행 조건

stage/build ID와 matched BIT/HWH 및 필요한 XSA; source/artifact hashes; 보드 profile·driver·register/memory map; golden·허용 오차·필수 테스트 범위.

## 3. 상세 처리 절차

1. 빌드 산출물과 테스트 계약을 확인하고 사용자의 실행 환경을 확정한다. 보드 이름만으로 PYNQ나 접속 방법을 추정하지 않는다.

2. 입력·독립 golden·테스트 script/notebook·setup/programming 안내·timeout·반환할 로그를 준비한다.

3. board 없이 가능한 syntax, packing, golden 및 offline 비교를 확인하고 실제 hardware 검증과 구분한다.

4. hardware_test_handoff.md를 전달하고 awaiting_user_hardware_validation 상태에서 사용자 결과를 기다린다.

5. 결과의 build/test/input identity를 대조하고 실제 출력·metadata·성능 범위를 분석한다.

6. passed/failed/incomplete와 evidence_basis를 기록해 부모에게 반환한다.

## 4. 출력과 산출물

hardware_test_handoff.md, 입력 및 예상 결과, 사용자 실행 코드, hardware_validation_report.json, 원시 결과와 offline 비교 기록.

파일명은 원본 Skill과 작업 패킷의 지정에 따른다. 산출물 목록은 생성 의무/형식을 설명하며 기존 파일 존재를 주장하지 않는다.

## 5. 완료 및 검증 기준

정확한 빌드의 필수 테스트와 사용자 확인을 충족해야 passed이다. 원시 자료 요구가 있으면 사용자 진술만으로 대체하지 않는다. 부모가 최종 stage acceptance를 결정한다.

## 6. 책임 경계와 실패 처리

직접 보드 접속·적재·리셋·실행하지 않는다. 단순 done이나 다운로드 성공을 수치 검증으로 취급하지 않는다. build mismatch는 incomplete로 남기고 자료를 요청한다.

## 7. 연계 Skills

- [fpga-incremental-bringup](fpga-incremental-bringup.md)
- [fpga-board-build-signoff](fpga-board-build-signoff.md)
- [zcu104-xczu7ev-hardware](zcu104-xczu7ev-hardware.md)

## 8. 적용 예시

사용자가 회수한 결과 배열을 동일 입력의 golden과 비교하고 최초 mismatch 인덱스·예상값·실제값·빌드 ID를 기록한다.

## 9. 현재 적용 시 유의점

evidence_basis는 user_attestation 또는 user_run_with_reviewed_outputs로 구분한다. 보드 테스트 전에 정한 오차를 결과에 맞춰 넓히지 않는다.

[전체 Skill 명세 목차](../skills_specification.md) · [공통 계약과 운영 규칙](../skills_overview.md)

