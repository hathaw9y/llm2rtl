# fpga-board-build-signoff 명세서

빌드 재현성과 배포 산출물 일치

- 기준: 2026-09-08 프로젝트 지침
- 원본: [SKILL.md](../../skills/fpga-board-build-signoff/SKILL.md)
- 문서 성격: 현재 Skill의 동작 명세이며, 아래 사례는 적용 예시로 실제 검증 결과가 아니다.

## 1. 목적과 적용 조건

검증된 설계를 현재 run의 BIT/HWH/XSA 및 routed evidence로 패키징한다. production·diagnostic 구분과 실패 recovery를 소유한다.

## 2. 입력과 선행 조건

검증 HDL/board packet, source/helper/constraint manifests, exact target/tool, resource/timing/congestion gates, required artifact set·deployment policy.

## 3. 상세 처리 절차

1. owner/run 생성 전 version·free space·fresh paths·hash·source closure·launch 계획을 확인한다.

2. 변경된 소스는 fresh build를 기본으로 하며 checkpoint 재개는 현재·완료·비오염 증거가 있을 때만 수행한다.

3. Vivado object cardinality·property 의미를 검사하고 synth/route 단계별 report parser를 사용한다.

4. timing·unconstrained·route·DRC/methodology·정책상 congestion을 원시 report로 판정한다.

5. standalone BIT와 XSA 내부 BIT, 요구 HWH, routed DCP·reports의 동일 build identity를 확인한다.

6. staging 사본을 검증·hash하고 classifier/READY와 manifest를 완성한 뒤 원자적으로 게시한다.

## 4. 출력과 산출물

일치하는 BIT/HWH/XSA, routed DCP·reports, typed source/artifact manifests, final classifier, build/run 상태와 재현 명령.

파일명은 원본 Skill과 작업 패킷의 지정에 따른다. 산출물 목록은 생성 의무/형식을 설명하며 기존 파일 존재를 주장하지 않는다.

## 5. 완료 및 검증 기준

산출물 존재만이 아니라 전체 acceptance policy와 동일 run·archive identity를 만족해야 production/deployable로 분류한다. 검증기 자체는 validation-only 경로에서 파일을 복구/변경하지 않아야 한다.

## 6. 책임 경계와 실패 처리

실패 one-shot token을 재사용하지 않는다. 실패 증거를 보존하고 새 namespace로 재시도한다. partial route나 report parsing 실패를 파일 이름 변경으로 통과 처리하지 않는다.

## 7. 연계 Skills

- [hdl-generation-verification](hdl-generation-verification.md)
- [hdl-board-wrapper-signoff](hdl-board-wrapper-signoff.md)
- [fpga-vivado](fpga-vivado.md)
- [hdl-vivado-timing-closure](hdl-vivado-timing-closure.md)
- [zcu104-xczu7ev-hardware](zcu104-xczu7ev-hardware.md)
- [fpga-hardware-validation](fpga-hardware-validation.md)

## 8. 적용 예시

BIT는 생성됐으나 XSA의 HWH가 다른 주소 맵이면 배포를 차단하고 일치하는 artifact를 새 검증 경로에서 준비한다.

## 9. 현재 적용 시 유의점

지원 자료: [failure-patterns.md](../../skills/fpga-board-build-signoff/references/failure-patterns.md). 정책상의 one-shot·congestion·archive 요구는 현재 packet에서 명확히 고정한다. 사용자의 실물 실행은 hardware-validation 인계 이후다.

[전체 Skill 명세 목차](../skills_specification.md) · [공통 계약과 운영 규칙](../skills_overview.md)

