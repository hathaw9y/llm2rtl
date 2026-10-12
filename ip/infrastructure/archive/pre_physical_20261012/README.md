# 물리 정리 전 infrastructure snapshot

`snapshot/`은 물리 정리 전에 사용한 패킷 디렉터리, source 목록, 탐색 링크,
계약·인덱스·TB·history·기존 검증 기록을 원래 repository-relative 구조로 보존한다.
공통 계약과 당시 checker/실행기도 포함한다. 활성 소스는 상위 `bank/datamover/controller/utils`에 있다.

활성 목록에서 제외한 RTL은 다음 8개이다.

- `bank_config_pkg`, `bank_sparse_router`, `bank_subsystem`
- `sparse_isa_dispatcher`, `execution_fabric`
- `mm2s_stream_bank_adapter`, `s2mm_stream_bank_adapter`
- `status_decoder`

앞의 7개는 기존 고정 bank/fabric 예제의 구성이다. `status_decoder`는 현재 엔진에
인스턴스가 없으며, 상태 검사는 `datamover_command_queue`가 수행한다.
기존 generic ownership/router는 다른 설계의 사용처가 있으므로 활성 bank 폴더에 유지했다.

당시 계약의 경로와 해시는 변경하지 않았다. 다음 명령은 이 snapshot의 동결 메타데이터를 검사한다.

```bash
python3 ip/infrastructure/archive/pre_physical_20261012/snapshot/scripts/check_infrastructure_template.py
python3 ip/infrastructure/archive/pre_physical_20261012/snapshot/scripts/check_infrastructure_binding.py
```

복원용 복사본은 별도 디렉터리에 만든다.

```bash
cp -a ip/infrastructure/archive/pre_physical_20261012/snapshot /tmp/infrastructure-before-cleanup
```

`inventory.json`은 보존 작업 당시의 파일 해시 목록이다. `deleted_generated_files.json`은
그중 삭제한 재생성 가능한 XSIM/Icarus 컴파일 산출물과 Python 캐시를 구분한다.
RTL·TB·계약·실패 기록·실행 명령의 compile/elaborate/simulation 로그·소스 snapshot은 보존했다.
XSIM 캐시 안의 kernel/crash debug 로그는 재생성 산출물 삭제 목록에 포함한다.
과거 보고서는 당시 소스와 도구에 대한 기록이며, 새 배치의 signoff 결과로 재사용하지 않는다.
