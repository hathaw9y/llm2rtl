# Design revisions

새 설계는 기존 결과를 덮어쓰지 않고 `designs/<revision>/`에 생성한다.

필수 파일:

```text
model_trace.json
isa_spec.json
bank_layout.json
isa_validation.json
```

현재 구현할 opcode executor가 정해진 뒤에만 `modules/<module_id>.json`을 추가한다.
미래 모듈의 빈 계약을 미리 만들지 않는다. 생성된 RTL·검증·빌드 evidence는 해당
revision 아래 별도 디렉터리에 두고 공통 계약이나 과거 revision을 수정하지 않는다.
