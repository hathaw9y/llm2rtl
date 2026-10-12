#!/usr/bin/env python3
"""Rebuild narrow reports from the closed run005_final raw evidence."""
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'evidence/striped_weight_bank'
RUN = OUT/'run005_final'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write(name, value):
    (OUT/name).write_text(json.dumps(value, indent=2, ensure_ascii=False)+'\n')


def main():
    result = json.loads((RUN/'result.json').read_text())
    manifest = json.loads((RUN/'source_manifest.json').read_text())
    assert result['protected_files_unchanged'] and result['source_files_unchanged_during_run']
    assert all(sha(path) == digest for path, digest in manifest['protected'].items())
    assert all(sha(path) == digest for path, digest in result['sources'].items())
    assert all(case['passed'] for case in result['simulation'])
    assert result['lint']['passed'] and result['synthesis']['passed']
    for path, digest in result['sources'].items():
        assert sha(RUN/'source_snapshot'/Path(path).name) == digest
    for previous in ['run001_sim', 'run001_lint']:
        first = OUT/previous
        old_manifest = json.loads((first/'source_manifest.json').read_text())
        for path, digest in old_manifest['sources'].items():
            assert sha(first/'source_snapshot'/Path(path).name) == digest

    reports = RUN/'ooc_reports'
    utilization = (reports/'utilization.rpt').read_text()
    resources = {}
    names = {'CLB LUTs*':'lut', 'CLB Registers':'ff', 'DSPs':'dsp', 'URAM':'uram', 'Block RAM Tile':'bram_36k', 'Bonded IOB':'io'}
    for name, key in names.items():
        row = re.search(r'^\|\s*'+re.escape(name)+r'\s*\|\s*(\d+)\s*\|', utilization, re.M)
        assert row, name
        resources[key] = int(row.group(1))
    summary = (reports/'timing_summary.rpt').read_text()
    timing_values = None
    for line in summary.splitlines():
        values = line.split()
        if len(values) == 12 and all(re.fullmatch(r'-?\d+(?:\.\d+)?', value) for value in values):
            timing_values = values
            break
    assert timing_values is not None
    timing = dict(zip(['wns_ns','tns_ns','setup_failing_endpoints','setup_total_endpoints','whs_ns','ths_ns','hold_failing_endpoints','hold_total_endpoints','wpws_ns','tpws_ns','pulse_width_failing_endpoints','pulse_width_total_endpoints'], map(float,timing_values)))
    for key in list(timing):
        if key.endswith('endpoints'): timing[key] = int(timing[key])
    timing.update(stage='post_synthesis', target_period_ns=5.0, target_clock_mhz=200.0,
                  passed=timing['wns_ns']>=0 and timing['whs_ns']>=0 and timing['wpws_ns']>=0,
                  false_paths_applied=False,
                  failing_path='enb_i -> g_pipelined_visibility.read_valid_pipe_r_reg[0]/D',
                  input_timing_context='OOC input delay max0.5ns/min0ns, unplaced netlist with external HD.CLK_SRC estimate',
                  board_signoff=False)
    drc = (reports/'drc.rpt').read_text()
    methodology = (reports/'methodology.rpt').read_text()
    assert 'Checks found: 0' in drc and 'Checks found: 0' in methodology
    positive = [case for case in result['simulation'] if not case['case'].get('expected_parameter_failure')]
    negative = [case for case in result['simulation'] if case['case'].get('expected_parameter_failure')]
    counts = {key:sum(case['counts'][key] for case in positive) for key in ['checks','reads','writes','cycles']}
    measured = {'simulation_positive_cases':len(positive), 'simulation_parameter_negative_cases':len(negative),
                'counts':counts, 'simulation_all_cases_passed':True,
                'strict_leaf_lint_passed':True, 'actual_vendor_xpm_verilator_lint':'unsupported_deassign_blocked',
                'ooc_mapping_passed':True, 'resources':resources, 'timing':timing,
                'drc_checks_found':0, 'methodology_checks_found':0, 'black_boxes':0,
                'protected_files_unchanged':True, 'closed_snapshot_hashes_match':True}
    limitations = ['Functional depth16; OOC synthesis depth16384. No exhaustive16K-row simulation.',
                  'Post-synthesis hold -0.007ns at1endpoint; no placement/routing or board timing claim.',
                  'Actual XPM XSIM uses vendor models; Verilator5.020 cannot lint vendor deassign. Strict leaf/common-URAM lint uses exact declaration-only XPM stub.',
                  'Quantization, scales, real checkpoint layout, four DMA wiring, complete bank pool, consumer/ISA integration and full-model quality remain outside this leaf.']
    ooc = dict(result['synthesis'], resources=resources, timing=timing, drc_checks_found=0,
               methodology_checks_found=0, resource_assessment='timing_limited',
               logical_storage_bits=4*128*16384, uram_per_stripe=8, device_uram=96,
               device_uram_fraction=32/96, full_accelerator_fit_claim=False,
               report_sha256={str(path):sha(path) for path in reports.iterdir() if path.is_file()})
    write('module_ooc_synthesis_report.json',ooc)
    kernel = dict(schema='llm2rtl.kernel_report.v1',module='smollm2_striped_weight_bank',
                  coverage_level='target_storage_leaf', synthetic_fixture=False,
                  status='functional_and_ooc_mapping_verified_timing_at_risk', integration_ready=False,
                  common_handshake='Explicit native memory contract overrides generic start_i/done_o kernel ports.',
                  latency_clocks=3, tested_read_latencies=[1,2,3], initiation_interval=1,
                  write_bytes_per_cycle_max=64, read_bytes_per_cycle=64,
                  bank_interface_only=True, true_parallel_write_stripes=4,
                  hardware=dict(board='AMD ZCU104',part='xczu7ev-ffvc1156-2-e',clock_period_ns=5.0),
                  numeric_arithmetic=False, real_checkpoint_layout_compatible=False,
                  packed_nibble_round_trip_passed=True, pattern_has_distinct_64bit_halves=True,
                  measured=measured, simulation=result['simulation'], verilator=result['lint'],
                  ooc_synthesis_report=str(OUT/'module_ooc_synthesis_report.json'),
                  source_hashes=result['sources'], limitations=limitations)
    write('kernel_report.json',kernel)
    failures = [dict(run='run001_sim',kind='design_defect',symptom='XPM stale pre-reset response reappears after reset release',
                     preserved_source_sha256='e15a8fded31773218655df2f501dd1fa194a4d35933191eda44c2bbe76d563dd',
                     repair='Latency-aligned post-reset fresh-read visibility mask in new leaf; primitive unchanged'),
                dict(run='run001_lint',kind='tool_limitation',symptom='Verilator5.020 unsupported vendor deassign',
                     repair='No vendor edit; actual-XPM simulation/OOC plus separately labelled strict leaf lint with exact declaration-only XPM stub'),
                dict(run='run002_lint',kind='vendor_boundary_width_warning',symptom='64bit immutable uram MEMORY_SIZE constant binds signed32bit XPM parameter',
                     repair='Only exact declaration stub line7 WIDTHTRUNC waiver; default2,097,152bits is within signed32bit range'),
                dict(run='run005_final/ooc_reports',kind='timing_failure',symptom='Post-synth hold -0.007ns, 1endpoint',repair=None)]
    changed = [ROOT/'rtl/smollm2_striped_weight_bank.sv',ROOT/'tb/tb_smollm2_striped_weight_bank.sv',ROOT/'scripts/run_striped_weight_bank.py',ROOT/'scripts/striped_weight_bank_ooc.tcl',ROOT/'scripts/striped_bank_reference.py',ROOT/'scripts/write_striped_weight_bank_report.py',ROOT/'scripts/lint/xpm_memory_sdpram.sv',ROOT/'scripts/lint/declaration_lint.vlt',ROOT/'contracts/striped_weight_bank_rtl_binding.json']
    subagent = dict(schema='llm2rtl.subagent_result.v1',task_id='smol_w4a4kv4_striped_weight_bank',
                    status=kernel['status'], parent_contract_unchanged=True, paid_model_calls=0,
                    changed_files=[str(path) for path in changed], evidence=str(OUT), measured=measured,
                    actual_commands={'simulation':[case['commands'] for case in result['simulation']],
                                     'lint':result['lint']['command'],'synthesis':result['synthesis']['command']},
                    failure_history=failures, final_source_hashes=result['sources'], remaining_risks=limitations,
                    skill_update_candidate=[dict(skill='fpga-systemverilog + fpga-vivado',failing_command=result['simulation'][0]['commands'][-1]['command'],
                       preserved_log=str(OUT/'run001_sim/sim/ports4_lat3/simulate.log'),
                       symptom='XPM reset of final output register does not flush earlier pipeline state; stale output reappears with read enable disabled.',
                       root_cause_hypothesis='Installed XPM model retains intermediate read data and regceb=1 lets it reach output after reset deassertion.',
                       prevention_rule='For vendor memory wrappers, dynamically test reset with a read in flight and idle after reset; gate externally visible output until a fresh post-reset response matures when the wrapper contract promises a pipeline flush.',
                       minimal_regression='Issue one read, reset before maturity, deassert reset with enb=0, check zero until first fresh read appears at exactly READ_LATENCY.')])
    write('subagent_result.json',subagent)
    lines = [f'# Smol W4A4KV4 striped weight bank leaf 검증\n',
             '새 revision에 4개 독립128-bit 쓰기와 공통주소512-bit 읽기 bank를 구현했다. 원본 저장소와 공통 `uram_bank`는 변경하지 않았다. 숫자 양자화·전체 모델 구현은 이번 범위에 포함하지 않았다.\n',
             '| 항목 | 실제 결과 |','|---|---|',
             f'| Actual XPM XSIM | 정상 case {len(positive)}개 PASS, 불법주소폭 expected fatal {len(negative)}개 확인 |',
             f'| 동적 검사 | {counts["checks"]} checks, {counts["reads"]} read responses, {counts["writes"]} accepted stripe writes |',
             '| Strict leaf lint | PASS. actual leaf + immutable URAM + declaration-only XPM. 실제 vendor 전체 lint는 deassign 미지원 |',
             '| Default OOC | Vivado2025.2, xczu7ev-ffvc1156-2-e, depth16384, 5ns, blackbox0 |',
             f'| 자원 | LUT{resources["lut"]}, FF{resources["ff"]}, DSP0, BRAM0, URAM{resources["uram"]}(stripe당8개; device96개 중33.33%) |',
             '| 합성 단계 timing | WNS+2.362ns, WHS−0.007ns(1endpoint), WPWS+1.800ns. Timing FAIL |',
             '| DRC / Methodology | OOC 검사에서 각각0개. 모든 board-level DRC를 수행한 결과가 아님 |\n',
             'Commit은 각 stripe의 full-strobe 연속 완료 prefix 중 최소값이다. Hole·partial·older rewrite는 prefix를 과장하지 않는다. Counter는 ADDR_WIDTH+1이며 전체 native 주소공간의 마지막 row에서도 DEPTH를 표현한다. Reset과 clear는 writes를 차단하고 memory를 보존한다. Clear는 read pipeline을 유지한다. Reset 이후에는 latency-aligned fresh-read mask로 잔류 응답을 숨긴다.\n',
             '필수 사례: 4개 서로 다른 write주소, byte masks/zero strobe, 첫·마지막 row, high-bit alias 억제, LAT1/2/3, II1 reads, disabled hold, read_first collision, unequal progress, skipped-row replay, clear/reset와 in-flight read. PORT_COUNT1/3/4와 ADDR_WIDTH4/32를 실행했다. Functional depth는16이며 실제 depth16384는 합성으로 확인했다.\n',
             '첫 reset failure와 actual-vendor lint failure는 run001 폴더 및 source_snapshot에 보존했다. 초기 RTL은 저장된 해시와 일치하는 bytes로 복원했다. run002~004는 중간 진단으로 보존했으며 최종 payload/lane 근거는 각64-bit half가 다른 패턴의 run005_final이다.\n',
             'Post-synth hold 실패는 `enb_i`에서 visibility pipe 입력까지의 unplaced I/O 경로다. Input delay max0.5/min0ns를 적용했고 false-path는 추가하지 않았다. 배치·배선 전 결과이며 integration-ready 또는 200MHz board timing PASS로 승격하지 않는다.\n',
             '사용한 lint waiver는 stub의 UNUSEDPARAM/UNUSEDSIGNAL/UNDRIVEN, 공통 URAM line69의 미사용 ECC PINCONNECTEMPTY, stub MEMORY_SIZE line7의 WIDTHTRUNC뿐이다. 실제 leaf의 warning은 억제하지 않았다. MEMORY_SIZE default2,097,152bits는 signed32bit 범위 안이다.\n',
             '재실행(새 run-id 필수):\n',
             '```sh',f'python {ROOT}/scripts/run_striped_weight_bank.py --run-id new_run --phase all',
             f'python {ROOT}/scripts/run_striped_weight_bank.py --run-id new_lat1 --phase sim --case ports4_lat1','```\n',
             '이 bank는 opaque INT4 packing 저장만 검증했다. Scale metadata, 수치 reference, checkpoint packing, 네 DMA 채널 연결, bank pool/consumer/ISA, 전체 Smol, routed timing·BIT·board 동작은 미검증이다.\n',
             '측정과 raw 명령은 `kernel_report.json`, `module_ooc_synthesis_report.json`, `subagent_result.json`, `run005_final/result.json`을 확인한다.']
    (OUT/'REPORT_KO.md').write_text('\n'.join(lines)+'\n')
    print(json.dumps({'reports':str(OUT),'measured':measured},indent=2))


if __name__ == '__main__':
    main()
