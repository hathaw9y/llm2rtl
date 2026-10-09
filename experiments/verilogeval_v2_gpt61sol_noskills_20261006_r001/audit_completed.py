"""Verify completed result identities and aggregation without rerunning generation."""
from pathlib import Path
import json,hashlib,csv
ROOT=Path(__file__).resolve().parent
manifest=json.loads((ROOT/'run_manifest.json').read_text())
assert manifest['status']=='completed'
expected={(j['mode'],j['problem_id']) for j in manifest['jobs']}
assert len(expected)==312
issues=[]; checks=0; records={}
def check(path,expected_hash,label):
 global checks
 checks+=1
 if not path.exists() or hashlib.sha256(path.read_bytes()).hexdigest()!=expected_hash:issues.append({'file':str(path),'reason':label})
for j in manifest['jobs']:
 d=Path(j['directory']);r=json.loads((d/'run_result.json').read_text());records[(j['mode'],j['problem_id'])]=r
 check(d/'problem.txt',manifest['prompt_sha256'][j['problem_id']],'prompt')
 check(d/'policy.txt',manifest['policy_sha256'][j['mode']],'policy')
 for n,h in manifest['helper_sha256'].items():check(d/n,h,'helper')
 for stage in ['initial','final']:
  e=r[stage];packet=ROOT/'evaluation'/j['mode']/j['problem_id']/stage
  for n,h in e['file_sha256'].items():check(packet/n,h,'evaluated_source')
  saved=json.loads((packet/'result.json').read_text())
  if saved!=e:issues.append({'file':str(packet/'result.json'),'reason':'saved verdict differs from run result'})
  check(d/('candidate_initial.sv' if stage=='initial' else 'candidate.sv'),e['file_sha256']['candidate.sv'],'generation vs evaluation')
 dev=[json.loads(line) for line in (d/'dev_checks.jsonl').read_text().splitlines()]
 for c in dev:
  packet=Path(c['directory'])
  check(packet/'candidate.sv',c['source_sha256'],'development RTL')
  check(packet/'dev_tb.sv',c['testbench_sha256'],'development TB')
 if j['mode']=='contract_based':
  gate=json.loads((d/'contract_gate.json').read_text());check(d/'contract.json',gate['contract_sha256'],'contract')
 if r['protocol_issues']:issues.append({'job':[j['mode'],j['problem_id']],'reason':'protocol issues','details':r['protocol_issues']})
with (ROOT/'results.csv').open() as f:rows=list(csv.DictReader(f))
keys=[(x['mode'],x['problem_id']) for x in rows]
assert set(keys)==expected and len(keys)==len(expected)
for row in rows:
 r=records[(row['mode'],row['problem_id'])]
 for field in ['official_status','workflow_status','development_status']:
  if row[field]!=r[field]:issues.append({'job':[row['mode'],row['problem_id']],'reason':'CSV status differs','field':field})
 if row['initial_status']!=r['initial']['status']:issues.append({'job':[row['mode'],row['problem_id']],'reason':'CSV initial status differs'})
summary=json.loads((ROOT/'summary.json').read_text())
assert summary['completed_jobs']==312
for arm in manifest['conditions']:
 subset=[r for (mode,n),r in records.items() if mode==arm]
 assert len(subset)==156
 for metric,actual in [('official_passed',sum(r['official_status']=='passed' for r in subset)),('initial_passed',sum(r['initial']['status']=='passed' for r in subset)),('workflow_passed',sum(r['workflow_status']=='passed' for r in subset))]:
  assert summary['conditions'][arm][metric]==actual
analyzer=Path('/tmp/llm2rtl_verilogeval_20260930/scripts/sv-iv-analyze')
check(analyzer,manifest['official_analyzer_sha256'],'pinned official analyzer')
access=json.loads((ROOT/'no_skills_audit.json').read_text())
assert access['status']=='passed' and not access['observed_skill_access_commands']
report={'status':'passed' if not issues else 'failed','completed_jobs':312,'hash_checks':checks,'issues':issues,'csv_job_set_matches':True,'summary_counts_match':True,'observed_skill_access_commands':0,'source_changed_by_audit':False,'generation_rerun':False,'scope':'Artifact identity, transcript access and aggregate audit. Does not establish correctness of the generated development oracle or of ambiguous original specifications.'}
(ROOT/'completion_audit.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
assert not issues
