from pathlib import Path
import sys,json,random,subprocess,hashlib
import numpy as np
ROOT=Path(__file__).resolve().parents[1];EV=Path('/home/shmin/llm2rtl/designs/smollm2_135m_w8a8_zcu104_r1/evidence/timing_retries/20261009T044944Z/quantization/arithmetic01')
sys.path.insert(0,str(ROOT/'scripts'));import exact_numeric as ex
contract_path=ROOT/'contracts/datapaths/quantization_arithmetic.json'
assert hashlib.sha256(contract_path.read_bytes()).hexdigest()=='61b35d34919d364a99e371cfbf8e50d483da08b3105d942402a1138f63d9c432'
contract=json.loads(contract_path.read_text());assert contract['status']=='frozen'
for pin in contract['unchanged_reuse'].values():
 assert hashlib.sha256((ROOT/pin['path'].split('smollm2_135m_w8a8_zcu104_r1/')[-1]).read_bytes()).hexdigest()==pin['sha256']
rng=random.Random(123790)
def pack(xs,w):return sum(x<<(i*w) for i,x in enumerate(xs))
def finite16(x):return (x>>7)&255!=255
def goodscale(x):return ex.finite32(x) and x>>31==0 and x!=0
cases={k:[] for k in ['div','quant','dequant']}
bounds=[0,0x80000000,1,2,0x7fffff,0x800000,0x3f000000,0x3f800000,0x3fc00000,0x7f7fffff,0x7f800000,0xff800000,0x7fc00000,0xbf800000,0x3f2aaaab,0x204]
for i in range(6500):
 aa=[rng.choice(bounds) if i<500 else rng.getrandbits(32) for _ in range(4)];bb=[rng.choice(bounds) if i<500 else rng.getrandbits(32) for _ in range(4)];mask=rng.randrange(16);result=[];invalid=[];overflow=[]
 for a,b in zip(aa,bb):
  inv=not ex.finite32(a) or not ex.finite32(b) or (b&0x7fffffff)==0
  v=0x7fc00000 if inv else ex.div32(a,b)
  result.append(v);invalid.append(int(inv));overflow.append(int(not inv and not ex.finite32(v)))
  if not inv:
   with np.errstate(all='ignore'):
    av=np.array([a],dtype=np.uint32).view(np.float32)[0];bv=np.array([b],dtype=np.uint32).view(np.float32)[0];nv=int(np.array([np.float32(av/bv)],dtype=np.float32).view(np.uint32)[0]);assert nv==v,(a,b,v,nv)
 inp=(pack(aa,32)<<132)|(pack(bb,32)<<4)|mask
 out=(pack(result,32)<<12)|(mask<<8)|((pack(invalid,1)&mask)<<4)|(pack(overflow,1)&mask)
 cases['div'].append((inp,out,(1<<140)-1))
for i in range(4000):
 xs=[rng.choice([0,0x8000,1,0x8001,0x3f00,0x3f80,0x3fc0,0x4020,0x7f7f,0xff7f,0x7f80,0x7fc0]) if i<500 else rng.getrandbits(16) for _ in range(4)]
 ss=[rng.choice(bounds) if i<500 else rng.randrange(0,0x7f800000) for _ in range(4)];unsigned=rng.randrange(2);mask=rng.randrange(16)
 if i==0:xs=[0x3f80,1,0x7f7f,0xff7f];ss=[0x3f2aaaab,0x204,1,1];unsigned=0;mask=15
 vals=[];errors=[];quotients=[];care=0
 for l,(x,s) in enumerate(zip(xs,ss)):
  invalid=not finite16(x) or not goodscale(s);errors.append(int(invalid))
  vals.append(0 if invalid else ex.quantize(x,s,bool(unsigned))&255)
  quotients.append(ex.div32(x<<16,s) if finite16(x) and ex.finite32(s) and (s&0x7fffffff)!=0 else 0x7fc00000)
  if not invalid:care|=255<<(8*l)
 inp=(pack(xs,16)<<133)|(pack(ss,32)<<5)|(unsigned<<4)|mask;out=(pack(quotients,32)<<40)|(pack(vals,8)<<8)|(mask<<4)|(pack(errors,1)&mask)
 cases['quant'].append((inp,out,(((1<<128)-1)<<40)|(care<<8)|255))
for i in range(3500):
 xs=[rng.randrange(256) for _ in range(4)];ss=[rng.choice(bounds) if i<500 else rng.randrange(0,0x7f800000) for _ in range(4)];mask=rng.randrange(16);vals=[];errors=[]
 if i==0:xs=[255,1,127,128];ss=[1,0x7f7fffff,0x7f7fffff,0x3f800000];mask=15
 for x,s in zip(xs,ss):
  signed=x if x<128 else x-256;v=ex.mul32(ex.f32(signed),s) if ex.finite32(s) else 0x7fc00000
  bf=ex.bf16(ex.value32(v),v>>31) if ex.finite32(v) else v>>16
  vals.append(bf);errors.append(int(x==128 or not goodscale(s) or not ex.finite32(v) or not finite16(bf)))
 inp=(pack(xs,8)<<132)|(pack(ss,32)<<4)|mask;out=(pack(vals,16)<<8)|(mask<<4)|(pack(errors,1)&mask)
 cases['dequant'].append((inp,out,(1<<72)-1))
