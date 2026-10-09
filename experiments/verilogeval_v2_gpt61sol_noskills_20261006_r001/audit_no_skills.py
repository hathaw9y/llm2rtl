"""Audit preserved experiment evidence without changing generated candidates."""
from pathlib import Path
import json,hashlib,re,statistics
ROOT=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
manifest=json.loads((ROOT/'run_manifest.json').read_text())
issues=[]; completed=[]; tool_commands=0; skill_commands=[]; skill_exclusions=[]; revisions=[]
for job in manifest['jobs']:
 d=Path(job['directory'])
 if sha(d/'problem.txt')!=manifest['prompt_sha256'][job['problem_id']]:issues.append([job['mode'],job['problem_id'],'prompt_changed'])
 if sha(d/'policy.txt')!=manifest['policy_sha256'][job['mode']]:issues.append([job['mode'],job['problem_id'],'policy_changed'])
 path=d/'run_result.json'
 if not path.exists():continue
 result=json.loads(path.read_text());completed.append(result)
 for name in ['dev_check.py','smoke_environment.py']:
  if sha(d/name)!=manifest['helper_sha256'][name]:issues.append([job['mode'],job['problem_id'],'helper_changed',name])
 if result.get('final_source_sha256') and sha(d/'candidate.sv')!=result['final_source_sha256']:issues.append([job['mode'],job['problem_id'],'final_rtl_changed'])
 if result['initial'] and sha(d/'candidate_initial.sv')!=result['initial']['file_sha256']['candidate.sv']:issues.append([job['mode'],job['problem_id'],'initial_rtl_changed'])
 if result['protocol_issues']:issues.append([job['mode'],job['problem_id'],'protocol',result['protocol_issues']])
 for line in (d/'events.jsonl').read_text().splitlines():
  try:e=json.loads(line)
  except ValueError:continue
  item=e.get('item',{})
  if item.get('type')=='command_execution' and e.get('type')=='item.completed':
   tool_commands+=1
   command=item.get('command','')
   if re.search(r'SKILL\.md|/skills/|skills\.(?:read|list)',command):
    record={'mode':job['mode'],'problem_id':job['problem_id'],'command':command}
    without_exclusions=re.sub(r'!\*\*/SKILL\.md|!SKILL\.md','',command)
    if 'rg --files' in command and not re.search(r'SKILL\.md|/skills/|skills\.(?:read|list)',without_exclusions):
     skill_exclusions.append(record)
    else:skill_commands.append(record)
 if result.get('revision_count',0):revisions.append({'mode':job['mode'],'problem_id':job['problem_id'],'reported_revisions':result['revision_count'],'observed_revisions':result['observed_checked_rtl_revisions'],'initial_status':result['initial']['status'] if result['initial'] else None,'final_status':result['official_status'],'reasons':result.get('worker_report',{}).get('justified_rtl_changes',[])})
conditions={}
for arm in manifest['conditions']:
 selected=[r for r in completed if r['mode']==arm]
 conditions[arm]={'completed':len(selected),'official_passed':sum(r['official_status']=='passed' for r in selected),'initial_passed':sum(r['initial'] is not None and r['initial']['status']=='passed' for r in selected),'workflow_passed':sum(r['workflow_status']=='passed' for r in selected),'development_passed':sum(r['development_status']=='passed' for r in selected),'mean_generation_seconds':statistics.mean(r['generation']['seconds'] for r in selected) if selected else None,'revised_tasks':sum((r.get('revision_count') or 0)>0 for r in selected),'rtl_revisions_total':sum(r.get('revision_count') or 0 for r in selected)}
audit={'status':'failed' if issues or skill_commands else 'passed' if len(completed)==len(manifest['jobs']) else 'partial','completed_jobs':len(completed),'total_jobs':len(manifest['jobs']),'conditions':conditions,'issues':issues,'tool_commands_examined':tool_commands,'observed_skill_access_commands':skill_commands,'skill_file_listing_exclusions':skill_exclusions,'revision_records':revisions,'scope':'Transcript-based access audit; no claim of hard filesystem isolation. Scores follow the unchanged original official evaluator, not post-hoc diagnostic repairs.'}
(ROOT/'no_skills_audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v for k,v in audit.items() if k not in ['revision_records','observed_skill_access_commands','skill_file_listing_exclusions']},ensure_ascii=False,indent=2))
