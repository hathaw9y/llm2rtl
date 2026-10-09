module audit_epilogue;
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
