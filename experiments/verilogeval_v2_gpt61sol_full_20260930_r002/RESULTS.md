# GPT-6.1 Sol 전체 VerilogEval v2 재실험 결과

전체 156문제를 일반 단일 Agent와 Contract 기반 단일 Agent로 새로 생성했다.
총 **312/312회 완료**했으며, 이전 후보를 재사용하지 않았다. 공식 판정과
최초·최종 RTL, 개발 검사, skill/helper 해시와 CSV 집계의 완료 감사를 통과했다.

| 지표 | 일반 단일 Agent | Contract 기반 단일 Agent |
| --- | ---: | ---: |
| 최초 RTL 공식 통과 | 142/156 (91.03%) | 142/156 (91.03%) |
| 자체 디버깅 후 최종 공식 통과 | **146/156 (93.59%)** | **146/156 (93.59%)** |
| reference 통과 152문제에서 최종 통과 | 146/152 (96.05%) | 146/152 (96.05%) |
| 평균 생성 시간 | 94.35초 | 132.44초 |
| 중앙값 생성 시간 | 89.76초 | 126.84초 |
| RTL이 수정된 문제 수 | 4 | 4 |
| 총 RTL 수정 횟수 | 5 | 6 |
| 실제 개발 검사 횟수 | 168 | 170 |
| 실패 후 수정·재검사된 개발 검사 | 12 | 14 |
| 최종 개발 TB 실행·통과 | 156/156 | 156/156 |
| 생성 시간 초과 / 프로토콜 위반 | 0 / 0 | 0 / 0 |

두 방식은 **156문제의 최종 통과/실패 결과까지 동일**하다. 이번 실행에서는
Contract에 따른 추가 성공률 개선이 관찰되지 않았고, 평균 생성 시간은
40.37% 길었다. 문제당 조건별 한 번의 세션이므로 일반적인 우열이나 반복
생성 변동성을 결론 내릴 수는 없다. 최종 통과율은 자체 디버깅을 허용한
워크플로 결과이며, 도구 없는 one-shot pass@1 점수로 부르지 않는다.

## 디버깅이 실제로 작동했는가

양쪽에서 아래 4문제가 최초 후보 실패에서 최종 통과로 바뀌었다.

| 문제 | 최초 실패 원인 | 일반 RTL 수정 | Contract RTL 수정 |
| --- | --- | ---: | ---: |
| Prob112_always_case2 | Icarus 12의 always_comb/constant-select 처리 호환성 | 1회 | 1회 |
| Prob128_fsm_ps2 | 같은 컴파일 호환성 | 2회 | 2회 |
| Prob147_circuit10 | 파형과 다른 상태 전이 | 1회 | 1회 |
| Prob148_2013_q2afsm | 컴파일 호환성 | 1회 | 2회 |

세 호환성 사례는 컴파일 실패 로그와 보조 Icarus 11 진단을 보고 표현을
바꿨다. enum의 localparam 표현 또는 always @* 같은 호환 표현을 사용한 뒤
**원래 지정한 Icarus 12**로 개발 검사와 공식 평가를 통과했다. 보조 진단은
평가 도구 교체가 아니다. 따라서 수정의 일부는 시뮬레이터 호환성 개선이다.

`circuit10`은 최초 AND-only 상태 갱신이 원문 파형의 125ns 샘플을 어겼다.
두 Agent 모두 원문 파형을 재현한 TB 실패를 보고 mixed inputs에서 state를
유지하는 majority 전이로 수정했다. Contract 조건은 잘못된 최초 Contract를
`contract_initial.json`에 보존하고, 수정·freeze·gate 재실행 후 RTL을 수정했다.
공식 피드백을 제공하지 않고도 기능 오류를 발견하고 수정한 사례다.

개발 검사 snapshot 사이의 TB 변경은 조건별 8회씩이었다. 일반 조건의 1회는
RTL 수정과 동시에 이뤄졌다. TB만 변경한 횟수는 일반 7회, Contract 8회이며,
각 worker가 reset/stimulus 타이밍 등의 변경 근거를 남겼다. 이 숫자는 검사
snapshot 사이에서 관찰한 변경이며, 모든 중간 편집 횟수는 아니다.

