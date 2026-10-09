#!/usr/bin/env python3
"""Audit actual static images against an evaluator-owned baseline region map."""
import argparse,array,hashlib,json,sys
from pathlib import Path
E=Path(__file__).resolve().parents[1]/'evaluator/t02';sys.path.insert(0,str(E));from oracle import pack,NEW,OLD
p=argparse.ArgumentParser();p.add_argument('--candidate-root',type=Path,required=True);p.add_argument('--out',type=Path,required=True);p.add_argument('--baseline-mode',action='store_true');p.add_argument('--reference-image',type=Path,required=True);p.add_argument('--reference-map',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
r={'task':'T02_static_assets','checks':[],'limitations':['Map/image correctness only; PS command stream and interpreter execution require separate gates.']}
try:
 reference=json.loads(a.reference_map.read_text());candidate=json.loads((a.candidate_root/'t02_asset_map.json').read_text())
 image=(a.candidate_root/candidate['image']).resolve();assert image.is_relative_to(a.candidate_root.resolve()),'image outside candidate'
 assert candidate['layout_id']==(OLD if a.baseline_mode else NEW)
 hasher=hashlib.sha256()
 with image.open('rb') as img:
  for chunk in iter(lambda:img.read(1024*1024),b''):hasher.update(chunk)
 assert candidate['image_sha256']==hasher.hexdigest(),'image hash'
 ref_entries=reference['regions'];entries={x['name']:x for x in candidate['regions']};assert len(entries)==len(candidate['regions'])
 assert set(entries)=={x['name'] for x in ref_entries},'region coverage'
 ref_intervals=[];dst_intervals=[]
 with a.reference_image.open('rb') as rf,image.open('rb') as cf:
  for expected in ref_entries:
   entry=entries[expected['name']];size=expected['size_bytes'];offset=entry['offset_bytes']
   assert offset%16==0 and offset>=0 and offset+size<=image.stat().st_size,'image bounds/alignment'
   assert entry['size_bytes']==size,'size changed/padding introduced'
   if expected['kind']=='dense':
    n,k=expected['n_tile'],expected['k'];assert size==2*n*k
    assert entry['n_tile']==n and entry['k']==k
   rf.seek(expected['offset_bytes']);raw=rf.read(size);assert len(raw)==size
   cf.seek(offset);actual=cf.read(size);assert len(actual)==size
   if expected['kind']=='dense' and not a.baseline_mode:
    words=array.array('H');words.frombytes(raw)
    if sys.byteorder!='little':words.byteswap()
    packed=array.array('H',pack([words[i*k:(i+1)*k] for i in range(n)]))
    if sys.byteorder!='little':packed.byteswap()
    assert actual==packed.tobytes(),f'dense image packing differs: {entry["name"]}'
   else:assert actual==raw,f'untouched asset differs: {entry["name"]}'
   assert candidate['ddr_base']+offset+size<=candidate['reserved_end'],'reserved DDR bound'
   ref_intervals.append((expected['offset_bytes'],expected['offset_bytes']+size))
   dst_intervals.append((offset,offset+size,expected['name']))
   r['checks'].append({'region':entry['name'],'kind':expected['kind'],'bytes':size,'status':'PASS'})
 # Evaluator map must cover all original static bytes. LM head may overlap embedding in reference.
 covered=0
 for start,end in sorted(ref_intervals):
  assert start<=covered,'reference map has uncovered bytes';covered=max(covered,end)
 assert covered==a.reference_image.stat().st_size,'reference map incomplete'
 if not a.baseline_mode:
  end=0
  for start,stop,name in sorted(dst_intervals):assert start>=end,f'overlapping target regions: {name}';end=stop
 r['status']='PASS';r['candidate_image_sha256']=candidate['image_sha256'];r['reference_map_sha256']=hashlib.sha256(a.reference_map.read_bytes()).hexdigest()
except Exception as e:r['status']='FAIL';r['error']=str(e)
(a.out/'asset_report.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r,indent=2));sys.exit(0 if r['status']=='PASS' else 1)
