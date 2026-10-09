# GPT-6.1 Sol 전체 VerilogEval v2 비교 결과

사후 원인 분석에서 자체 개발 컴파일의 timescale 경고 경로 문제가 확인됐다.
공식 평가는 해당 경고를 처음부터 비활성화해 점수는 유지된다. 생성 중 자체
검증·수정이 제한된 점과 4개 불일치 사례는 [ANALYSIS.md](ANALYSIS.md)에 기록했다.

공식 spec-to-RTL 156문제를 두 조건으로 모두 실행했다. 문제당 조건별 새
GPT-6.1 Sol 세션 1회, 총 312회이며, 앞선 12문제 pilot 결과는 재사용하지 않았다.
공식 테스트벤치와 reference는 수정하지 않았고 Icarus Verilog 12.0 및 고정한
공식 분석기의 판정으로 최종 점수를 확정했다.

| 지표 | 일반 단일 Agent | Contract 기반 단일 Agent |
| --- | ---: | ---: |
| 전체 문제 실행 | 156/156 | 156/156 |
| 최초 RTL 통과 | 139/156 (89.10%) | 138/156 (88.46%) |
| 자체 검증·수정 후 최종 통과 | 140/156 (89.74%) | 138/156 (88.46%) |
| reference 통과 152문제에서 최종 통과 | 140/152 (92.11%) | 138/152 (90.79%) |
| 평균 생성 시간 | 74.32초 | 116.17초 |
| 중앙값 생성 시간 | 68.90초 | 108.23초 |
| 총 RTL 수정 횟수 | 1 | 0 |
| 생성 프로토콜 위반 | 0 | 0 |
| 총 출력 토큰 | 245,172 | 395,141 |

최종 통과율은 Contract 조건에서 1.28%p 낮고, 평균 생성 시간은 56.31% 길었다.
이번 실행에서는 Contract에 따른 성공률 개선이 관찰되지 않았다. 문제당 1회만
생성했으므로 Contract 방식이 일반적으로 열등하다고 결론 내릴 수는 없다.
결과가 갈린 4문제의 탐색적 paired exact McNemar p값은 0.625이다.

## 비교한 조건

- 일반 조건: 원문 요구사항을 읽고 RTL을 생성하며 자체 개발 테스트를 수행한다.
- Contract 조건: interface, semantics, numeric, verification 및 specification
  ambiguities를 문서화하고 Contract를 freeze한다. 구조 검증 gate를 통과한 뒤
  RTL을 생성하고 자체 개발 테스트를 수행한다.

두 조건 모두 문제당 **단일 Agent**이며, 같은 원문 문제, 도구 접근, 최대 3회
수정 및 300초 생성 제한을 적용했다. Contract 조건에는 Contract 검증 skill과
추가 문서 작성 절차가 포함되므로, 비교 대상은 Contract-first 워크플로 전체이다.
구조 검증 gate가 기능적 의미까지 증명하지는 않는다. 생성 시간은 모델 호출,
Contract 작성, 도구 실행과 자체 검증을 포함한 실제 경과 시간이며, 공식 평가
시간은 제외한다. 최초 RTL 지표도 도구를 사용하는 세션에서 얻었으며, 최종
통과율을 도구 없는 one-shot 생성 점수로 해석해서는 안 된다.

## 결과가 갈린 문제

| 문제 | 일반 Agent | Contract 기반 |
| --- | --- | --- |
| Prob089_ece241_2014_q5a | 통과 | 컴파일 실패 |
| Prob098_circuit7 | 통과 | 기능 검증 실패 |
| Prob140_fsm_hdlc | 통과 | 컴파일 실패 |
| Prob139_2013_q2bfsm | 컴파일 실패 | 통과 |

reference가 통과한 152문제에서 두 방식 모두 통과한 문제는 137개, 두 방식 모두
실패한 문제는 11개다. 일반 조건의 유효 문제 실패는 컴파일 4개와 기능 8개,
Contract 조건은 컴파일 5개와 기능 9개다. `dff8`과 `mt2015_muxdff`는 두 조건
모두 최초 샘플에서 1회 mismatch가 발생했다. 자체 테스트 통과만으로 공식
테스트 통과를 보장하지 않는 사례이며, 상세 원인 검토용 소스와 로그를 보존했다.

## 공식 reference 자체가 실패한 4문제

- `Prob099_m2014_q6c`: prompt/reference의 Y1/Y3와 testbench의 Y2/Y4가 달라
  공식 reference 자체도 컴파일에 실패한다.
- `Prob082_lfsr32`, `Prob141_count_clock`, `Prob156_review2015_fancytimer`:
  reference도 mismatch 0인 상태에서 TIMEOUT 문구를 출력하며, 고정한 공식
  분석기는 이를 실패로 판정한다.

이 4문제를 포함한 **156문제 공식 점수가 기본 결과**이다. reference 통과 여부로
사전에 정의한 152문제 점수는 참고용으로 함께 제시했다. 중간 runner에 빠져 있던
공식 TIMEOUT 처리 규칙은 저장된 로그에 원본 분석 함수를 적용해 보정했다.
기존 판정과 변경 내역은 `official_verdict_audit.json`에 남겼으며, RTL 수정이나
추가 생성은 하지 않았다.

## 재현 자료 및 범위

- [실험 프로토콜](README.md), [실행 manifest](run_manifest.json)
- [문제별 결과 CSV](results.csv), [최종 비교 JSON](final_comparison.json)
- [완료 감사](completion_audit.json), [공식 판정 보정 내역](official_verdict_audit.json)
- [reference 검증](benchmark_validity.json)

312개 결과의 후보 파일 및 공식 평가 snapshot과 원본 문제 파일을 대조했고,
2,808개 해시 확인에서 불일치가 없었다. Contract gate의 선행 실행과 문서 해시도
확인했다. 실행 명령의 금지 경로 검색에서 의심 항목은 없었지만, 파일 접근
격리는 지시 기반이며 보안 경계로 강제한 것은 아니다.

이 결과는 VerilogEval v2의 독립 모듈 생성 실험이다. VerilogEval v1/CVDP,
MAGE 재실행, multi-Agent 구성, 전체 가속기의 ISA/bank Contract, Vivado 합성,
ZCU104 실행 또는 TOPS/W는 측정하지 않았다. 디코딩 설정은 Codex CLI 기본값이며
별도 통제하지 않았다. 논문에서 일반화하려면 독립 반복 실행이 추가로 필요하다.
