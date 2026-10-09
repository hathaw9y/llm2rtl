"""Independent stimuli and source-read-only arithmetic verification."""
from pathlib import Path
import json,random,subprocess,sys,hashlib
R=Path(__file__).resolve().parents[1];O=R/'evidence/independent_quant_arithmetic_audit';O.mkdir(exist_ok=True)
sys.path.insert(0,str(R/'scripts'));import exact_numeric as ex
rng=random.Random(783104)
sources=[R/'rtl'/f for f in ['w8a8_fp32_pkg.sv','w8a8_fp32_mul.sv','w8a8_fp32_div4.sv','w8a8_quant_lane4.sv','w8a8_dequant_lane4.sv']]
before={str(p.relative_to(R)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sources}
edges=[0,0x80000000,1,2,3,0x7fffff,0x800000,0x800001,0x3f000000,0x3f2aaaab,0x3f7fffff,0x3f800000,0x42fe0000,0x7f7fffff,0x7f800000,0x7fc00001,0xbf800000]
def pack(vals,bits):return sum((v&((1<<bits)-1))<<(bits*i) for i,v in enumerate(vals))
def run(name,cmd):
    p=subprocess.run(cmd,cwd=O,capture_output=True,text=True,timeout=180);(O/(name+'.log')).write_text(p.stdout+p.stderr);p.check_returncode();return p.stdout
rows={k:[] for k in ['div','quant','dequant']}
for i in range(5000):
    a=[rng.choice(edges) if i<1500 else rng.getrandbits(32) for _ in range(4)]
    b=[rng.choice(edges) if i<1500 else rng.getrandbits(32) for _ in range(4)]
    mask=rng.randrange(16);results=[];inv=ov=check=0
    for l,(x,y) in enumerate(zip(a,b)):
        bad=not ex.finite32(x) or not ex.finite32(y) or y&0x7fffffff==0
        z=0x7fc00000 if bad else ex.div32(x,y);results.append(z)
        if mask>>l&1:
            inv|=int(bad)<<l;ov|=int(not bad and not ex.finite32(z))<<l
            if not bad:check|=0xffffffff<<(12+32*l)
    src=(pack(a,32)<<132)|(pack(b,32)<<4)|mask
    exp=(pack(results,32)<<12)|(mask<<8)|(inv<<4)|ov
    rows['div'].append((src,exp,check|0xfff))
for i in range(3000):
    xs=[rng.choice([0,0x8000,1,0x8001,0x3f80,0xbf80,0x3fc0,0x7f7f,0xff7f,0x7fc1,0x7f80]) if i<1000 else rng.getrandbits(16) for _ in range(4)]
    scales=[rng.choice(edges) if i<1000 else rng.getrandbits(32) for _ in range(4)]
    if i==0:xs=[0x3f80,1,0x7f7f,0xff7f];scales=[0x3f2aaaab,0x42fe0000,1,1]
    mask=15 if i==0 else rng.randrange(16);unsigned=rng.randrange(2);q=[];iv=[];err=check=0
    for l,(x,sc) in enumerate(zip(xs,scales)):
        bad=((x>>7)&255)==255 or sc>>31 or not ex.finite32(sc) or sc&0x7fffffff==0
        quotient=0x7fc00000 if bad else ex.div32(x<<16,sc)
        value=0 if bad else ex.quantize(x,sc,bool(unsigned));q.append(quotient);iv.append(value)
        if mask>>l&1:
            err|=int(bool(bad))<<l
            if not bad:check|=(0xffffffff<<(40+32*l))|(0xff<<(8+8*l))
    src=(pack(xs,16)<<133)|(pack(scales,32)<<5)|(unsigned<<4)|mask
    exp=(pack(q,32)<<40)|(pack(iv,8)<<8)|(mask<<4)|err
    rows['quant'].append((src,exp,check|0xff))
for i in range(1500):
    xs=[rng.randrange(-128,128) for _ in range(4)];scales=[rng.choice(edges) if i<800 else rng.getrandbits(32) for _ in range(4)]
    if i==0:xs=[-1,1,-128,127];scales=[1,0x7f7fffff,0x3f800000,0x7f7fffff]
    mask=15 if i==0 else rng.randrange(16);vals=[];err=check=0
    for l,(v,sc) in enumerate(zip(xs,scales)):
        bad=v==-128 or sc>>31 or not ex.finite32(sc) or sc&0x7fffffff==0
        z=0
        if not bad:
            y=ex.mul32(ex.f32(v),sc)
            z=ex.bf16(ex.value32(y),y>>31) if ex.finite32(y) else y>>16
            bad=not ex.finite32(y) or (z>>7)&255==255
        vals.append(z)
        if mask>>l&1:
            err|=int(bool(bad))<<l
            if not bad:check|=0xffff<<(8+16*l)
    src=(pack(xs,8)<<132)|(pack(scales,32)<<4)|mask;exp=(pack(vals,16)<<8)|(mask<<4)|err
    rows['dequant'].append((src,exp,check|0xff))
configs={
'div':(260,140,'w8a8_fp32_div4',19,'.s_a(source[259:132]),.s_b(source[131:4]),.s_mask(source[3:0]),.m_result(sink[139:12]),.m_mask(sink[11:8]),.m_invalid(sink[7:4]),.m_overflow(sink[3:0])'),
'quant':(197,168,'w8a8_quant_lane4',22,'.s_bf16(source[196:133]),.s_scale(source[132:5]),.s_unsigned(source[4]),.s_mask(source[3:0]),.m_quotient(sink[167:40]),.m_int8(sink[39:8]),.m_mask(sink[7:4]),.m_error(sink[3:0])'),
'dequant':(164,72,'w8a8_dequant_lane4',8,'.s_int8(source[163:132]),.s_scale(source[131:4]),.s_mask(source[3:0]),.m_bf16(sink[71:8]),.m_mask(sink[7:4]),.m_error(sink[3:0])')}
summary={}
for kind,(sw,dw,mod,lat,ports) in configs.items():
    vec=rows[kind];total=sw+dw*2;digits=(total+3)//4
    (O/f'audit_{kind}.hex').write_text(''.join(f'{(s<<(dw*2))|(e<<dw)|c:0{digits}x}\n' for s,e,c in vec))
    tb=f'''module audit;
logic clk=0;always #2.5 clk=~clk;
logic resetn=0,sv=0,sr,mv,mr=0;logic[95:0]tag,ot;logic[{sw-1}:0]source;logic[{dw-1}:0]sink,held;
logic[{total-1}:0]data[0:{len(vec)-1}];integer sent=0,got=0,cycles=0;integer accepted[0:{len(vec)-1}];logic washeld=0;logic[95:0]heldtag;logic[31:0]rng=32'h37519372;
{mod} dut(.clk(clk),.resetn(resetn),.s_valid(sv),.s_ready(sr),.s_tag(tag),.m_valid(mv),.m_ready(mr),.m_tag(ot),{ports});
initial begin $readmemh("audit_{kind}.hex",data);repeat(4)@(negedge clk);resetn=1;end
always @(negedge clk)if(resetn)begin
cycles=cycles+1;rng={{rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]}};mr=cycles<100 || (cycles%151<80 &&rng[1:0]!=0);
if(!sv||tag[31:0]!=32'(sent))begin sv=sent<{len(vec)} &&(cycles<100||rng[4:2]!=0);if(sv)begin source=data[sent][{total-1}:{2*dw}];tag={{64'h12398756abcdef09,32'(sent)}};end end
if(cycles>200000)$fatal(1,"timeout");end
always @(posedge clk)if(resetn)begin
if(washeld&&(!mv||sink!==held||ot!==heldtag))$fatal(1,"output valid/payload/tag changed stalled");washeld=mv&&!mr;held=sink;heldtag=ot;
if(sv&&sr)begin accepted[sent]=cycles;sent=sent+1;end
if(mv&&mr)begin
if(((sink^data[got][{2*dw-1}:{dw}])&data[got][{dw-1}:0])!==0||ot!=={{64'h12398756abcdef09,32'(got)}})$fatal(1,"{kind} mismatch index%d got%h exp%h",got,sink,data[got][{2*dw-1}:{dw}]);
if(cycles<90&&cycles-accepted[got]!={lat})$fatal(1,"latency %d",cycles-accepted[got]);got=got+1;end
if(got=={len(vec)})begin $display("AUDIT_{kind}_PASS bundles=%d",got);$finish;end
end
endmodule
'''
    (O/f'audit_{kind}.sv').write_text(tb)
    run(kind+'_compile',['iverilog','-g2012','-s','audit','-o',str(O/(kind+'_sim'))]+list(map(str,sources))+[str(O/f'audit_{kind}.sv')])
    output=run(kind+'_sim',['vvp',str(O/(kind+'_sim'))]);assert f'AUDIT_{kind}_PASS' in output;print(output.strip(),flush=True)
    summary[kind]={'bundles':len(vec),'lanes':len(vec)*4,'latency':lat,'status':'PASS'}
assert before=={str(p.relative_to(R)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sources}
(O/'results.json').write_text(json.dumps({'source_sha256':before,'results':summary,'source_unchanged':True},indent=2)+'\n')
