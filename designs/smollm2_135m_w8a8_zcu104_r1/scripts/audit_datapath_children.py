"""Independent read-only child RTL audit; no synthesis or source mutation."""
from pathlib import Path
import hashlib,json,random,subprocess,sys
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'evidence/independent_datapath_audit'
OUT.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(ROOT/'scripts'))
import exact_numeric as ex

def run(name,args,cwd=OUT):
    p=subprocess.run(args,cwd=cwd,capture_output=True,text=True,timeout=120)
    (OUT/(name+'.log')).write_text(p.stdout+p.stderr)
    if p.returncode: raise RuntimeError(name+' failed: '+p.stdout[-1500:]+p.stderr[-1500:])
    return p.stdout

# Recompute every primary core expected payload with independent Python integers.
state=[[0]*16 for _ in range(96)]; expected=[]; nsteps=0
for line in (ROOT/'evidence/int8_dot_core/inputs.txt').read_text().splitlines():
    a,b,row,first,last,n,tag,scale=[int(x,16) for x in line.split()]
    def signed(v): return v-256 if v>=128 else v
    sums=[]
    for ch in range(16):
        value=sum(signed((a>>(8*k))&255)*signed((b>>(8*(ch*16+k)))&255) for k in range(16)) if ch<n else 0
        state[row][ch]=value if first else state[row][ch]+value
        sums.append(state[row][ch]&0xffffffff)
    if last: expected.append((sum(x<<(32*j) for j,x in enumerate(sums)),n,tag,scale))
    nsteps+=1
primary=[tuple(int(x,16) for x in l.split()) for l in (ROOT/'evidence/int8_dot_core/expected.txt').read_text().splitlines()]
assert expected==primary
run('core_compile',['iverilog','-g2012','-s','tb_int8_dot_core','-o',str(OUT/'core_sim'),str(ROOT/'rtl/int8_dot_core.sv'),str(ROOT/'tb/tb_int8_dot_core.sv')])
assert 'CORE_PASS' in run('core_sim',['vvp',str(OUT/'core_sim')],ROOT/'evidence/int8_dot_core')

rng=random.Random(991837)
# Bias multiplication toward cancellation-free halfway and subnormal boundaries.
edge=[0,0x80000000,1,2,3,0x7ffffe,0x7fffff,0x800000,0x800001,0x3effffff,0x3f000000,0x3f000001,0x3f7fffff,0x3f800000,0x3f800001,0x40000000,0x7f7ffffe,0x7f7fffff]
edge+= [x|0x80000000 for x in edge if x<0x80000000]
pairs=[(a,b) for a in edge for b in edge]
for _ in range(24000):
    a=rng.getrandbits(32); b=rng.getrandbits(32)
    if ex.finite32(a) and ex.finite32(b):pairs.append((a,b))
(OUT/'audit_mul.hex').write_text(''.join(f'{a:08x}{b:08x}{ex.mul32(a,b):08x}\n' for a,b in pairs))
checks=[]
for _ in range(12000):
    i=rng.randrange(-2**31,2**31); x=rng.getrandbits(32)
    if not ex.finite32(x):x=0x7f7fffff
    bf=ex.bf16(ex.value32(x),x>>31)
    checks.append(f'{i&0xffffffff:08x}{ex.f32(i):08x}{x:08x}{bf:04x}')
