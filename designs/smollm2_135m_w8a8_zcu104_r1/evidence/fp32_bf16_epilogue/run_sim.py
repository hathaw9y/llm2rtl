from pathlib import Path
import sys, random, subprocess, json
root=Path(__file__).resolve().parents[2]; ev=Path(__file__).parent
sys.path.insert(0,str(root/'scripts'))
import exact_numeric as ex
rng=random.Random(7744)
# finite random multiplication, including full subnormal encodings
pairs=[(a,b) for a in [0,0x80000000,1,2,0x7fffff,0x800000,0x3f800000,0x3f800001,0xbf800001,0x7f7fffff] for b in [0,1,0x800000,0x3f000000,0x3f800000,0x3fc00000,0x40000000,0x80000000,0x7f7fffff]]
for _ in range(12000):
 a=rng.getrandbits(32);b=rng.getrandbits(32)
 if ex.finite32(a) and ex.finite32(b):pairs.append((a,b))
import numpy as np
with np.errstate(all='ignore'):
 for a,b in pairs:
  av=np.array([a],dtype=np.uint32).view(np.float32)[0]
  bv=np.array([b],dtype=np.uint32).view(np.float32)[0]
  nv=int(np.array([np.float32(av*bv)],dtype=np.float32).view(np.uint32)[0])
  assert nv==ex.mul32(a,b),(a,b,nv,ex.mul32(a,b))
mulwords=[]
for a,b in pairs:
 v=ex.mul32(a,b);mulwords.append(f'{a:08x}{b:08x}{v:08x}')
(ev/'mul.hex').write_text('\n'.join(mulwords)+'\n')
records=[]
ints=[0,1,-1,16777217,16777219,-16777217,2147483647,-2147483648]
scales=[0,1,0x7fffff,0x800000,0x3f800000,0x3f808000,0x3f818000,0x007f8000,0x00008000,0x00018000,0x3b800000,0x7f7fffff,0x80000000,0xbf800000,0x7f800000,0x7fc00000]
for i in range(1600):
 sums=[rng.choice(ints) if i<150 else rng.randrange(-2**31,2**31) for j in range(4)]
 ss=[rng.choice(scales) if i<200 else rng.randrange(0,0x7f800000) for j in range(4)]
 mask=rng.randrange(16);out=[];err=0
 for j,(s,sc) in enumerate(zip(sums,ss)):
  bad=bool(sc>>31) or not ex.finite32(sc)
  if not ex.finite32(sc):res=0x7fc00000
  else:res=ex.mul32(ex.f32(s),sc)
  if ex.finite32(res):bf=ex.bf16(ex.value32(res),res>>31)
  else:bf=res>>16
  out.append(bf)
  if mask>>j&1:err|=int(bad or not ex.finite32(res) or (bf>>7)&255==255)
 sv=sum((s&0xffffffff)<<(32*j) for j,s in enumerate(sums));scv=sum(s<<(32*j) for j,s in enumerate(ss));bfv=sum(b<<(16*j) for j,b in enumerate(out))
 records.append(f'{sv:032x}{scv:032x}{mask:01x}{bfv:016x}{err:01x}')
# Complete output tiles from stored interpreter golden, one each workload/K.
import gzip,hashlib
import isa_codec
manifest=json.loads((root/'verification/tensor_golden/manifest.json').read_text())
golden=root/'verification/tensor_golden';seen=set();golden_cases=[]
def component(item,name):
 info=item['components'][name];raw=gzip.decompress((golden/info['file']).read_bytes());assert hashlib.sha256(raw).hexdigest()==info['sha256'];return raw
