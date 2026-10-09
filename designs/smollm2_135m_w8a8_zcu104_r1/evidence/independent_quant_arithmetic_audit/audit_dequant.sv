module audit;
logic clk=0;always #2.5 clk=~clk;
logic resetn=0,sv=0,sr,mv,mr=0;logic[95:0]tag,ot;logic[163:0]source;logic[71:0]sink,held;
logic[307:0]data[0:1499];integer sent=0,got=0,cycles=0;integer accepted[0:1499];logic washeld=0;logic[95:0]heldtag;logic[31:0]rng=32'h37519372;
w8a8_dequant_lane4 dut(.clk(clk),.resetn(resetn),.s_valid(sv),.s_ready(sr),.s_tag(tag),.m_valid(mv),.m_ready(mr),.m_tag(ot),.s_int8(source[163:132]),.s_scale(source[131:4]),.s_mask(source[3:0]),.m_bf16(sink[71:8]),.m_mask(sink[7:4]),.m_error(sink[3:0]));
initial begin $readmemh("audit_dequant.hex",data);repeat(4)@(negedge clk);resetn=1;end
always @(negedge clk)if(resetn)begin
cycles=cycles+1;rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};mr=cycles<100 || (cycles%151<80 &&rng[1:0]!=0);
if(!sv||tag[31:0]!=32'(sent))begin sv=sent<1500 &&(cycles<100||rng[4:2]!=0);if(sv)begin source=data[sent][307:144];tag={64'h12398756abcdef09,32'(sent)};end end
if(cycles>200000)$fatal(1,"timeout");end
always @(posedge clk)if(resetn)begin
if(washeld&&(!mv||sink!==held||ot!==heldtag))$fatal(1,"output valid/payload/tag changed stalled");washeld=mv&&!mr;held=sink;heldtag=ot;
if(sv&&sr)begin accepted[sent]=cycles;sent=sent+1;end
if(mv&&mr)begin
if(((sink^data[got][143:72])&data[got][71:0])!==0||ot!=={64'h12398756abcdef09,32'(got)})$fatal(1,"dequant mismatch index%d got%h exp%h",got,sink,data[got][143:72]);
if(cycles<90&&cycles-accepted[got]!=8)$fatal(1,"latency %d",cycles-accepted[got]);got=got+1;end
if(got==1500)begin $display("AUDIT_dequant_PASS bundles=%d",got);$finish;end
end
endmodule
