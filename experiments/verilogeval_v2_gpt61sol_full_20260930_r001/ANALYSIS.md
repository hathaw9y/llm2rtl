# Contract 점수 하락의 원인 분석

최종 140/156 대 138/156의 차이는 4개의 불일치 사례로 설명된다. 이 중
3개는 enum 전이 표현의 컴파일 호환성, 1개는 파형 샘플링의 의미 해석이다.
전체 점수는 유지했고, 아래 추가 실행은 사후 진단이며 추가 생성이 아니다.

| 문제 | 실패 조건 | 직접 원인 | 확인한 증거 |
| --- | --- | --- | --- |
| Prob089_ece241_2014_q5a | Contract | enum에 삼항 표현 대입 | 동등한 if/else 사본: 공식 0/436 mismatch |
| Prob140_fsm_hdlc | Contract | enum에 삼항 표현 대입 | 동등한 if/else 사본: 공식 0/801 mismatch |
| Prob139_2013_q2bfsm | 일반 | enum에 삼항 표현 대입 | 동등한 if/else 사본: 공식 0/1002 mismatch |
| Prob098_circuit7 | Contract | 추가 한 사이클 지연을 가정 | 공식 58/123 mismatch, 같은 가정을 쓴 개발 테스트는 317개 비교 통과 |

세 enum 실패는 지정한 Icarus 12에서 종료 코드 139를 낸다. 시스템 Icarus
11의 별도 진단은 `This assignment requires an explicit cast`를 출력한다.
삼항 표현만 동등한 if/else로 바꾼 진단용 사본은 Icarus 12와 공식 테스트를
모두 통과했다. 이는 기능 설계보다 표현의 컴파일 문제다. Contract가 삼항
표현을 유발한다는 인과관계는 확인하지 못했다. 문제 수 차이는 Contract 문법
손실 2개 + 의미 손실 1개 − 일반 문법 손실 1개 = 최종 통과 2개 감소다.

## circuit7: 잘못된 가정을 Contract와 oracle이 공유

일반 RTL은 `q <= ~a`이다. Contract 조건은 `a_sample_r <= a;
q <= ~a_sample_r;`로 추가 레지스터를 넣었다. Contract는 입력과 클록이
같은 시각에 바뀌는 파형을 보고 `q[n] = ~a[n-1]`를 명시했다. 일반 조건은
동시 입력 변화가 클록 샘플링 이후에 일어나는 것으로 해석했다.

Contract 개발 테스트도 입력을 edge 전에 안정화하고 이전 샘플의 반전을
기대한다. 실행하면 317개 비교가 통과하지만 공식 테스트는 58개 mismatch다.
RTL과 테스트가 Contract에 일치해도 Contract의 원문 해석이 맞는지는 별도다.
이번 구조에는 이 가정을 독립적으로 반박하는 검증이 없었다.

## 발견한 실험 설정 문제

worker 보고서 중 일반 120/156, Contract 129/156에서 종료 코드 139를
기록했다. 원본 개발 파일을 `-g2012 -Wall -s dev_tb`로 사후 컴파일해도 각각
120개와 129개가 실패한다. 동일 명령에 **`-Wno-timescale`만 추가**하면
일반 116개, Contract 125개가 복구돼, 두 조건 모두 개발 컴파일 성공이
152/156이 된다. 이는 컴파일 성공이며 시뮬레이션/공식 평가 통과가 아니다.

`circuit7`의 소스 경로를 상대/절대로 바꾼 2×2 진단에서도 경로와 무관하게
`-Wall`일 때 실패했고, 옵션을 제거하거나 `-Wno-timescale`을 추가하면
성공했다. 이 설치본의 timescale 경고 경로 문제는 재현됐지만 컴파일러
내부 원인까지 분석한 것은 아니다.

