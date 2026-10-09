module audit_numeric;
import w8a8_fp32_pkg::*;
logic clk=0; always #2.5 clk=~clk;
logic resetn=0,sv=0,sr,mv,mr=0;
logic [31:0] a,b,y;logic[95:0] tag,ot;logic nf;
w8a8_fp32_mul dut(clk,resetn,sv,sr,a,b,tag,mv,mr,y,ot,nf);
logic[95:0] data[0:25046-1];logic[111:0] pkgdata[0:12000-1];
integer sent=0,got=0,cycles=0,j;logic[128:0] held;logic was_held=0;
logic[31:0] rng=32'hdd113789;
initial begin
 $readmemh("audit_mul.hex",data);$readmemh("audit_pkg.hex",pkgdata);
 for(j=0;j<12000;j=j+1)begin
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
  sv=sent<25046 && rng[4:2]!=0;
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
 if(got==25046)begin $display("AUDIT_NUMERIC_PASS mul=%d pkg=%d cycles=%d",got,12000,cycles);$finish;end
end
endmodule
