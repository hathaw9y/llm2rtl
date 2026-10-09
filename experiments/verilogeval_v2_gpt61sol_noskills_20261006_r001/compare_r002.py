"""Compare completed no-Skills results with historical r002; never alter scores."""
from pathlib import Path
import json,statistics,re
ROOT=Path(__file__).resolve().parent
OLD=ROOT.parent/'verilogeval_v2_gpt61sol_full_20260930_r002'
manifest=json.loads((ROOT/'run_manifest.json').read_text())
completed={}
for job in manifest['jobs']:
 p=Path(job['directory'])/'run_result.json'
 if p.exists():completed[(job['mode'],job['problem_id'])]=json.loads(p.read_text())
result={'completed_jobs':len(completed),'total_jobs':len(manifest['jobs']),'complete':len(completed)==len(manifest['jobs']),'conditions':{},'paired_outcomes':{},'scope':'One new sample per task per arm. Retains historical prompts/evaluator including known inconsistencies. Diagnostic copies do not alter scores. Historical runtime differences and fresh generation variability prevent causal attribution to Skills alone.'}
invalid=set(json.loads((ROOT/'benchmark_validity.json').read_text())['invalid_problems'])
for arm in manifest['conditions']:
 selected=[r for (mode,name),r in completed.items() if mode==arm]
 improved=[]; regressed=[]; initial_improved=[]; initial_regressed=[]; final_failed=[]
 syntax={key:0 for key in ['always_ff','always_comb','logic','reg','wire','typedef enum']}
 compile_crashes=0; dev_failed=0
 for r in selected:
  n=r['problem_id']; d=ROOT/'generation'/arm/n
  old=json.loads((OLD/'generation'/arm/n/'run_result.json').read_text())
  a=old['official_status']=='passed'; b=r['official_status']=='passed'
  if b and not a:improved.append(n)
  if a and not b:regressed.append(n)
  a=old['initial']['status']=='passed' if old['initial'] else False
  b=r['initial']['status']=='passed' if r['initial'] else False
  if b and not a:initial_improved.append(n)
  if a and not b:initial_regressed.append(n)
  if r['official_status']!='passed':final_failed.append({'problem_id':n,'status':r['official_status'],'reference_passes':n not in invalid})
  text=(d/'candidate.sv').read_text() if (d/'candidate.sv').exists() else ''
  for key in syntax:
   syntax[key]+=bool(re.search(r'\b'+re.escape(key)+r'\b',text))
  for line in (d/'dev_checks.jsonl').read_text().splitlines() if (d/'dev_checks.jsonl').exists() else []:
   check=json.loads(line);dev_failed+=check['status']!='passed';compile_crashes+=check['compile'].get('returncode') in [139,-11]
 result['conditions'][arm]={'completed':len(selected),'official_passed':sum(r['official_status']=='passed' for r in selected),'initial_passed':sum(r['initial'] is not None and r['initial']['status']=='passed' for r in selected),'final_rate':sum(r['official_status']=='passed' for r in selected)/156 if len(selected)==156 else None,'mean_generation_seconds':statistics.mean(r['generation']['seconds'] for r in selected) if selected else None,'median_generation_seconds':statistics.median(r['generation']['seconds'] for r in selected) if selected else None,'revised_tasks':sum((r.get('revision_count') or 0)>0 for r in selected),'reported_rtl_revisions':sum(r.get('revision_count') or 0 for r in selected),'development_failed_checks':dev_failed,'development_compile_crashes':compile_crashes,'final_source_construct_task_counts':syntax,'final_improved_vs_r002':improved,'final_regressed_vs_r002':regressed,'initial_improved_vs_r002':initial_improved,'initial_regressed_vs_r002':initial_regressed,'final_failed':final_failed}
for n in manifest['problems']:
 a=completed.get(('single_agent',n));b=completed.get(('contract_based',n))
 if a and b:
  ap=a['official_status']=='passed';bp=b['official_status']=='passed'
  key='both_pass' if ap and bp else 'single_only' if ap else 'contract_only' if bp else 'both_fail'
  result['paired_outcomes'].setdefault(key,[]).append(n)
(ROOT/'comparison_r002.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ['conditions','paired_outcomes']},ensure_ascii=False))
