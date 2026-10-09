`timescale 1ns/1ps
module tb_t02;
logic aclk=0; always #5 aclk=~aclk;
logic aresetn=0, cmd_valid=0, cmd_ready;
logic [3:0] cmd_opcode=3;
logic [2:0][3:0] cmd_bank;
logic [111:0] cmd_payload=0;
logic done_valid, done_ready=0;
logic [3:0] done_tag; logic [1:0] done_bank_count;
logic [2:0][3:0] done_bank; logic done_error;
logic act_read_valid,act_read_ready=1; logic [3:0] act_read_bank;
logic [15:0] act_read_addr; logic act_rsp_valid;
logic [3:0] act_rsp_bank=2; logic [255:0] act_rsp_data;
logic weight_read_valid,weight_read_ready=1; logic [3:0] weight_read_bank;
logic [15:0] weight_read_addr; logic weight_rsp_valid;
logic [3:0] weight_rsp_bank=3; logic [255:0] weight_rsp_data;
logic dst_write_valid,dst_write_ready=1; logic [3:0] dst_write_bank;
logic [15:0] dst_write_addr,dst_write_strb; logic [127:0] dst_write_data;
logic [127:0] act_mem[0:2303], weight_mem[0:13823], dst_mem[0:6143];
logic [15:0] expected[0:6143];
logic [2:0] av=0,wv=0; logic [2:0][255:0] ad,wd;
int k,n,m,mstart,nstart,ntotal,writes=0, cycles=0;
string af,wf,ef;
smollm2_gemm_systolic_wide_executor dut(.*);
assign act_rsp_valid=av[2]; assign weight_rsp_valid=wv[2];
assign act_rsp_data=ad[2]; assign weight_rsp_data=wd[2];
always @(posedge aclk) begin
 cycles<=cycles+1;
 if(cycles>2000000)$fatal(1,"timeout");
 if(!aresetn)begin av<=0;wv<=0;end
 else begin
  av<={av[1:0],act_read_valid&&act_read_ready};
  wv<={wv[1:0],weight_read_valid&&weight_read_ready};
  ad[2]<=ad[1];ad[1]<=ad[0]; wd[2]<=wd[1];wd[1]<=wd[0];
  if(act_read_valid&&act_read_ready) begin
   if(act_read_bank!=2 || act_read_addr[0] || act_read_addr+1>=2304)$fatal(1,"activation bounds");
   ad[0]<={act_mem[act_read_addr+1],act_mem[act_read_addr]};
  end
  if(weight_read_valid&&weight_read_ready) begin
   if(weight_read_bank!=3 || weight_read_addr[0] || weight_read_addr+1>=(n*k+7)/8)$fatal(1,"weight bounds");
   wd[0]<={weight_mem[weight_read_addr+1],weight_mem[weight_read_addr]};
  end
  if(dst_write_valid&&dst_write_ready) begin
   if(dst_write_bank!=4 || dst_write_addr>=6144 || $countones(dst_write_strb)!=2)$fatal(1,"write contract");
   for(int b=0;b<16;b++)if(dst_write_strb[b])begin
    if((dst_write_addr*8+b/2)/ntotal>=m || (dst_write_addr*8+b/2)%ntotal<nstart ||
       (dst_write_addr*8+b/2)%ntotal>=nstart+n)$fatal(1,"write outside tile");
    dst_mem[dst_write_addr][b*8+:8]<=dst_write_data[b*8+:8];
   end
   writes<=writes+1;
  end
 end
end
initial begin
 if(!$value$plusargs("K=%d",k)||!$value$plusargs("N=%d",n)||!$value$plusargs("M=%d",m)||
    !$value$plusargs("ACT=%s",af)||!$value$plusargs("WEIGHT=%s",wf)||!$value$plusargs("EXPECTED=%s",ef))$fatal(1,"args");
 mstart=1;nstart=3;ntotal=n+5;
 cmd_bank[0]=2;cmd_bank[1]=3;cmd_bank[2]=4;
 for(int i=0;i<2304;i++)act_mem[i]=0;
 for(int i=0;i<13824;i++)weight_mem[i]=0;
 for(int i=0;i<6144;i++)dst_mem[i]={8{16'h5a5a}};
 $readmemh(af,act_mem,0,((m+1)*k+7)/8-1);
 $readmemh(wf,weight_mem,0,(n*k+7)/8-1);
 $readmemh(ef,expected,0,m*n-1);
 repeat(4)@(negedge aclk);aresetn=1;
 @(negedge aclk);
 cmd_payload={49'd0,16'(nstart),16'(ntotal),6'(mstart),6'(m),11'(k),8'(n)};
 if(!cmd_ready)$fatal(1,"not ready");cmd_valid=1;
 @(negedge aclk);cmd_valid=0;
 wait(done_valid);#1;
 if(done_error||done_tag!=2||done_bank_count!=3||done_bank!=cmd_bank||writes!=m*n)$fatal(1,"completion");
 for(int i=0;i<m*ntotal+8;i++)begin
  if(i/ntotal<m&&i%ntotal>=nstart&&i%ntotal<nstart+n)begin
   if(dst_mem[i/8][16*(i%8)+:16]!==expected[(i/ntotal)*n+i%ntotal-nstart])
    $fatal(1,"BF16 mismatch i=%0d actual=%h expected=%h",i,dst_mem[i/8][16*(i%8)+:16],expected[(i/ntotal)*n+i%ntotal-nstart]);
  end else if(dst_mem[i/8][16*(i%8)+:16]!==16'h5a5a)$fatal(1,"sentinel");
 end
 repeat(3)@(negedge aclk);
 if(!done_valid||cmd_ready)$fatal(1,"completion hold");
 done_ready=1;@(negedge aclk);done_ready=0;
 if(!cmd_ready)$fatal(1,"completion release");
 $display("T02_RTL_PASS writes=%0d cycles=%0d",writes,cycles);$finish;
end
endmodule
