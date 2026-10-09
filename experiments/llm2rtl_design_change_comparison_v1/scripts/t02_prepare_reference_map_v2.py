#!/usr/bin/env python3
"""Evaluator v2 supplement: derive immutable actual image inventory from frozen C/header/manifest."""
import argparse,hashlib,json,re,shutil,subprocess,sys
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--baseline-root',type=Path,required=True);p.add_argument('--baseline-manifest',type=Path,required=True);p.add_argument('--out',type=Path,required=True);p.add_argument('--auditor',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
def sha(path):
 h=hashlib.sha256()
 with path.open('rb') as f:
  for chunk in iter(lambda:f.read(1024*1024),b''):h.update(chunk)
 return h.hexdigest()
design=Path('designs/smollm2_135m_bf16_zcu104_r1/full_model_board_probe');D=a.baseline_root/design
snapshot=json.loads(a.baseline_manifest.read_text());identities={x['path']:x for x in snapshot['files']}
files=['manifest.json','address_map.h','program.c','ddr_static_bf16.bin'];source={}
for name in files:
 path=D/name;identity=identities[str(design/name)];actual=sha(path)
 assert actual==identity['sha256'] and path.stat().st_size==identity['bytes'],f'snapshot identity: {name}'
 source[name]={'path':str(path.resolve()),'sha256':actual,'bytes':path.stat().st_size}
manifest=json.loads((D/'manifest.json').read_text());header=(D/'address_map.h').read_text();program=(D/'program.c').read_text()
def number(token):return int(re.sub(r'[uUlL]+$','',token),0)
def macro(name):
 match=re.search(r'^#define\s+'+re.escape(name)+r'\s+(0x[0-9a-fA-F]+|\d+)u?',header,re.M);assert match,name
 return number(match.group(1))
base=macro('MODEL_DDR_BASE');size=macro('MODEL_DDR_STATIC_BYTES');end=macro('MODEL_DDR_END')
assert manifest['ddr_base']==base and manifest['ddr_static_bytes']==size and manifest['ddr_static_sha256']==source['ddr_static_bf16.bin']['sha256']
assert size==source['ddr_static_bf16.bin']['bytes'] and size==269161088
assert source['ddr_static_bf16.bin']['sha256']=='7439dd37925be3ba6c3ef6853b1728d836c6bdda13d7bbbcc93f7966bd745c68'
enum=re.search(r'enum\s*\{([^}]+)\}',header).group(1);names=[x.strip() for x in enum.split(',')]
block=re.search(r'layer_weight_base\[(\d+)\]\[(\d+)\]\s*=\s*\{(.*?)\n\};',header,re.S);assert block
layers=int(block.group(1));assert int(block.group(2))==len(names)
bases=[[number(x) for x in re.findall(r'0x[0-9a-fA-F]+u?',row)] for row in re.findall(r'\{([^}]+)\}',block.group(3))];assert len(bases)==layers and all(len(x)==len(names) for x in bases)
shapes={name:(int(n),int(k)) for name,n,k in re.findall(r'gemm_tiles\(&e,w\[(W_\w+)\],\d+,\d+,(\d+),(\d+),',program)}
assert len(shapes)==7 and set(shapes)==set(names)-{'W_INPUT_NORM','W_POST_NORM'}
head=re.search(r'gemm_tiles\(&e,MODEL_EMBEDDING_BASE,\d+,\d+,(\d+),(\d+),',program);assert head
vocab,width=map(int,head.groups());tile=int(re.search(r'for\(unsigned n=0;n<out;n\+=(\d+)u\)',program).group(1));assert tile<=192
embedding_stride=int(re.search(r'tokens\[row\]\*(\d+)u',program).group(1));assert embedding_stride==2*width
norm_sizes={name:int(b) for name,b in re.findall(r'dma\(&e,OP_LOAD,3,w\[(W_\w+)\],(\d+)u,',program)};assert set(norm_sizes)=={'W_INPUT_NORM','W_POST_NORM'}
final_norm_size=int(re.search(r'dma\(&e,OP_LOAD,3,MODEL_FINAL_NORM,(\d+)u,',program).group(1))
rope_stride=int(re.search(r'MODEL_ROPE_BASE\+start\*(\d+)u',program).group(1));context=int(re.search(r'start\+rows>(\d+)u',program).group(1))
semantic={'W_INPUT_NORM':'input_layernorm','W_POST_NORM':'post_attention_layernorm','W_Q':'q_proj','W_K':'k_proj','W_V':'v_proj','W_O':'o_proj','W_GATE':'gate_proj','W_UP':'up_proj','W_DOWN':'down_proj'}
regions=[]
def region(name,kind,address,byte_count,**extra):
 offset=address-base;assert offset>=0 and offset+byte_count<=size and offset%16==0
 regions.append({'name':name,'kind':kind,'offset_bytes':offset,'size_bytes':byte_count,**extra})