초기 도구 점검에서도 실제 GPT-6.1 Sol이 의도적으로 잘못된 별도 DFF fixture의
TB 실패 로그를 읽고 RTL 1회 수정 후 통과했다. 이 별도 점검은 312회 점수나
평균 생성 시간에 포함하지 않았다.

## 남은 실패

reference가 통과한 152문제 중 양쪽에서 동일한 6문제가 실패했다.

- Prob034_dff8
- Prob053_m2014_q4d
- Prob062_bugs_mux2
- Prob093_ece241_2014_q3
- Prob104_mt2015_muxdff
- Prob149_ece241_2013_q4

각 조건에서 기능 mismatch 5개와 공식 컴파일 실패 1개다. 이 6문제는 생성
당시 자체 개발 TB를 통과했기 때문에 Agent가 공식 실패를 알고 수정한 것은
아니다. 자체 TB 통과와 공식 테스트 통과는 다르다. 예를 들어 `bugs_mux2`는
출력을 1비트로 생성했지만 공식 TB는 8비트로 연결했다. 일반 후보에 대한
보조 진단 로그를 `diagnostics/Prob062_bugs_mux2/`에 남겼다. 개발 TB가 동일한
좁은 인터페이스를 사용하면 이 차이를 놓칠 수 있다.

나머지 4문제는 이전의 공식 reference 검증에서도 실패한 문제다.
`Prob099_m2014_q6c`는 prompt/reference Y1/Y3와 testbench Y2/Y4가 불일치한다.
`Prob082_lfsr32`, `Prob141_count_clock`, `Prob156_review2015_fancytimer`는
reference에서도 TIMEOUT 문구가 발생해 고정한 공식 분석기가 실패로 판정한다.
이 4문제를 포함한 **156문제 점수가 기본 결과**이고, 152문제 점수는 참고용이다.
benchmark source나 점수 산정 기준을 모델 결과에 맞춰 수정하지 않았다.

## 이전 실행과 비교할 때의 범위

이전 최종 점수는 일반 140/156, Contract 138/156이었다. 이번에는 개발 검증의
warning 옵션, 필수 smoke/검사/디버깅 절차, 공통 TopModule/enum 호환성 지침과
생성 시간 제한(300→600초)을 변경했고 모든 후보를 새로 생성했다. 따라서
점수 상승 전체를 디버깅 하나의 인과 효과로 해석하지 않는다. 같은 새 실행
안에서 최초 후보 142개에서 최종 후보 146개로 바뀐 4문제는 수정 효과를
직접 관찰한 결과다.

두 조건 모두 단일 Agent이고 공통 SystemVerilog skill을 사용한다. Contract
조건에는 문서 작성, 구조 gate, 추가 Contract 검증 skill이 포함된다. 이는
워크플로 전체 비교이며, 구조 gate가 원문 의미나 oracle의 정확성을 증명하는
것은 아니다. 전체 가속기의 ISA/bank/모듈 간 Contract 효과는 평가하지 않았다.

## 확인 자료

- [실험 프로토콜](README.md), [실행 manifest](run_manifest.json)
- [문제별 CSV](results.csv), [최종 비교 JSON](final_comparison.json)
- [관찰한 디버깅 이력](debug_analysis.json), [완료 감사](completion_audit.json)
- [사전 점검](preflight_acceptance.json), [reference 검증](benchmark_validity.json)

완료 감사에서 312개 결과의 원본/평가/개발 snapshot과 helper/skill 파일을
대조했고, 4,108개 파일 해시 확인에서 불일치가 없었다. 실행 명령 1,601개에
대한 금지 경로 검색에서도 의심 항목은 없었다. 파일 접근 격리는 지시 기반이며
보안 경계로 강제한 것은 아니다. 모든 명령과 모델 transcript를 보존했다.

이 실험은 VerilogEval v2만 대상으로 한다. VerilogEval v1/CVDP, MAGE 재실행,
Vivado 합성, ZCU104 실행과 TOPS/W는 측정하지 않았다.
