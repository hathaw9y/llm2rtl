# 최소 모델→ISA→보드 흐름

기존 module mapping approval과 bringup stage 문서 계층은 사용하지 않는다. 새 흐름은
[PS-issued ISA 아키텍처](isa_model_lowering.md)를 따른다.

```text
정확한 모델 revision·Python source identity
  → model_trace.json
  → Agent가 모델별 opcode·executor 후보와 경계 제안
  → 사용자와 모듈 목록·공유·fusion·PS/PL 책임 논의
  → 논의 결과로 ISA·bank layout 결정
  → isa_spec.json + bank_layout.json
  → Python ISA interpreter
  → isa_validation.json
  → 현재 executor의 구현 방식·golden 검증 기준을 사용자와 논의
  → 합의한 모듈 계약으로 executor 하나 구현·독립 검증
  → 누적 보드 build·사용자 검증
  → 다음 executor도 구현 전에 논의
```

Parent는 Python trace를 따라 semantic operation과 tensor/state 변화를 기록한다. low-level
framework 호출마다 opcode를 만들지 않고 실제 executor module 동작만 opcode로 만든다.
예를 들어 embedding이 token-dependent DMA load라면 별도 `EMBED_LOOKUP` opcode를 만들지
않는다. Q/K/V/O/FFN projection은 하나의 범용 `GEMM` opcode와 다른 설정을 사용한다.

후보 목록에는 지원할 각 semantic operation에서 opcode와 executor로 이어지는 경로,
재사용할 executor, PS에 남기는 일, 아직 지원하지 않는 경로를 표시한다. 이 목록은
Agent의 제안이며 사용자와 모듈 경계를 논의하기 전에는 확정된 ISA나 구현 지시로
취급하지 않는다. 논의에서 정한 사항은 해당 설계 revision에 반영한다.

사용자가 선택해야 하는 fusion, 수치 경계, host/PL state ownership, bank lifetime 같은
사항은 한 항목씩 질문한다. 답이 없으면 `unresolved_decisions`에 남기고 구현을 차단한다.
ISA와 executor 목록에 대한 초기 논의가 각 executor의 구현 방식까지 결정하지는 않는다.
새 executor를 만들 때마다 연산 범위, 포트·완료 응답, bank 접근, 수치 규칙,
성능 목표와 명령별 golden 검증 방법을 별도로 제안하고 사용자와 논의한다.
그 결과를 현재 모듈 계약에 기록한 뒤 RTL을 구현한다.

구조 검사는 다음 두 명령으로 수행한다.

```bash
python3 scripts/check_common_contracts.py
python3 scripts/check_isa_design.py --design-dir designs/<revision>
```

검사기는 선언과 SHA-256 연결을 확인할 뿐 모델 수치 정확도, RTL 또는 보드 동작을 대신
증명하지 않는다.
