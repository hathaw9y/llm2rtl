module tb;
logic clk=0;always #2.5 clk=~clk;
logic resetn=0,sv=0,sr,mv,mr=0;logic[95:0]st,mt;
integer si=0,ri=0,cycle=0;integer accepted[0:4000-1];
logic[197-1:0]source;logic[168-1:0]sink,held;
logic hold_previous=0;
logic[197+2*168-1:0]vectors[0:4000-1];
initial begin $readmemh("quant.hex",vectors);repeat(4)@(negedge clk);resetn=1;wait(cycle==60);@(negedge clk);resetn=0;sv=0;si=0;ri=0;hold_previous=0;repeat(2)@(negedge clk);resetn=1;end
always @(negedge clk)if(resetn)begin
cycle=cycle+1;mr=(cycle<50)||(cycle%13<7);
if(!sv||st[31:0]!=32'(si))begin sv=si<4000&&((cycle<50)||cycle%7!=1);if(sv)begin source=vectors[si][197+2*168-1:2*168];st={64'hccdeeeff12345678,32'(si)};end end
if(cycle>150000)$fatal(1,"timeout");end
always @(posedge clk)if(resetn)begin
if(sv&&sr)begin accepted[si]=cycle;si=si+1;end
if(hold_previous&&sink!==held)$fatal(1,"stall payload");
if(hold_previous&&mt!=={64'hccdeeeff12345678,32'(ri)})$fatal(1,"stall tag");
hold_previous=mv&&!mr;held=sink;
if(mv&&mr)begin
if(cycle<50&&cycle-accepted[ri]!=22)$fatal(1,"latency actual%0d",cycle-accepted[ri]);
if(((sink^vectors[ri][2*168-1:168])&vectors[ri][168-1:0])!==0||mt!=={64'hccdeeeff12345678,32'(ri)})$fatal(1,"quant case%0d got%h expected%h",ri,sink,vectors[ri][2*168-1:168]);
ri=ri+1;if(ri==4000)begin $display("PASS_quant");$finish;end
end end
w8a8_quant_lane4 dut(.clk(clk),.resetn(resetn),.s_valid(sv),.s_ready(sr),.s_bf16(source[196:133]),.s_scale(source[132:5]),.s_unsigned(source[4]),.s_mask(source[3:0]),.s_tag(st),.m_valid(mv),.m_ready(mr),.m_quotient(sink[167:40]),.m_int8(sink[39:8]),.m_mask(sink[7:4]),.m_tag(mt),.m_error(sink[3:0]));
endmodule
