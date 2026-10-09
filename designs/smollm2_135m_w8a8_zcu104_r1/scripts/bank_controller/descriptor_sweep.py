import pathlib,json,sys,subprocess,random,hashlib
B=pathlib.Path(__file__).resolve().parents[2];E=B/'evidence/infrastructure_wave/bank_controller';sys.path.insert(0,str(B/'scripts'));import isa_codec
rng=random.Random(4419);vs=[]
for bank in range(16):
 for p in range(1,24):
  for rows in [0,1,2,30,32,33,192,193,1024,1025]:
   for cols in [64,192,576,1024,1536,49152]:vs.append((bank,p,rows,cols,0,0,0,1))
for i in range(3000):vs.append((rng.randrange(16),rng.randrange(32),rng.choice([1,2,16,30,32,192,1024]),rng.choice([64,192,576,1024,1536,49152]),rng.choice([0,1,15,1000,1023]),rng.choice([0,1,29,30,31]),rng.randrange(4),rng.choice([0,1])))
# Include every B7 component/position boundary, explicit normative exception.
for comp in range(4):
 for rows in [1,30,32,33]:
  for pos in [0,1,992,1023]:vs.append((7,11,rows,64,pos,0,comp,1))
lines=[];exceptions=0;validn=0
for bank,p,r,c,pos,l,co,g in vs:
 f=dict(profile=p,rows=r,cols=c,position=pos,layer=l,component=co,generation=g)
 try:isa_codec.validate_descriptor_fields(bank,f);valid=True
 except ValueError:valid=False
 if bank==7 and co==2 and pos!=0:
  if valid:exceptions+=1
  valid=False
 validn+=valid
 lines.append(f'0 {bank} {p} {r} {c} {pos} {l} {co} {g} {int(valid)}')
(E/'descriptor_vectors.txt').write_text('\n'.join(lines)+'\n')
s=(E/'selftest_tb.sv').read_text().split('initial begin\nresetn=0;')[0]
s+='integer fd,rc,unused,b,p,r,c,pos,l,co,g,expected,count;\ninitial begin\n'
j=json.loads((B/'contracts/infrastructure_rtl_port_binding.json').read_text());inputs=['resetn']
for sec in ['acquire','release','config','producer','invalidate','coverage','embedding']:inputs+=list(j[sec]['inputs'])
s+=''.join(n+'=0;\n' for n in inputs)+'cfg_resp_ready=1;\n'
s+=f'fd=$fopen("{E}/descriptor_vectors.txt","r");count=0;\n'
s+='''while(!$feof(fd))begin
rc=$fscanf(fd,"%d %d %d %d %d %d %d %d %d %d\\n",unused,b,p,r,c,pos,l,co,g,expected);
if(rc==10)begin
 @(negedge clk);resetn=0;tick();resetn=1;
 cfg_bank=4'(b);cfg_profile=5'(p);cfg_rows=11'(r);cfg_cols=16'(c);cfg_position=10'(pos);
 cfg_layer=5'(l);cfg_component=2'(co);cfg_generation=32'(g);cfg_valid=1;tick();cfg_valid=0;
 check(cfg_resp_valid,"sweep response");
 if((cfg_resp_error_code==0)!=expected)$fatal(1,"vector %0d b%0d p%0d r%0d c%0d pos%0d layer%0d component%0d gen%0d expected%0d err%0d",count,b,p,r,c,pos,l,co,g,expected,cfg_resp_error_code);
 if(expected)check(bank_desc_present[b]&&bank_profiles[b*5+:5]==5'(p)&&bank_generations[b*32+:32]==32'(g),"sweep committed descriptor");
 else check(bank_desc_present==0&&bank_generations==0&&bank_profiles==0&&bank_data_valid==0&&bank_scale_valid==0,"sweep reject no mutation");
 count=count+1;
end
end
$display("PASS_DESCRIPTOR_SWEEP %0d",count);$finish;end
initial begin #1000000;$fatal(1,"timeout");end
endmodule
'''
(E/'descriptor_tb.sv').write_text(s)
cmd=['iverilog','-g2012','-s','tb','-o',str(E/'descriptor.vvp'),str(E/'descriptor_tb.sv'),str(B/'rtl/smollm2_bank_controller.sv'),str(B/'rtl/bank_ownership_table.sv')]
a=subprocess.run(cmd,text=True,capture_output=True);(E/'descriptor_compile.log').write_text(a.stdout+a.stderr);assert a.returncode==0,a.stderr
a=subprocess.run(['vvp',str(E/'descriptor.vvp')],text=True,capture_output=True);(E/'descriptor_simulation.log').write_text(a.stdout+a.stderr);print(a.stdout+a.stderr);assert a.returncode==0
(E/'descriptor_report.json').write_text(json.dumps(dict(status='PASS',vectors=len(vs),valid_vectors=validn,invalid_vectors=len(vs)-validn,oracle='frozen isa_codec.validate_descriptor_fields; B7 component2 position0 required by normative frozen bank_layout',normative_exception_vectors=exceptions,source_sha256=hashlib.sha256((B/'rtl/smollm2_bank_controller.sv').read_bytes()).hexdigest()),indent=2)+'\n')
