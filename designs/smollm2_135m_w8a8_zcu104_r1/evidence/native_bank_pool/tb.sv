`timescale 1ns/1ps
module tb;
logic clk;
logic resetn;
logic [15:0] rd_valid;
logic [15:0] rd_ready;
logic [303:0] rd_word_address;
logic [15:0] rd_wide;
logic [15:0] rd_resp_valid;
logic [4095:0] rd_data;
logic [15:0] wr_valid;
logic [15:0] wr_ready;
logic [303:0] wr_word_address;
logic [2047:0] wr_data;
logic [255:0] wr_strb;
logic [511:0] wr_transaction_id;
logic [511:0] wr_generation;
logic [79:0] wr_role;
logic [15:0] wr_commit;
logic [15:0] wr_pending;
logic [15:0] coverage_pending;
logic [15:0] bank_quiescent;
logic [15:0] bank_ready;
logic epoch_valid;
logic epoch_ready;
logic [7:0] epoch_error_code;
logic [3:0] epoch_bank;
logic [1:0] epoch_component;
logic [31:0] epoch_token;
logic [31:0] epoch_generation;
logic [4:0] epoch_profile;
logic [10:0] epoch_rows;
logic [15:0] epoch_cols;
logic [9:0] epoch_position;
logic [4:0] epoch_layer;
logic [31:0] epoch_data_offset;
logic [31:0] epoch_data_bytes;
logic [31:0] epoch_scale_offset;
logic [31:0] epoch_scale_bytes;
logic [15:0] epoch_done_valid;
logic [15:0] epoch_done_ready;
logic [511:0] epoch_done_token;
logic [511:0] epoch_done_generation;
logic [31:0] epoch_done_component;
logic coverage_valid;
logic coverage_ready;
logic [3:0] coverage_bank;
logic [1:0] coverage_component;
logic [31:0] coverage_generation;
logic [31:0] coverage_transaction_id;
logic [4:0] coverage_role;
logic coverage_data_complete;
logic coverage_scale_complete;
logic fault_valid;
logic [3:0] fault_bank;
logic [7:0] fault_error_code;
smollm2_native_bank_pool dut(.*);

initial clk=0;always #2.5 clk=~clk;
logic[127:0]shadow[16][36864];logic[15:0]known[16][36864],covshadow[16][36864];
integer off[16][2],len[16][2],remain[16][2];integer gen[16][2];
logic[1:0]complete[16];
logic[255:0]expected_data[16][3];logic[31:0]expected_mask[16][3];logic[2:0]pv[16];
integer qhead[16],qtail[16];logic[1:0]qcomp[16][8];integer qgen[16][8],qtxn[16][8],qrole[16][8];
logic qdata[16][8],qscale[16][8];integer assertions=0,reads=0,writes=0,pubs=0;
logic stalled;logic[110:0]stalled_payload;
task check(input logic ok,input string msg);assertions++;if(!ok)$fatal(1,"%s",msg);endtask
task tick;@(posedge clk);#1;@(negedge clk);endtask
always @(posedge clk)begin:oracle
integer a,component,d0,d1,oldleft0,oldleft1;logic old0,old1;logic[255:0]edata;logic[31:0]emask;logic[110:0]payload;
if(!resetn)begin
 stalled=0;
 for(int b=0;b<16;b++)begin pv[b]=0;qhead[b]=0;qtail[b]=0;complete[b]=0;
  for(int r=0;r<2;r++)begin off[b][r]=0;len[b][r]=0;remain[b][r]=0;gen[b][r]=0;end
  for(int w=0;w<36864;w++)covshadow[b][w]=0;
 end
end else begin
 payload={coverage_bank,coverage_component,coverage_generation,coverage_transaction_id,coverage_role,coverage_data_complete,coverage_scale_complete,34'd0};
 if(stalled)check(coverage_valid&&payload===stalled_payload,"stable held publication");
 stalled=coverage_valid&&!coverage_ready;if(stalled)stalled_payload=payload;
 if(coverage_valid&&coverage_ready)begin
  a=coverage_bank;check(qhead[a]<qtail[a],"unexpected publication");
  check(coverage_component==qcomp[a][qhead[a]]&&coverage_generation==qgen[a][qhead[a]]&&
    coverage_transaction_id==qtxn[a][qhead[a]]&&coverage_role==qrole[a][qhead[a]]&&
    coverage_data_complete==qdata[a][qhead[a]]&&coverage_scale_complete==qscale[a][qhead[a]],"publication exact independent byte union");
  qhead[a]++;pubs++;
 end
 for(int b=0;b<16;b++)begin
  check(rd_resp_valid[b]===pv[b][2],"exact read latency3/one response");
  if(pv[b][2])begin
   for(int k=0;k<32;k++)if(expected_mask[b][2][k])check(rd_data[b*256+k*8+:8]===expected_data[b][2][k*8+:8],"native byte canary/packing");
   reads++;
  end
  for(int z=2;z>0;z--)begin expected_data[b][z]=expected_data[b][z-1];expected_mask[b][z]=expected_mask[b][z-1];end
  pv[b]={pv[b][1:0],rd_valid[b]&&rd_ready[b]};
  if(rd_valid[b]&&rd_ready[b])begin
    a=rd_word_address[b*19+:19];edata={128'd0,shadow[b][a]};emask={16'hffff,known[b][a]};
    if(rd_wide[b])begin edata={shadow[b][a+1],shadow[b][a]};emask={known[b][a+1],known[b][a]};end
    expected_data[b][0]=edata;expected_mask[b][0]=emask;
  end
 end
 if(epoch_valid&&epoch_ready&&epoch_error_code==0)begin
  a=epoch_bank;
  if(a==7&&epoch_component==2)begin
   off[a][1]=epoch_data_offset;len[a][1]=epoch_data_bytes;remain[a][1]=epoch_data_bytes;
   gen[a][1]=epoch_generation;complete[a][1]=0;
  end else begin
   off[a][0]=epoch_data_offset;len[a][0]=epoch_data_bytes;remain[a][0]=epoch_data_bytes;
   gen[a][0]=epoch_generation;complete[a][0]=0;
   if(a!=7||epoch_component==0)begin off[a][1]=epoch_scale_offset;len[a][1]=epoch_scale_bytes;
    remain[a][1]=epoch_scale_bytes;gen[a][1]=epoch_generation;complete[a][1]=epoch_scale_bytes==0;end
  end
  for(int w=epoch_data_offset/16;w<(epoch_data_offset+epoch_data_bytes)/16;w++)covshadow[a][w]=0;
  for(int w=epoch_scale_offset/16;w<(epoch_scale_offset+epoch_scale_bytes)/16;w++)covshadow[a][w]=0;
  qhead[a]=0;qtail[a]=0;
 end
 for(int b=0;b<16;b++)if(wr_commit[b])begin
   a=wr_word_address[b*19+:19];d0=0;d1=0;old0=complete[b][0];old1=complete[b][1];oldleft0=remain[b][0];oldleft1=remain[b][1];
   for(int k=0;k<16;k++)if(wr_strb[b*16+k])begin
    shadow[b][a][k*8+:8]=wr_data[b*128+k*8+:8];known[b][a][k]=1;
    if(!covshadow[b][a][k])begin
     if(a*16+k>=off[b][0]&&a*16+k<off[b][0]+len[b][0])d0++;
     if(a*16+k>=off[b][1]&&a*16+k<off[b][1]+len[b][1])d1++;
    end
    covshadow[b][a][k]=1;
   end
   remain[b][0]-=d0;remain[b][1]-=d1;
   if(remain[b][0]==0)complete[b][0]=1;if(remain[b][1]==0)complete[b][1]=1;
   if((!old0&&d0>0&&remain[b][0]==0)||(!old1&&d1>0&&remain[b][1]==0))begin
    component=b==7?(d0>0?1:2):0;
    qcomp[b][qtail[b]]=2'(component);qgen[b][qtail[b]]=wr_generation[b*32+:32];
    qtxn[b][qtail[b]]=wr_transaction_id[b*32+:32];qrole[b][qtail[b]]=wr_role[b*5+:5];
    qdata[b][qtail[b]]=b==7?1:complete[b][0];qscale[b][qtail[b]]=b==7?1:complete[b][1];qtail[b]++;
   end
   writes++;
 end
end
end
task epoch(input integer b,p,rows,cols,comp,g,dataoff,databytes,scaleoff,scalebytes,input integer expected_error=0);
 @(negedge clk);epoch_bank=4'(b);epoch_profile=5'(p);epoch_rows=11'(rows);epoch_cols=16'(cols);
 epoch_component=2'(comp);epoch_generation=32'(g);epoch_token=32'(100+g);
 epoch_data_offset=32'(dataoff);epoch_data_bytes=32'(databytes);epoch_scale_offset=32'(scaleoff);epoch_scale_bytes=32'(scalebytes);
 epoch_valid=1;#1;while(!epoch_ready)tick();check(epoch_error_code==8'(expected_error),"epoch eligibility/error");tick();epoch_valid=0;
 if(expected_error==0)begin
  check(!bank_ready[b],"epoch clear must block bank");while(!epoch_done_valid[b])tick();
  check(epoch_done_token[b*32+:32]==32'(100+g)&&epoch_done_generation[b*32+:32]==32'(g)&&epoch_done_component[b*2+:2]==2'(comp),"epoch done identity");
  check(!bank_ready[b],"epoch ACK accounted");epoch_done_ready[b]=1;tick();epoch_done_ready[b]=0;check(bank_ready[b],"epoch activated");
 end
endtask
task write(input integer b,a,input logic[15:0]strb,input logic[127:0]data,input integer g);
 @(negedge clk);wr_valid[b]=1;wr_word_address[b*19+:19]=19'(a);wr_strb[b*16+:16]=strb;
 wr_data[b*128+:128]=data;wr_generation[b*32+:32]=32'(g);wr_transaction_id[b*32+:32]=32'(900+b);wr_role[b*5+:5]=5'd1;
 #1;check(wr_ready[b]&&wr_commit[b],"legal write II1");tick();wr_valid[b]=0;
endtask
task burst(input integer b,start,count,g);
 @(negedge clk);wr_valid[b]=1;wr_generation[b*32+:32]=32'(g);wr_transaction_id[b*32+:32]=32'(900+b);wr_role[b*5+:5]=1;
 for(int i=0;i<count;i++)begin
  wr_word_address[b*19+:19]=19'(start+i);wr_strb[b*16+:16]=16'hffff;
  for(int k=0;k<16;k++)wr_data[b*128+k*8+:8]=8'(i*17+k+b);
  #1;check(wr_ready[b]&&wr_commit[b],"burst II1 every cycle");tick();
 end
 wr_valid[b]=0;
endtask
task read(input integer b,a,input bit wide);
 logic[255:0]held_data;
 @(negedge clk);rd_valid[b]=1;rd_word_address[b*19+:19]=19'(a);rd_wide[b]=wide;
 #1;check(rd_ready[b],"legal read");tick();rd_valid[b]=0;repeat(4)tick();
 held_data=rd_data[b*256+:256];rd_word_address[b*19+:19]=19'(a^1);rd_wide[b]=!wide;
 repeat(4)begin tick();check(rd_data[b*256+:256]===held_data,"disabled read output hold");end
endtask
task drain;integer timeout;timeout=0;while(wr_pending!=0||coverage_valid)begin tick();timeout++;check(timeout<1000,"publication drain timeout");end endtask
initial begin
resetn=0;
rd_valid=0;
rd_word_address=0;
rd_wide=0;
wr_valid=0;
wr_word_address=0;
wr_data=0;
wr_strb=0;
wr_transaction_id=0;
wr_generation=0;
wr_role=0;
epoch_valid=0;
epoch_bank=0;
epoch_component=0;
epoch_token=0;
epoch_generation=0;
epoch_profile=0;
epoch_rows=0;
epoch_cols=0;
epoch_position=0;
epoch_layer=0;
epoch_data_offset=0;
epoch_data_bytes=0;
epoch_scale_offset=0;
epoch_scale_bytes=0;
epoch_done_ready=0;
coverage_ready=0;

for(int b=0;b<16;b++)for(int w=0;w<36864;w++)begin shadow[b][w]=0;known[b][w]=0;covshadow[b][w]=0;end
coverage_ready=1;tick();resetn=1;while(bank_ready!=16'hffff)tick();check(!fault_valid,"boot");
$display("BOOT_COMPLETE");
epoch(0,1,1,576,0,1,0,1152,0,0);
write(0,0,16'hffff,128'hffeeddccbbaa99887766554433221100,1);
// Consecutive sameword RMW partial/duplicate/zero coverage and data canaries.
@(negedge clk);wr_valid[0]=1;wr_word_address[0+:19]=1;wr_generation[0+:32]=1;wr_transaction_id[0+:32]=900;wr_role[0+:5]=1;
for(int t=0;t<8;t++)begin wr_strb[0+:16]=t==0?16'h000f:t==1?16'h00f0:t==2?16'h000f:t==3?16'h0f00:t==4?16'hf000:16'h0000;
 wr_data[0+:128]={4{32'(t+1)}};#1;check(wr_ready[0],"sameword II1");tick();end
wr_valid[0]=0;read(0,0,0);read(0,1,0);burst(0,2,69,1);drain();check(qtail[0]==0,"gap blocks completeness");
write(0,71,16'hffff,128'h123456789abcdef,1);drain();check(qtail[0]==1,"missing final gap closes");
// Rejected extents/gen cannot reset coverage or overwrite tensor data.
epoch(0,1,1,576,0,1,0,1152,0,0,7);read(0,0,0);
epoch(0,1,1,576,0,2,0,1168,0,0,7);read(0,1,0);
epoch(0,1,1,576,0,2,0,1152,0,0);read(0,0,0);read(0,1,0);
// Per-profile exact sidecar padding; hold a publication while scale event follows.
epoch(14,23,17,576,0,1,0,9792,18432,80);coverage_ready=0;burst(14,0,612,1);
while(!coverage_valid)tick();check(coverage_bank==14&&coverage_data_complete&&!coverage_scale_complete,"Q held data complete");
burst(14,1152,4,1);repeat(8)tick();check(wr_pending[14],"Q padding gap remains pending heldevent");
write(14,1156,16'hffff,128'hf00d,1);repeat(8)tick();check(coverage_valid&&!coverage_scale_complete,"stalled event unchanged");
coverage_ready=1;drain();check(qtail[14]==2&&qhead[14]==2,"Q two publications lossless");read(14,1156,1);read(14,1156,0);read(14,1157,0);
epoch(3,6,1,576,0,1,0,576,294912,16);burst(3,0,36,1);write(3,18432,16'hffff,128'h1122,1);drain();read(3,0,1);read(3,1,0);read(3,18432,1);
epoch(8,12,1,192,0,1,0,192,196608,16);burst(8,0,12,1);write(8,12288,16'hffff,128'h3344,1);drain();read(8,12288,1);
epoch(9,14,1,192,0,1,0,192,196608,48);burst(9,0,12,1);burst(9,12288,3,1);drain();read(9,12290,1);
epoch(13,22,17,17,0,1,0,4896,294912,80);burst(13,18432,5,1);burst(13,0,306,1);drain();read(13,18436,1);
// B7 component epochs preserve actual bytes and opposite exact coverage.
epoch(7,11,2,64,0,10,0,256,4096,1920);burst(7,0,16,10);burst(7,256,120,10);drain();read(7,256,0);
epoch(7,11,1,64,1,11,0,128,0,0);read(7,256,0);burst(7,0,8,11);drain();
epoch(7,11,30,64,2,12,4096,1920,0,0);read(7,0,0);burst(7,256,120,12);drain();
// Full largest bank capacity and logarithmic last-word addressing in actual XPM.
epoch(10,16,32,1024,0,1,0,589824,0,0);burst(10,0,36864,1);drain();read(10,0,0);read(10,36863,0);
epoch(15,4,192,1536,0,1,0,294912,294912,48);burst(15,0,18432,1);burst(15,18432,3,1);drain();read(15,18432,1);read(15,18434,1);
epoch(6,10,32,192,0,1,0,12288,0,0);burst(6,0,768,1);drain();read(6,767,0);
epoch(12,20,1,49152,0,1,0,98304,0,0);burst(12,0,6144,1);drain();read(12,6143,0);
// All remaining banks and simultaneous completions with scalar arbiter.
epoch(1,2,1,576,0,1,0,1152,0,0);epoch(2,3,1,576,0,1,0,1152,0,0);
epoch(4,7,1,576,0,1,0,1152,0,0);epoch(5,8,1,192,0,1,0,384,0,0);epoch(11,19,1,576,0,1,0,1152,0,0);
burst(1,0,71,1);burst(2,0,71,1);coverage_ready=0;
@(negedge clk);wr_valid[1]=1;wr_valid[2]=1;
for(int b=1;b<3;b++)begin wr_word_address[b*19+:19]=71;wr_strb[b*16+:16]=16'hffff;wr_generation[b*32+:32]=1;wr_transaction_id[b*32+:32]=32'(900+b);wr_role[b*5+:5]=1;wr_data[b*128+:128]=128'hcafe;end
#1;check(wr_ready[1]&&wr_ready[2],"parallel bank writes");tick();wr_valid=0;repeat(8)tick();check(wr_pending[1]&&wr_pending[2],"simultaneous publications retained");coverage_ready=1;drain();
burst(4,0,72,1);burst(5,0,24,1);burst(11,0,72,1);drain();
// Invalid native request no enable/acceptance; no-touch checked via real reads.
@(negedge clk);rd_valid[3]=1;rd_wide[3]=1;rd_word_address[57+:19]=1;#1;check(!rd_ready[3],"oddwide rejected");tick();rd_valid=0;
check(fault_valid&&fault_error_code==7,"sticky fault");
@(negedge clk);wr_valid[0]=1;wr_word_address[0+:19]=0;wr_strb[0+:16]=16'hffff;wr_generation[0+:32]=1;#1;check(!wr_ready[0],"stale generation no write");tick();wr_valid=0;read(0,0,0);
@(negedge clk);rd_valid[10]=1;rd_word_address[190+:19]=36864;#1;check(!rd_ready[10],"capacity bound");tick();rd_valid=0;
// Last allocated word reads remain legal even for ignored/unwritten tails.
read(0,2303,0);
read(1,2303,0);
read(2,2303,0);
read(3,18463,0);
read(4,2303,0);
read(5,2303,0);
read(6,767,0);
read(7,375,0);
read(8,12289,0);
read(9,12291,0);
read(10,36863,0);
read(11,2303,0);
read(12,6143,0);
read(13,18437,0);
read(14,1157,0);
read(15,18439,0);

// Coordinated reset cancels read response pipeline and wipes only coverage.
@(negedge clk);rd_valid[3]=1;rd_wide[3]=1;rd_word_address[57+:19]=0;tick();rd_valid=0;
resetn=0;tick();check(rd_resp_valid==0&&bank_ready==0,"reset native pipeline/init");resetn=1;
while(bank_ready!=16'hffff)tick();check(!fault_valid&&!coverage_valid&&wr_pending==0,"reset no stale completion/fault");
read(0,0,0);read(3,0,1);read(10,36863,0);
repeat(6)tick();check(wr_pending==0&&coverage_pending==0,"final committed drain");
$display("COUNTS assertions=%0d reads=%0d writes=%0d pubs=%0d",assertions,reads,writes,pubs);
$display("PASS_NATIVE_BANK_POOL_ACTUAL_XPM");$finish;
end
initial begin #2000000;$fatal(1,"timeout");end
endmodule
