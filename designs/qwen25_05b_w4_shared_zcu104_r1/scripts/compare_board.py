#!/usr/bin/env python3
"""Host-only user-returned hardware comparison; never fabricates board evidence."""
import argparse,hashlib,json,re
from pathlib import Path

def digest(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for block in iter(lambda:f.read(1048576),b''):h.update(block)
 return h.hexdigest()
def main():
 p=argparse.ArgumentParser();p.add_argument('--golden',type=Path,required=True);p.add_argument('--dumps',type=Path,required=True);p.add_argument('--uart',type=Path,required=True);p.add_argument('--artifact-manifest',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 if a.output.exists():raise RuntimeError('Use a fresh output path')
 g=json.loads((a.golden/'manifest.json').read_text());art=json.loads(a.artifact_manifest.read_text())
 if art.get('status')!='routed_artifact_handoff':raise ValueError('A routed, matched artifact manifest is required')
 results=[]
 for w in g['workloads']:
  phase=w['phase']
  for suffix,key,size in [('logits','logits_sha256',303872),('KV_valid_prefix','KV_valid_prefix_sha256',24*2*2*w['cache_after']*128)]:
   name=f'{phase}_{suffix}.bin';expected=a.golden/name;actual=a.dumps/name
   if expected.stat().st_size!=size or digest(expected)!=w[key]:raise ValueError('Golden identity mismatch: '+name)
   record={'file':name,'expected_bytes':size,'expected_sha256':w[key],'present':actual.is_file()}
   if actual.is_file():record.update(actual_bytes=actual.stat().st_size,actual_sha256=digest(actual))
   record['passed']=record['present'] and record['actual_bytes']==size and record['actual_sha256']==w[key];results.append(record)
 uart=a.uart.read_text();numbers=[];commands=chunks=0
 for w in g['workloads']:
  commands+=w['commands'];chunks+=w['chunks'];label='prefill2' if w['phase']=='prefill' else 'decode1'
  match=re.search(re.escape(label)+r' DONE commands=(\d+) chunks=(\d+) PL_active_cycles=(\d+) cache_length=(\d+)',uart)
  numbers.append({'phase':w['phase'],'passed':bool(match) and [int(match[1]),int(match[2]),int(match[4])]==[commands,chunks,w['cache_after']] and int(match[3])>0,'reported':match.group(0) if match else None})
 passed=all(x['passed'] for x in results+numbers) and 'HANDOFF_DONE' in uart and 'QWEN ERROR' not in uart
 if art.get('model_load'):
  passed=passed and 'SD_MODEL_SHA256_PASS' in uart and uart.index('SD_MODEL_SHA256_PASS')<uart.find('prefill2 DONE')
 report={'status':'passed_user_returned_prefill2_decode1' if passed else 'failed_or_incomplete_user_returned_run','scope':'User-returned dumps and UART attributed by supplied artifact manifest. No independent physical observation; no long-context or quality acceptance.','artifact_manifest_sha256':digest(a.artifact_manifest),'golden_manifest_sha256':digest(a.golden/'manifest.json'),'UART_sha256':digest(a.uart),'dump_results':results,'UART_results':numbers,'artifact_identity':art,'remaining_limits':['Original BF16 versus W4 quality probe failed','prefill512 KV tolerance failed','decode1024 prefix was reference-seeded; full ISA decode chain unverified']}
 a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(report,indent=2)+'\n');print(report['status']);raise SystemExit(0 if passed else 1)
if __name__=='__main__':main()