공식 평가에는 처음부터 `-Wall -Winfloop -Wno-timescale -g2012`를 썼으므로
기존 점수는 유효하다. 하지만 생성 중 자체 검증·수정 루프는 많은 문제에서
실행되지 못했다. 이 설정을 전체 실행 전에 충분히 확인하지 못했다.
이번 실험은 정상적으로 자체 검증이 가능한 워크플로의 효과를 충분히
평가한 결과로 해석할 수 없다.

사후 실행에서 일반 q5a의 개발 테스트는 실패했다. reset release와 첫 입력
drive 사이에 오래된 x가 샘플링될 여지가 있는 testbench 구조다. 원본 일반
RTL은 공식 테스트를 통과하므로 개발 테스트 자체도 검증해야 한다.

## gate, 시간 및 통계의 의미

`validate_contract.py`는 frozen 표시와 필수 dict/list 구조를 검사한다.
runner는 해시와 gate의 선행 실행도 확인한다. 원문 의미와 Contract의 일치,
oracle의 정확성, RTL의 컴파일 성공까지 보장하지는 않는다. 현재 비교 대상은
Contract 문서 작성과 추가 검증 skill을 포함하는 워크플로 전체다.

Contract 평균 생성 시간은 56.31% 길었지만 양쪽 모두 timeout은 0이다.
최대 생성 시간은 일반 151.63초, Contract 233.04초로 제한 300초 안이다.
따라서 관찰된 실패를 시간 제한 소진으로 설명할 근거는 없다.

최초 RTL은 139 대 138로 1문제 차이였고, 일반 조건의 자체 수정 1회로 최종
차이가 2문제가 됐다. 불일치 4문제의 탐색적 paired exact McNemar p=0.625다.
문제당 1회 생성이므로 Contract 자체의 일반적 우열을 결론 내리지 않는다.

추가 공통 실패: `Prob131_mt2015_q4` 원문은 top 이름을 명시하지 않았다.
두 조건 모두 skill의 소문자 규칙에 따라 `top_module`을 생성했지만 공식
harness는 `TopModule`을 요구한다. 점수 차이의 원인은 아니며, 다음 실행에는
harness 필수 top 이름을 공통 입력에 명시해야 한다.

## 다음 실행의 우선 변경

1. 실제 생성 환경에서 sequential RTL+testbench smoke test를 수행하고 simulator
   옵션을 양쪽 동일하게 고정한다. compiler crash와 RTL 오류를 구분한다.
2. enum 전이에 호환 가능한 if/else 표현을 양쪽 동일하게 적용한다.
3. Contract의 의미 항목을 원문 근거와 연결하고, 파형의 edge 전후 시점과
   추가 latency를 근거 없이 freeze하지 않는다.
4. 동일 단일 Agent 안에서 원문 재검토와 Contract 반례 탐색 단계를 둔다.
   Contract를 따른 oracle만으로 끝내지 않고 원문 파형의 시점도 replay한다.
5. Agent 수·skill·도구 예산을 맞춘 독립 반복 실험을 별도 run에 기록한다.

현재 실험은 독립 모듈의 Contract-first 방식이다. 전체 가속기의 ISA/bank와
모듈 간 Contract 효과 또는 FPGA 성능으로 일반화하지 않는다.

## 근거 자료

- `analysis/disagreement_diagnostics.json`: 원본 소스 진단과 개발 테스트 실행
- `analysis/syntax_only_diagnostics.json`: enum 표현만 바꾼 별도 사본의 공식 테스트
- `analysis/development_failure_probe.json`: 경고 옵션/소스 경로 2×2 진단
- `analysis/timescale_warning_probe.json`: 경고 옵션 추가 확인
- `analysis/development_recompile_audit.json`: 312개 개발 컴파일 원본 옵션 진단
- `analysis/development_warning_fixed_audit.json`: 같은 파일의 경고 옵션 추가 진단

원래 실험 후보, benchmark source, 공식 점수는 변경하지 않았다.
