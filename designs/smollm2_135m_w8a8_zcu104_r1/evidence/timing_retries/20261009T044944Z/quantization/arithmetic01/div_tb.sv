module tb;
logic clk=0;always #2.5 clk=~clk;
logic resetn=0,sv=0,sr,mv,mr=0;logic[95:0]st,mt;
integer si=0,ri=0,cycle=0;integer accepted[0:6500-1];
logic[260-1:0]source;logic[140-1:0]sink,held;
logic hold_previous=0;
logic[260+2*140-1:0]vectors[0:6500-1];
initial begin $readmemh("div.hex",vectors);repeat(4)@(negedge clk);resetn=1;wait(cycle==60);@(negedge clk);resetn=0;sv=0;si=0;ri=0;hold_previous=0;repeat(2)@(negedge clk);resetn=1;end
always @(negedge clk)if(resetn)begin
cycle=cycle+1;mr=(cycle<50)||(cycle%13<7);
if(!sv||st[31:0]!=32'(si))begin sv=si<6500&&((cycle<50)||cycle%7!=1);if(sv)begin source=vectors[si][260+2*140-1:2*140];st={64'hccdeeeff12345678,32'(si)};end end
if(cycle>150000)$fatal(1,"timeout");end
always @(posedge clk)if(resetn)begin
if(sv&&sr)begin accepted[si]=cycle;si=si+1;end
if(hold_previous&&sink!==held)$fatal(1,"stall payload");
if(hold_previous&&mt!=={64'hccdeeeff12345678,32'(ri)})$fatal(1,"stall tag");
hold_previous=mv&&!mr;held=sink;
if(mv&&mr)begin
if(cycle<50&&cycle-accepted[ri]!=19)$fatal(1,"latency actual%0d",cycle-accepted[ri]);
if(((sink^vectors[ri][2*140-1:140])&vectors[ri][140-1:0])!==0||mt!=={64'hccdeeeff12345678,32'(ri)})$fatal(1,"div case%0d got%h expected%h",ri,sink,vectors[ri][2*140-1:140]);
ri=ri+1;if(ri==6500)begin $display("PASS_div");$finish;end
end end
w8a8_fp32_div4 dut(.clk(clk),.resetn(resetn),.s_valid(sv),.s_ready(sr),.s_a(source[259:132]),.s_b(source[131:4]),.s_mask(source[3:0]),.s_tag(st),.m_valid(mv),.m_ready(mr),.m_result(sink[139:12]),.m_mask(sink[11:8]),.m_tag(mt),.m_invalid(sink[7:4]),.m_overflow(sink[3:0]));
endmodule