for v in manifest['vectors']:
 if v['opcode']!='GEMM_INT8':continue
 f=isa_codec.decode(int(v['hex128'],16))['fields'];key=(v['workload'],f['k'])
 if key in seen:continue
 seen.add(key);golden_cases.append(v['command_id'])
 left,right=v['inputs'];K=f['k'];N=f['n_tile'];M=f['m_count']
 aa=np.frombuffer(component(left,'data'),dtype=np.int8).astype(np.int32).reshape(-1,K)
 bb=np.frombuffer(component(right,'data'),dtype=np.int8).astype(np.int32).reshape(N,K)
 dots=aa[f['m_start']:f['m_start']+M]@bb.T
 sa=np.frombuffer(component(left,'scale'),dtype='<u4');sb=np.frombuffer(component(right,'scale'),dtype='<u4')
 info=v['outputs']['data'];raw=gzip.decompress((golden/info['file']).read_bytes());assert hashlib.sha256(raw).hexdigest()==info['sha256'];output=np.frombuffer(raw,dtype='<u2').reshape(-1,f['n_total'])
 for row in range(M):
  for col in range(0,N,4):
   sums=[int(dots[row,col+j]) for j in range(4)]
   ss=[ex.mul32(int(sa[(row+f['m_start'])//16]),int(sb[(col+j)//16])) for j in range(4)]
   expected=[int(output[row+f['m_start'],col+j+f['n_start']]) for j in range(4)]
   for dot,scale,bf in zip(sums,ss,expected): assert ex.bf16(ex.value32(ex.mul32(ex.f32(dot),scale)))==bf
   sv=sum((x&0xffffffff)<<(32*j) for j,x in enumerate(sums));scv=sum(x<<(32*j) for j,x in enumerate(ss));bfv=sum(x<<(16*j) for j,x in enumerate(expected))
   records.append(f'{sv:032x}{scv:032x}f{bfv:016x}0')
(ev/'epi.hex').write_text('\n'.join(records)+'\n')
tb='''module tb;
logic clk=0;always #2.5 clk=~clk;
logic resetn=0,sv=0,sr,mv,mr=0;logic[31:0] a,b,result;logic[95:0] st,mt;logic nf;
w8a8_fp32_mul mul(clk,resetn,sv,sr,a,b,st,mv,mr,result,mt,nf);
logic iv=0,ir,ov,orr=0;logic[127:0] sums,scales;logic[3:0] mask,om;logic[95:0] it,ot;logic[63:0] bf;logic err;
fp32_bf16_epilogue epi(clk,resetn,iv,ir,sums,scales,mask,it,ov,orr,bf,om,ot,err);
logic [95:0] muldata[0:MCOUNT-1];logic[327:0] edata[0:ECOUNT-1];
integer mi=0,mo=0,ei=0,eo=0,cycle=0;integer mcycle[0:MCOUNT-1],ecycle[0:ECOUNT-1];
logic [95:0] heldmul;logic [164:0] heldepi;logic mh=0,eh=0;
initial begin $readmemh("mul.hex",muldata);$readmemh("epi.hex",edata); repeat(4) @(negedge clk);resetn=1;wait(cycle==50);@(negedge clk);resetn=0;sv=0;iv=0;mi=0;mo=0;ei=0;eo=0;mh=0;eh=0;repeat(2)@(negedge clk);resetn=1;end
always @(negedge clk) if(resetn) begin
 cycle=cycle+1;mr=(cycle<40)||((cycle%7!=1)&&(cycle%7!=2));orr=(cycle<40)||((cycle%9!=2)&&(cycle%9!=3));
 if(!sv||st!=96'(mi)) begin sv=mi<MCOUNT && ((cycle<40)||cycle%5!=0);if(sv)begin a=muldata[mi][95:64];b=muldata[mi][63:32];st=96'(mi);end end
 if(!iv||it[31:0]!=32'(ei)) begin iv=ei<ECOUNT && ((cycle<40)||cycle%6!=0);if(iv)begin sums=edata[ei][327:200];scales=edata[ei][199:72];mask=edata[ei][71:68];it={64'habcdefff01234567,32'(ei)};end end
 if(cycle>100000) $fatal(1,"timeout");
end
always @(posedge clk) if(resetn) begin
 if(sv&&sr)begin mcycle[mi]=cycle;mi=mi+1;end
 if(iv&&ir)begin ecycle[ei]=cycle;ei=ei+1;end
 if(mh && {result,mt[63:0]}!==heldmul)$fatal(1,"mul stall");
 if(eh && {bf,om,ot,err}!==heldepi)$fatal(1,"epi stall");
 mh=mv&&!mr;heldmul={result,mt[63:0]};eh=ov&&!orr;heldepi={bf,om,ot,err};
 if(mv&&mr)begin
 if(cycle<40&&cycle-mcycle[mo]!=6)$fatal(1,"mul latency");
 if(result!==muldata[mo][31:0]||mt!==96'(mo))$fatal(1,"mul %0d actual %h expected %h",mo,result,muldata[mo][31:0]);mo=mo+1;
 end
 if(ov&&orr)begin
 if(cycle<40&&cycle-ecycle[eo]!=9)$fatal(1,"epi latency");
 if(bf!==edata[eo][67:4]||om!==edata[eo][71:68]||err!==edata[eo][3:0]||ot!=={64'habcdefff01234567,32'(eo)})$fatal(1,"epi %0d bf%h exp%h err%b exp%h tag%h",eo,bf,edata[eo][67:4],err,edata[eo][3:0],ot);eo=eo+1;
 end
 if(mo==MCOUNT&&eo==ECOUNT)begin $display("PASS_FP32_EPILOGUE");$finish;end
end
endmodule
'''
# record has 128+128+4+64+4=328 bits, pad error nibble above
# format actual error originally1hex makes nibble correct
(ev/'tb.sv').write_text(tb.replace('MCOUNT',str(len(pairs))).replace('ECOUNT',str(len(records))))
sources=[root/'rtl'/n for n in ['w8a8_fp32_pkg.sv','w8a8_fp32_mul.sv','fp32_bf16_epilogue.sv']]
with (ev/'compile.log').open('w') as log: subprocess.run(['iverilog','-g2012','-s','tb','-o',str(ev/'sim')]+list(map(str,sources))+[str(ev/'tb.sv')],stdout=log,stderr=log,check=True)
res=subprocess.run(['vvp',str(ev/'sim')],cwd=ev,capture_output=True,text=True,timeout=90);(ev/'simulation.log').write_text(res.stdout+res.stderr);print(res.stdout);res.check_returncode();assert 'PASS_FP32_EPILOGUE' in res.stdout
(ev/'simulation_report.json').write_text(json.dumps({'multiplier_cases':len(pairs),'epilogue_bundles':len(records),'result':'PASS','oracle':'exact Fraction binary32 and BF16 rounding','stalls':True,'midstream_reset_replay':True,'complete_golden_command_ids':golden_cases,'independent_numpy_binary32':True,'unstalled_latency_cycles':{'multiplier':6,'epilogue':9},'II1_tested_initial_continuous_cycles':39},indent=2)+'\n')
