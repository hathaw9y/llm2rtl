module tb;
logic clk=0;always #2.5 clk=~clk;
logic resetn=0,sv=0,sr,mv,mr=0;logic[31:0] a,b,result;logic[95:0] st,mt;logic nf;
w8a8_fp32_mul mul(clk,resetn,sv,sr,a,b,st,mv,mr,result,mt,nf);
logic iv=0,ir,ov,orr=0;logic[127:0] sums,scales;logic[3:0] mask,om;logic[95:0] it,ot;logic[63:0] bf;logic err;
fp32_bf16_epilogue epi(clk,resetn,iv,ir,sums,scales,mask,it,ov,orr,bf,om,ot,err);
logic [95:0] muldata[0:11972-1];logic[327:0] edata[0:4864-1];
integer mi=0,mo=0,ei=0,eo=0,cycle=0;integer mcycle[0:11972-1],ecycle[0:4864-1];
logic [95:0] heldmul;logic [164:0] heldepi;logic mh=0,eh=0;
initial begin $readmemh("mul.hex",muldata);$readmemh("epi.hex",edata); repeat(4) @(negedge clk);resetn=1;wait(cycle==50);@(negedge clk);resetn=0;sv=0;iv=0;mi=0;mo=0;ei=0;eo=0;mh=0;eh=0;repeat(2)@(negedge clk);resetn=1;end
always @(negedge clk) if(resetn) begin
 cycle=cycle+1;mr=(cycle<40)||((cycle%7!=1)&&(cycle%7!=2));orr=(cycle<40)||((cycle%9!=2)&&(cycle%9!=3));
 if(!sv||st!=96'(mi)) begin sv=mi<11972 && ((cycle<40)||cycle%5!=0);if(sv)begin a=muldata[mi][95:64];b=muldata[mi][63:32];st=96'(mi);end end
 if(!iv||it[31:0]!=32'(ei)) begin iv=ei<4864 && ((cycle<40)||cycle%6!=0);if(iv)begin sums=edata[ei][327:200];scales=edata[ei][199:72];mask=edata[ei][71:68];it={64'habcdefff01234567,32'(ei)};end end
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
 if(mo==11972&&eo==4864)begin $display("PASS_FP32_EPILOGUE");$finish;end
end
endmodule
