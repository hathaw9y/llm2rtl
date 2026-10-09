# 무개입 설계 변경 예비 실험

일반 Agent와 LLM2RTL 조건을 세 변경 과제에서 한 번씩 실행한다. 이 여섯 실행은 본 실험 결과에 포함하지 않는다.

| 과제 | 조건 | 실행 상태 | 소요 시간 | 공개 검사 | 비공개 검사 | 전체 정적 자산 |
| --- | --- | --- | --- | --- | --- | --- |
| T01 | general_agent | PARTICIPANT_ENDED | 42분 20.4초 | PASS | PASS | N/A |
| T01 | llm2rtl | PARTICIPANT_ENDED | 25분 47.1초 | PASS | PASS | N/A |
| T02 | general_agent | PARTICIPANT_ENDED | 28분 34.5초 | PASS | PASS | PASS |
| T02 | llm2rtl | PARTICIPANT_ENDED | 32분 38.3초 | PASS | PASS | PASS |
| T03 | general_agent | PARTICIPANT_ENDED | 33분 37.5초 | PASS | PASS | N/A |
| T03 | llm2rtl | PARTICIPANT_ENDED | 30분 43.9초 | PASS | PASS | N/A |

## 결과의 범위

과제별 검사는 변경한 기능의 검증이다. 공통 합성·통합·ABI 검토와 실물 보드 검증은 별도 증거가 필요하다. 과제별 PASS만으로 전체 완료를 판정하지 않는다.

T01은 8×16 GEMM 배열, T02는 K16 단위 가중치 배치, T03은 GEMM 행 수의 count-minus-one 표현을 평가한다.

## 본 실험 전에 해결할 사항

- 기준 설계의 빌드와 테스트벤치 문제를 수정하고 다시 검증한다.
- 평가기와 통과 조건을 고정하고 자원 접근을 격리한다.
- 동일한 시간·토큰 예산을 정하고 18회 독립 실행을 시작한다.
- 예비 실험 한 번의 시간 차이를 프레임워크의 우월성으로 해석하지 않는다.