units={'div':('w8a8_fp32_div4',260,140,19),'quant':('w8a8_quant_lane4',197,168,22),'dequant':('w8a8_dequant_lane4',164,72,8)}
common='''logic clk=0;always #2.5 clk=~clk;
logic resetn=0,sv=0,sr,mv,mr=0;logic[95:0]st,mt;
integer si=0,ri=0,cycle=0;integer accepted[0:COUNT-1];
logic[INW-1:0]source;logic[OUTW-1:0]sink,held;
logic hold_previous=0;
logic[INW+2*OUTW-1:0]vectors[0:COUNT-1];
initial begin $readmemh("UNIT.hex",vectors);repeat(4)@(negedge clk);resetn=1;wait(cycle==60);@(negedge clk);resetn=0;sv=0;si=0;ri=0;hold_previous=0;repeat(2)@(negedge clk);resetn=1;end
always @(negedge clk)if(resetn)begin
cycle=cycle+1;mr=(cycle<50)||(cycle%13<7);
if(!sv||st[31:0]!=32'(si))begin sv=si<COUNT&&((cycle<50)||cycle%7!=1);if(sv)begin source=vectors[si][INW+2*OUTW-1:2*OUTW];st={64'hccdeeeff12345678,32'(si)};end end
if(cycle>150000)$fatal(1,"timeout");end
always @(posedge clk)if(resetn)begin
if(sv&&sr)begin accepted[si]=cycle;si=si+1;end
if(hold_previous&&sink!==held)$fatal(1,"stall payload");
if(hold_previous&&mt!=={64'hccdeeeff12345678,32'(ri)})$fatal(1,"stall tag");
hold_previous=mv&&!mr;held=sink;
if(mv&&mr)begin
if(cycle<50&&cycle-accepted[ri]!=LATENCY)$fatal(1,"latency actual%0d",cycle-accepted[ri]);
if(((sink^vectors[ri][2*OUTW-1:OUTW])&vectors[ri][OUTW-1:0])!==0||mt!=={64'hccdeeeff12345678,32'(ri)})$fatal(1,"UNIT case%0d got%h expected%h",ri,sink,vectors[ri][2*OUTW-1:OUTW]);
ri=ri+1;if(ri==COUNT)begin $display("PASS_UNIT");$finish;end
end end
'''
connections={
'div':'''w8a8_fp32_div4 dut(.clk(clk),.resetn(resetn),.s_valid(sv),.s_ready(sr),.s_a(source[259:132]),.s_b(source[131:4]),.s_mask(source[3:0]),.s_tag(st),.m_valid(mv),.m_ready(mr),.m_result(sink[139:12]),.m_mask(sink[11:8]),.m_tag(mt),.m_invalid(sink[7:4]),.m_overflow(sink[3:0]));''',
'quant':'''w8a8_quant_lane4 dut(.clk(clk),.resetn(resetn),.s_valid(sv),.s_ready(sr),.s_bf16(source[196:133]),.s_scale(source[132:5]),.s_unsigned(source[4]),.s_mask(source[3:0]),.s_tag(st),.m_valid(mv),.m_ready(mr),.m_quotient(sink[167:40]),.m_int8(sink[39:8]),.m_mask(sink[7:4]),.m_tag(mt),.m_error(sink[3:0]));''',
'dequant':'''w8a8_dequant_lane4 dut(.clk(clk),.resetn(resetn),.s_valid(sv),.s_ready(sr),.s_int8(source[163:132]),.s_scale(source[131:4]),.s_mask(source[3:0]),.s_tag(st),.m_valid(mv),.m_ready(mr),.m_bf16(sink[71:8]),.m_mask(sink[7:4]),.m_tag(mt),.m_error(sink[3:0]));'''}
sources=[ROOT/'rtl'/n for n in ['w8a8_fp32_pkg.sv','w8a8_fp32_mul.sv','w8a8_fp32_div4.sv','w8a8_quant_lane4.sv','w8a8_dequant_lane4.sv']]
report={}
for key,(module,iw,ow,latency) in units.items():
 rows=cases[key];width=iw+2*ow;(EV/(key+'.hex')).write_text('\n'.join(f'{((inp<<(2*ow))|(out<<ow)|care):0{(width+3)//4}x}' for inp,out,care in rows)+'\n')
 tb='module tb;\n'+common+connections[key]+'\nendmodule\n'
 for a,b in [('COUNT',str(len(rows))),('INW',str(iw)),('OUTW',str(ow)),('LATENCY',str(latency)),('UNIT',key)]:tb=tb.replace(a,b)
 (EV/(key+'_tb.sv')).write_text(tb)
 with (EV/(key+'_compile.log')).open('w') as f:subprocess.run(['iverilog','-g2012','-s','tb','-o',str(EV/(key+'_sim'))]+list(map(str,sources))+[str(EV/(key+'_tb.sv'))],stdout=f,stderr=f,check=True)
 result=subprocess.run(['vvp',str(EV/(key+'_sim'))],cwd=EV,capture_output=True,text=True,timeout=100);(EV/(key+'_simulation.log')).write_text(result.stdout+result.stderr);print(result.stdout);result.check_returncode();assert 'PASS_'+key in result.stdout
 lint_sources=[p for p in sources if key!='div' or p.name=='w8a8_fp32_div4.sv']
 with (EV/(key+'_lint.log')).open('w') as f:subprocess.run(['verilator','--lint-only','-Wall','--top-module',module]+list(map(str,lint_sources)),stdout=f,stderr=f,check=True)
 report[module]={'status':'PASS','bundles':len(rows),'lanes':len(rows)*4,'latency_cycles':latency,'II':1,'II1_continuous_first_cycles':49,'stalls_and_bubbles':True,'midstream_reset':True,'oracle':'exact_numeric.py Fraction','numpy_division_independent':key=='div','strict_lint':'PASS'}
(EV/'simulation_report.json').write_text(json.dumps(report,indent=2)+'\n')