(OUT/'audit_pkg.hex').write_text('\n'.join(checks)+'\n')
tb=r'''module audit_numeric;
import w8a8_fp32_pkg::*;
logic clk=0; always #2.5 clk=~clk;
logic resetn=0,sv=0,sr,mv,mr=0;
logic [31:0] a,b,y;logic[95:0] tag,ot;logic nf;
w8a8_fp32_mul dut(clk,resetn,sv,sr,a,b,tag,mv,mr,y,ot,nf);
logic[95:0] data[0:COUNT-1];logic[111:0] pkgdata[0:PKGCOUNT-1];
integer sent=0,got=0,cycles=0,j;logic[128:0] held;logic was_held=0;
logic[31:0] rng=32'hdd113789;
initial begin
 $readmemh("audit_mul.hex",data);$readmemh("audit_pkg.hex",pkgdata);
 for(j=0;j<PKGCOUNT;j=j+1)begin
  if(int32_to_fp32(pkgdata[j][111:80])!==pkgdata[j][79:48])$fatal(1,"integer convert %d",j);
  if(fp32_to_bf16(pkgdata[j][47:16])!==pkgdata[j][15:0])$fatal(1,"BF16 round %d",j);
 end
 repeat(4)@(negedge clk);resetn=1;
end
always @(negedge clk)if(resetn)begin
 cycles=cycles+1;rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
 mr=(cycles%103<70)&&rng[1:0]!=0;
 // Never replace a pending input. 'sent' advances only on handshake.
 if(!sv || tag[31:0]!=32'(sent))begin
  sv=sent<COUNT && rng[4:2]!=0;
  if(sv)begin a=data[sent][95:64];b=data[sent][63:32];tag={64'habcde00001234567,32'(sent)};end
 end
 if(cycles>200000)$fatal(1,"timeout");
end
always @(posedge clk)if(resetn)begin
 if(was_held && (!mv || {y,ot,nf}!==held))$fatal(1,"stalled output changed");
 was_held=mv&&!mr;held={y,ot,nf};
 if(sv&&sr)sent=sent+1;
 if(mv&&mr)begin
  if(y!==data[got][31:0]||ot!=={64'habcde00001234567,32'(got)}||nf!==(data[got][30:23]==8'hff))
    $fatal(1,"MUL idx%d a%h b%h got%h exp%h tag%h",got,data[got][95:64],data[got][63:32],y,data[got][31:0],ot);
  got=got+1;
 end
 if(got==COUNT)begin $display("AUDIT_NUMERIC_PASS mul=%d pkg=%d cycles=%d",got,PKGCOUNT,cycles);$finish;end
end
endmodule
'''
tb=tb.replace('PKGCOUNT',str(len(checks))).replace('COUNT',str(len(pairs)))
(OUT/'audit_numeric.sv').write_text(tb)
run('numeric_compile',['iverilog','-g2012','-s','audit_numeric','-o',str(OUT/'numeric_sim'),str(ROOT/'rtl/w8a8_fp32_pkg.sv'),str(ROOT/'rtl/w8a8_fp32_mul.sv'),str(OUT/'audit_numeric.sv')])
assert 'AUDIT_NUMERIC_PASS' in run('numeric_sim',['vvp',str(OUT/'numeric_sim')])
# Independently generated four-lane bundles: masked numerical faults and signed zero.
records=[]
for i in range(4000):
    sums=[rng.randrange(-2**31,2**31) for _ in range(4)]
    scales=[rng.choice(edge+[0xbf800000,0x7f800000,0x7fc00001]) if i<1200 else rng.randrange(0x7f800000) for _ in range(4)]
    mask=rng.randrange(16);bf=[];error=0
    for j,(v,sc) in enumerate(zip(sums,scales)):
        y=ex.mul32(ex.f32(v),sc) if ex.finite32(sc) else 0x7fc00000
        rounded=ex.bf16(ex.value32(y),y>>31) if ex.finite32(y) else y>>16
        bf.append(rounded)
        if mask>>j&1:error|=int(bool(sc>>31) or not ex.finite32(sc) or not ex.finite32(y) or ((rounded>>7)&255)==255)
    a=sum((v&0xffffffff)<<(32*j) for j,v in enumerate(sums));b=sum(v<<(32*j) for j,v in enumerate(scales));c=sum(v<<(16*j) for j,v in enumerate(bf))
    records.append(f'{a:032x}{b:032x}{mask:x}{c:016x}{error:x}')
(OUT/'audit_epi.hex').write_text('\n'.join(records)+'\n')
tb2=r'''module audit_epilogue;
logic clk=0;always #2.5 clk=~clk;
logic resetn=0,iv=0,ir,ov,orr=0;logic[127:0]sums,scales;logic[3:0]mask,om;logic[95:0]tag,ot;logic[63:0]bf;logic err;
fp32_bf16_epilogue dut(clk,resetn,iv,ir,sums,scales,mask,tag,ov,orr,bf,om,ot,err);
logic[327:0]data[0:3999];integer sent=0,got=0,cycles=0;logic[31:0]rng=32'h33443398;logic heldvalid=0;logic[164:0]held;
initial begin $readmemh("audit_epi.hex",data);repeat(4)@(negedge clk);resetn=1;end
always @(negedge clk)if(resetn)begin
 cycles=cycles+1;rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};orr=cycles%73<40 &&rng[1:0]!=0;
 if(!iv||tag[31:0]!=32'(sent))begin iv=sent<4000 &&rng[3:2]!=0;if(iv)begin sums=data[sent][327:200];scales=data[sent][199:72];mask=data[sent][71:68];tag={64'h12345678bcabcdef,32'(sent)};end end
 if(cycles>100000)$fatal(1,"timeout");
end
always @(posedge clk)if(resetn)begin
 if(heldvalid&&(!ov||{bf,om,ot,err}!==held))$fatal(1,"epi output changed stalled");heldvalid=ov&&!orr;held={bf,om,ot,err};
 if(iv&&ir)sent=sent+1;
 if(ov&&orr)begin
 if({bf,om,ot,err}!=={data[got][67:4],data[got][71:68],64'h12345678bcabcdef,32'(got),data[got][0]})$fatal(1,"epi mismatch %d actual %h exp%h err%b expected%b tag%h",got,bf,data[got][67:4],err,data[got][0],ot);
 got=got+1;end
 if(got==4000)begin $display("AUDIT_EPILOGUE_PASS bundles=%d cycles=%d",got,cycles);$finish;end
end
endmodule
'''
(OUT/'audit_epilogue.sv').write_text(tb2)
run('epilogue_compile',['iverilog','-g2012','-s','audit_epilogue','-o',str(OUT/'epilogue_sim')]+[str(ROOT/'rtl'/f) for f in ['w8a8_fp32_pkg.sv','w8a8_fp32_mul.sv','fp32_bf16_epilogue.sv']]+[str(OUT/'audit_epilogue.sv')])
assert 'AUDIT_EPILOGUE_PASS' in run('epilogue_sim',['vvp',str(OUT/'epilogue_sim')])
print(json.dumps({'epilogue_bundles':len(records),'core_steps_independently_recomputed':nsteps,'core_results':len(expected),'mul_cases':len(pairs),'package_cases':len(checks),'status':'PASS_SCOPED_FUNCTIONAL_NUMERIC_CHECKS'}))
