# hdl-kernel-contract-gates 명세서

조합 가능한 커널의 검증 기준

- 기준: 2026-09-08 프로젝트 지침
- 원본: [SKILL.md](../../skills/hdl-kernel-contract-gates/SKILL.md)
- 문서 성격: 현재 Skill의 동작 명세이며, 아래 사례는 적용 예시로 실제 검증 결과가 아니다.

## 1. 목적과 적용 조건

개별 커널이 상위 Layer/Top FSM에 연결 가능한지, 주장 범위가 검증에 맞는지 검사한다. sim-only, placeholder 또는 일부 증거 누락이 의심될 때 적용한다.

## 2. 입력과 선행 조건

module packet·공통 interface·RTL·TB·clock constraint, kernel_report, simulation/lint/Vivado·packing 증거와 target coverage.

## 3. 상세 처리 절차

1. aclk/aresetn/start/done, stable output과 little-element packing을 확인한다.

2. 실제 clock constraint와 NA가 아닌 setup/hold/pulse-width, 정확한 도구 단계와 lint 결과를 확인한다.

3. GPTQ INT4 roundtrip 및 real checkpoint 호환 증거의 존재/차단을 구분한다.

4. 실제 datapath·병렬 product·tensor payload와 fixture/checksum/control scaffold를 구분한다.

5. model_scheduler 자체 loop와 compute의 local-only 포트를 확인한다.

6. 상위 FSM의 실제 child status/payload 관측·release 대기·반복 호출 증거를 검토하고 미충족 항목을 반환한다.

## 4. 출력과 산출물

kernel_report의 필수 증거·coverage 필드에 대한 판정, 실패·누락 항목과 contract-compliant retry 요구; 패킷에 포함할 prompt 조건.

파일명은 원본 Skill과 작업 패킷의 지정에 따른다. 산출물 목록은 생성 의무/형식을 설명하며 기존 파일 존재를 주장하지 않는다.

## 5. 완료 및 검증 기준

모듈 이름이나 completion만으로 통과하지 않는다. 대상 기능·현재 source·수치·handshake·clock·도구 증거가 해당 범위를 뒷받침해야 한다.

## 6. 책임 경계와 실패 처리

구현을 하지 않은 arithmetic을 fixture로 표시한다. 자원 수치가 낮다는 이유만으로 효율적이라 인정하지 않는다. 실측 구조 변화 없이 같은 tuning을 반복하지 않는다.

## 7. 연계 Skills

- [hdl-module-implementation](hdl-module-implementation.md)
- [hdl-module-verification](hdl-module-verification.md)
- [hdl-integration-agent](hdl-integration-agent.md)
- [hdl-integration-verification](hdl-integration-verification.md)
- [fpga-systemverilog](fpga-systemverilog.md)
- [fpga-vivado](fpga-vivado.md)

## 8. 적용 예시

RMSNorm이 외부 inv_rms를 곱하기만 한다면 full RMSNorm으로 승인하지 않고 apply fixture와 누락 reduction/rsqrt를 명시한다.

## 9. 현재 적용 시 유의점

이 Skill의 gates는 LLM 검토 지침이다. 모든 조항을 자동 강제하는 단일 프로그램이 현재 존재한다는 뜻은 아니다.

[전체 Skill 명세 목차](../skills_specification.md) · [공통 계약과 운영 규칙](../skills_overview.md)

