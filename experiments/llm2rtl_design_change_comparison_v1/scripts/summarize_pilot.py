#!/usr/bin/env python3
"""Summarize recorded pilot evidence without changing candidates or evaluators."""
import argparse
import csv
import datetime as dt
import json
from pathlib import Path


def read(path):
    return json.loads(path.read_text()) if path.is_file() else None


def task_result(directory, phase):
    for name in ('result.json', 'report.json'):
        report = read(directory / ('evaluation_' + phase) / name)
        if report is None:
            continue
        if 'functional' in report:
            ok = all(x.get('passed') is True for x in report['functional'])
            if phase == 'public':
                structural = report.get('structural')
                ok = ok and isinstance(structural, dict) and structural.get('passed') is True
            return 'PASS' if ok else 'FAIL'
        if isinstance(report.get('passed'), bool):
            return 'PASS' if report['passed'] else 'FAIL'
        return report.get('status', 'UNKNOWN')
    return 'PENDING'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--storage', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    rows = []
    for task in ('T01', 'T02', 'T03'):
        for condition in ('general_agent', 'llm2rtl'):
            directory = args.storage / 'pilot' / task / condition
            metadata = read(directory / 'status.json') or {}
            usage = metadata.get('usage') or {}
            assets = read(directory / 'evaluation_static_assets/asset_report.json')
            row = {
                'task': task, 'condition': condition,
                'participant_status': metadata.get('status', 'NOT_STARTED'),
                'elapsed_seconds': metadata.get('elapsed_seconds'),
                'public': task_result(directory, 'public'),
                'hidden': task_result(directory, 'hidden'),
                'static_assets': assets.get('status', 'UNKNOWN') if assets else ('PENDING' if task == 'T02' else 'N/A'),
                'expert_guidance_count': metadata.get('expert_guidance_count'),
                'expert_source_edits': metadata.get('expert_source_edits'),
                'input_tokens': usage.get('input_tokens'),
                'cached_input_tokens': usage.get('cached_input_tokens'),
                'output_tokens': usage.get('output_tokens'),
                'tool_item_count': metadata.get('tool_item_count'),
                'common_all_gates': metadata.get('common_all_gates', 'PENDING'),
                'evidence_directory': str(directory),
            }
            rows.append(row)
    result = {
        'generated_utc': dt.datetime.now(dt.timezone.utc).isoformat(),
        'queue': read(args.storage / 'pilot_queue_status.json'),
        'common_supervisor': read(args.storage / 'common_audits/supervisor_status.json'),
        'common_summary': read(args.storage / 'common_audits/summary.json'),
        'trials': rows,
        'scope': 'Six calibration pilots, excluded from the planned 18 main trials. Task-specific PASS does not imply all-gates PASS or FPGA validation.',
        'limitations': [
            'Wall budget was 90 minutes per participant; no enforced token budget.',
            'Resource scope was audited, not protected by an OS-enforced isolation boundary.',
            'Hidden evaluation followed participant completion; no live public-evaluation service was provided.',
            'Recorded elapsed times do not separate model time from tools and environmental waits.',
            'Baseline build and test-harness gaps require qualification before main trials.',
            'No attributable API dollar cost or new physical board evidence is available.',
        ],
    }
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / 'pilot_results.json').write_text(json.dumps(result, indent=2) + '\n')
    with (args.out / 'pilot_results.csv').open('w', newline='') as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    lines = ['# 무개입 설계 변경 예비 실험', '',
             '일반 Agent와 LLM2RTL 조건을 세 변경 과제에서 한 번씩 실행한다. 이 여섯 실행은 본 실험 결과에 포함하지 않는다.', '',
             '| 과제 | 조건 | 실행 상태 | 소요 시간 | 공개 검사 | 비공개 검사 | 전체 정적 자산 |',
             '| --- | --- | --- | --- | --- | --- | --- |']
    for row in rows:
        seconds = row['elapsed_seconds']
        duration = f'{int(seconds // 60)}분 {seconds % 60:.1f}초' if seconds is not None else '진행 중/미실행'
        lines.append(f"| {row['task']} | {row['condition']} | {row['participant_status']} | {duration} | {row['public']} | {row['hidden']} | {row['static_assets']} |")
    lines += ['', '## 결과의 범위', '',
              '과제별 검사는 변경한 기능의 검증이다. 공통 합성·통합·ABI 검토와 실물 보드 검증은 별도 증거가 필요하다. 과제별 PASS만으로 전체 완료를 판정하지 않는다.', '',
              'T01은 8×16 GEMM 배열, T02는 K16 단위 가중치 배치, T03은 GEMM 행 수의 count-minus-one 표현을 평가한다.', '',
              '## 본 실험 전에 해결할 사항', '',
              '- 기준 설계의 빌드와 테스트벤치 문제를 수정하고 다시 검증한다.',
              '- 평가기와 통과 조건을 고정하고 자원 접근을 격리한다.',
              '- 동일한 시간·토큰 예산을 정하고 18회 독립 실행을 시작한다.',
              '- 예비 실험 한 번의 시간 차이를 프레임워크의 우월성으로 해석하지 않는다.', '']
    (args.out / 'pilot_results_ko.md').write_text('\n'.join(lines))
    print(json.dumps({'output': str(args.out), 'queue_stage': (result['queue'] or {}).get('stage')}))


if __name__ == '__main__':
    main()
