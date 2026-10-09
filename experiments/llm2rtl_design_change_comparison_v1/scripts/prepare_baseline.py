#!/usr/bin/env python3
"""Create content-addressed study inputs without modifying the working design."""
from pathlib import Path
import argparse,hashlib,json,shutil,datetime
p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);a=p.parse_args()
repo=Path(__file__).resolve().parents[3]
design=repo/'designs/smollm2_135m_bf16_zcu104_r1'
snapshot=a.out/'baseline';snapshot.mkdir(parents=True,exist_ok=True)
roots=[design,repo/'contracts/common',repo/'ip/infrastructure',repo/'verification/prototypes',repo/'docs']
allowed={'.sv','.v','.svh','.mem','.hex','.py','.sh','.tcl','.c','.h','.json','.md','.xdc'}
excluded={'artifacts','build','evidence','resource_analysis','__pycache__','.Xil'}
records=[]
for root in roots:
 for src in sorted(root.rglob('*')):
  if not src.is_file() or excluded.intersection(src.relative_to(root).parts):continue
  if src.suffix not in allowed:continue
  if src.is_symlink():continue
  rel=src.relative_to(repo)
  dst=snapshot/rel;dst.parent.mkdir(parents=True,exist_ok=True)
  sha=hashlib.sha256(src.read_bytes()).hexdigest()
  if dst.exists():assert hashlib.sha256(dst.read_bytes()).hexdigest()==sha,rel
  else:shutil.copy2(src,dst)
  records.append({'path':str(rel),'sha256':sha,'bytes':src.stat().st_size})
assets=['full_model_board_probe/ddr_static_bf16.bin']
for asset in assets:
 src=design/asset;rel=src.relative_to(repo);dst=snapshot/rel
 sha=hashlib.sha256(src.read_bytes()).hexdigest()
 if not dst.exists():shutil.copy2(src,dst)
 assert hashlib.sha256(dst.read_bytes()).hexdigest()==sha
 records.append({'path':str(rel),'sha256':sha,'bytes':src.stat().st_size})
manifest={'created_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source':str(repo),'snapshot':str(snapshot),'notes':'Original files copied; no Git commit/mtime used as identity. Snapshot must be hash-checked before every trial. Source includes contracts/interpreter for both conditions. Old skills excluded.','files':records}
(a.out/'baseline_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps({'snapshot':str(snapshot),'files':len(records),'bytes':sum(x['bytes'] for x in records)},indent=2))
