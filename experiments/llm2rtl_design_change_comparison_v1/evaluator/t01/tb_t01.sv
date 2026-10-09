`timescale 1ns/1ps
module tb_t01;
logic aclk=0; always #5 aclk=~aclk;
logic aresetn=0,cmd_valid=0,cmd_ready,done_valid,done_ready=0,done_error;
logic [3:0] cmd_opcode,done_tag; logic [2:0][3:0] cmd_bank,done_bank;
logic [111:0] cmd_payload; logic [1:0] done_bank_count;
logic act_read_valid,act_read_ready,weight_read_valid,weight_read_ready,dst_write_valid,dst_write_ready;
logic [3:0] act_read_bank,weight_read_bank,dst_write_bank,act_rsp_bank,weight_rsp_bank;
logic [15:0] act_read_addr,weight_read_addr,dst_write_addr,dst_write_strb;
logic act_rsp_valid,weight_rsp_valid; logic [255:0] act_rsp_data,weight_rsp_data;
logic [127:0] dst_write_data;
logic [127:0] am[0:36863],wm[0:36863],dm[0:36863],expected[0:36863];
logic [2:0] av=0,wv=0; logic [2:0][255:0] ad,wd;
logic [2:0][3:0] ab,wb;
int cycle=0,acap,wcap,dcap,alen,wlen,op,ba,bw,bd,err,writes,expected_writes,record_mode;
int fd,got,id; string suite,line,path; logic [111:0] p;
logic write_stalled=0; logic [159:0] held_write;
smollm2_gemm_systolic_wide_executor dut(.*);
assign act_rsp_valid=av[2]; assign weight_rsp_valid=wv[2];
assign act_rsp_data=ad[2]; assign weight_rsp_data=wd[2];
assign act_rsp_bank=ab[2]; assign weight_rsp_bank=wb[2];
// Different periodic stalls on each channel, plus three-cycle read latency.
assign act_read_ready=aresetn && cycle%7!=1 && cycle%7!=2;
assign weight_read_ready=aresetn && cycle%5!=1;
assign dst_write_ready=aresetn && cycle%11!=1 && cycle%11!=2 && cycle%11!=3;
always @(posedge aclk) begin
cycle<=cycle+1;
av<={av[1:0],aresetn && act_read_valid && act_read_ready};
wv<={wv[1:0],aresetn && weight_read_valid && weight_read_ready};
ad[2]<=ad[1];ad[1]<=ad[0];wd[2]<=wd[1];wd[1]<=wd[0];
ab[2]<=ab[1];ab[1]<=ab[0];wb[2]<=wb[1];wb[1]<=wb[0];
if(aresetn && act_read_valid && act_read_ready)begin
if(act_read_bank!=cmd_bank[0] || act_read_addr>=acap || (op==3 && act_read_addr+1>=acap))$fatal(1,"activation address/bank");
ad[0]<=op==3 ? {am[act_read_addr+1],am[act_read_addr]} : {128'd0,am[act_read_addr]};ab[0]<=act_read_bank;
end
if(aresetn && weight_read_valid && weight_read_ready)begin
if(weight_read_bank!=cmd_bank[1] || weight_read_addr>=wcap || (op==3 && weight_read_addr+1>=wcap))$fatal(1,"weight address/bank");
wd[0]<=op==3 ? {wm[weight_read_addr+1],wm[weight_read_addr]} : {128'd0,wm[weight_read_addr]};wb[0]<=weight_read_bank;
end
if(aresetn && write_stalled && (!dst_write_valid || {dst_write_addr,dst_write_strb,dst_write_data}!==held_write))$fatal(1,"write changed under stall");
write_stalled<=aresetn && dst_write_valid && !dst_write_ready;
held_write<={dst_write_addr,dst_write_strb,dst_write_data};
if(aresetn && dst_write_valid && dst_write_ready)begin
if(dst_write_bank!=cmd_bank[2] || dst_write_addr>=dcap || dst_write_strb==0)$fatal(1,"destination address/bank/mask");
for(int lane=0;lane<8;lane++)if(dst_write_strb[2*lane+:2]!=0 && dst_write_strb[2*lane+:2]!=3)$fatal(1,"partial BF16 byte strobe");
for(int b=0;b<16;b++)if(dst_write_strb[b])dm[dst_write_addr][8*b+:8]<=dst_write_data[8*b+:8];
writes<=writes+$countones(dst_write_strb)/2;
end
end
initial begin
if(!$value$plusargs("SUITE=%s",suite))suite="public";
record_mode=$test$plusargs("RECORD");
fd=$fopen({suite,"/cases.txt"},"r");if(!fd)$fatal(1,"missing cases");
repeat(4)@(negedge aclk);aresetn=1;
while(!$feof(fd))begin
 got=$fscanf(fd,"%d %d %d %d %d %h %d %d %d %d %d %d %d\n",id,op,ba,bw,bd,p,acap,wcap,dcap,alen,wlen,err,expected_writes);
 if(got!=13)$fatal(1,"bad case record fields=%d",got);
 for(int i=0;i<36864;i++)begin am[i]=0;wm[i]=0;dm[i]=128'hdeadbeefdeadbeefdeadbeefdeadbeef;end
 $readmemh($sformatf("%s/%0d_a.hex",suite,id),am,0,alen-1);
 $readmemh($sformatf("%s/%0d_w.hex",suite,id),wm,0,wlen-1);
 if(!record_mode)$readmemh($sformatf("%s/%0d_expected.hex",suite,id),expected,0,dcap-1);
 @(negedge aclk);writes=0;cmd_opcode=4'(op);cmd_bank={4'(bd),4'(bw),4'(ba)};cmd_payload=p;cmd_valid=1;
 if(!cmd_ready)$fatal(1,"not ready");
 @(negedge aclk);cmd_valid=0;
 wait(done_valid);@(negedge aclk);
 if(done_error!==1'(err) || done_bank!==cmd_bank || done_tag!==cmd_bank[0] || done_bank_count!=3 || writes!=expected_writes)$fatal(1,"completion case=%d err=%b writes=%d expected=%d",id,done_error,writes,expected_writes);
 repeat(4)begin @(negedge aclk);if(!done_valid || cmd_ready || done_error!==1'(err) || done_bank!==cmd_bank || done_tag!==cmd_bank[0] || done_bank_count!=3)$fatal(1,"completion did not hold");end
 if(record_mode)$writememh($sformatf("%s/%0d_expected.hex",suite,id),dm,0,dcap-1);
 else for(int i=0;i<dcap;i++)if(dm[i]!==expected[i])$fatal(1,"bank mismatch case=%d word=%d got=%h expected=%h",id,i,dm[i],expected[i]);
 $display("PASS T01 case=%0d opcode=%0d elements=%0d cycles=%0d",id,op,writes,cycle);
 done_ready=1;@(negedge aclk);done_ready=0;if(!cmd_ready)$fatal(1,"no ready after completion");
end
$fclose(fd);$display("PASS T01 suite");$finish;
end
initial begin #2000000000;$fatal(1,"T01 timeout");end
endmodule