region('embedding','raw',macro('MODEL_EMBEDDING_BASE'),vocab*width*2,semantic_tensor='embedding',rows=vocab,columns=width)
for layer,row in enumerate(bases):
 for index,key in enumerate(names):
  if key in norm_sizes:region(f'layer.{layer:02d}.{semantic[key]}','raw',row[index],norm_sizes[key],semantic_tensor=semantic[key],layer=layer)
  else:
   n,k=shapes[key];assert k in (576,1536) and k%16==0
   for nstart in range(0,n,tile):
    ntile=min(tile,n-nstart)
    region(f'layer.{layer:02d}.{semantic[key]}.n{nstart:05d}','dense',row[index]+2*nstart*k,2*ntile*k,semantic_tensor=semantic[key],layer=layer,n_start=nstart,n_tile=ntile,k=k)
region('final.norm','raw',macro('MODEL_FINAL_NORM'),final_norm_size,semantic_tensor='final_norm')
region('rope','raw',macro('MODEL_ROPE_BASE'),context*rope_stride,semantic_tensor='rope',rows=context,row_bytes=rope_stride)
for nstart in range(0,vocab,tile):
 ntile=min(tile,vocab-nstart)
 region(f'lm_head.n{nstart:05d}','dense',macro('MODEL_EMBEDDING_BASE')+2*nstart*width,2*ntile*width,semantic_tensor='lm_head',n_start=nstart,n_tile=ntile,k=width,reference_alias_of='embedding')
covered=0
for start,stop in sorted((x['offset_bytes'],x['offset_bytes']+x['size_bytes']) for x in regions):assert start<=covered,'gap in actual image coverage';covered=max(covered,stop)
assert covered==size and len(regions)==1129 and sum(x['kind']=='dense' for x in regions)==1066
with (D/'ddr_static_bf16.bin').open('rb') as f:
 for x in regions:f.seek(x['offset_bytes']);x['original_region_sha256']=hashlib.sha256(f.read(x['size_bytes'])).hexdigest()
reference={'version':2,'scope':'evaluator-owned actual static image inventory supplement; original v1 evaluator unchanged','layout_id':'dense_nk_bf16','ddr_base':base,'image_bytes':size,'image_sha256':source['ddr_static_bf16.bin']['sha256'],'image':source['ddr_static_bf16.bin']['path'],'source_identity':source,'regions':regions}
map_path=a.out/'reference_map_v2.json';map_path.write_text(json.dumps(reference,indent=2)+'\n')
# Temporary evaluator-owned mirror exercises the unchanged auditor's candidate schema.
mirror=a.out/'baseline_mirror';mirror.mkdir(exist_ok=True);mirror_image=mirror/'MODEL.BIN'
if not mirror_image.exists():shutil.copyfile(D/'ddr_static_bf16.bin',mirror_image)
assert sha(mirror_image)==reference['image_sha256']
mirror_map={'image':'MODEL.BIN','image_sha256':reference['image_sha256'],'layout_id':'dense_nk_bf16','ddr_base':base,'reserved_end':end,'regions':regions}
(mirror/'t02_asset_map.json').write_text(json.dumps(mirror_map,indent=2)+'\n')
command=[sys.executable,str(a.auditor.resolve()),'--candidate-root',str(mirror.resolve()),'--out',str((a.out/'baseline_audit').resolve()),'--baseline-mode','--reference-image',str((D/'ddr_static_bf16.bin').resolve()),'--reference-map',str(map_path.resolve())]
result=subprocess.run(command,text=True,capture_output=True);(a.out/'baseline_audit.stdout').write_text(result.stdout+result.stderr);assert result.returncode==0,result.stdout[-2000:]+result.stderr
report={'status':'PASS','version':2,'original_v1_bundle_mutated':False,'reference_map_sha256':sha(map_path),'reference_image_sha256':reference['image_sha256'],'image_bytes':size,'covered_original_bytes':covered,'region_count':len(regions),'dense_region_count':1066,'layer_dense_regions':810,'lm_head_aliased_regions':256,'raw_region_count':63,'layers':layers,'actual_dense_shapes':sorted({(x['n_tile'],x['k']) for x in regions if x['kind']=='dense'}),'baseline_auditor_status':'PASS','baseline_auditor_command':command,'baseline_auditor_sha256':sha(a.auditor),'generator_sha256':sha(Path(__file__)),'source_identity':source,'limits':['Actual target image is not generated or evaluated here.','DDR reserved-capacity policy and candidate runtime addresses remain common integration gates.','Raw RoPE is one opaque bit-preserved region; no changed-layout numerical execution is claimed.']}
(a.out/'reference_map_evidence_v2.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items() if k not in ('source_identity','baseline_auditor_command')},indent=2))
