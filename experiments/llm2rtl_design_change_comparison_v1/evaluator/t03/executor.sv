`timescale 1ns/1ps
module t03_executor;
logic aclk=0; always #5 aclk=~aclk;
logic aresetn=0,cmd_valid=0,cmd_ready; logic[3:0]cmd_opcode=3;
logic[2:0][3:0]cmd_bank={4'd4,4'd3,4'd2}; logic[111:0]cmd_payload;
logic done_valid,done_ready=0,done_error; logic[3:0]done_tag; logic[1:0]done_bank_count; logic[2:0][3:0]done_bank;
logic act_read_valid,act_read_ready=1,act_rsp_valid=0; logic[3:0]act_read_bank,act_rsp_bank;
logic[15:0]act_read_addr; logic[255:0]act_rsp_data;
logic weight_read_valid,weight_read_ready=1,weight_rsp_valid=0; logic[3:0]weight_read_bank,weight_rsp_bank;
logic[15:0]weight_read_addr; logic[255:0]weight_rsp_data;
logic dst_write_valid,dst_write_ready=1; logic[3:0]dst_write_bank;
logic[15:0]dst_write_addr,dst_write_strb; logic[127:0]dst_write_data;
smollm2_gemm_systolic_wide_executor dut(.*);
bit baseline;
function automatic bit selected(input int count);
 bit pub;begin pub=(count==1||count==2||count==8||count==16||count==31||count==32);selected=$test$plusargs("public")?pub:$test$plusargs("hidden")?!pub:1;end
endfunction int rows,first_row,ncols,ktotal,writes,read_count;
bit written[0:6143]; int index,row,col,element; logic[15:0]gold;
always @(posedge aclk) begin
 if(!aresetn) begin act_rsp_valid<=0;weight_rsp_valid<=0; end
 else begin
  act_rsp_valid<=act_read_valid&&act_read_ready;
  weight_rsp_valid<=weight_read_valid&&weight_read_ready;
  if(act_read_valid&&act_read_ready) begin
   if(act_read_bank!=2) $fatal(1,"act bank");
   act_rsp_bank<=act_read_bank; read_count++;
   for(int lane=0;lane<16;lane++) begin
    // Address is in 128-bit words; response includes this and its successor.
    element=act_read_addr*8+lane;
    act_rsp_data[lane*16+:16]<=16'h3f80+16'((element/ktotal)%4)*16'h0080;
   end
  end
  if(weight_read_valid&&weight_read_ready) begin
   if(weight_read_bank!=3) $fatal(1,"weight bank");
   weight_rsp_bank<=weight_read_bank; read_count++;
   for(int lane=0;lane<16;lane++) begin
    element=weight_read_addr*8+lane;
    weight_rsp_data[lane*16+:16]<=16'h3f80+16'((element/ktotal)%3)*16'h0080;
   end
  end
  if(dst_write_valid&&dst_write_ready) begin
   if(dst_write_bank!=4 || dst_write_strb==0) $fatal(1,"write bank/empty strobe");
   for(int lane=0;lane<8;lane++) begin
    if(dst_write_strb[lane*2+:2]!=0) begin
     if(dst_write_strb[lane*2+:2]!=3) $fatal(1,"partial BF16 strobe");
     index=dst_write_addr*8+lane; row=index/ncols; col=index%ncols;
     if(index>=rows*ncols || written[index]) $fatal(1,"out of bounds/duplicate write");
     written[index]=1; writes++;
     gold=(ktotal==16?16'h4180:16'h4280)+16'((row+first_row)%4+col%3)*16'h0080;
     if(dst_write_data[lane*16+:16]!==gold) $fatal(1,"numeric row=%0d col=%0d got=%h expected=%h",row,col,dst_write_data[lane*16+:16],gold);
    end
   end
  end
 end
end
task automatic execute(input int raw,input int start,input int logical_rows,input int n,input int k,input bit invalid);
 int cycles;
 begin
  @(negedge aclk); rows=logical_rows;first_row=start;ncols=n;ktotal=k;writes=0;read_count=0;
  for(int i=0;i<6144;i++) written[i]=0;
  while(!cmd_ready) @(negedge aclk);
  cmd_payload={49'd0,16'd0,16'(n),6'(start),6'(raw),11'(k),8'(n)};
  cmd_valid=1; @(negedge aclk);cmd_valid=0;cycles=0;
  while(!done_valid&&cycles<200000) begin @(negedge aclk);cycles++;end
  if(cycles==200000) $fatal(1,"executor timeout");
  if(done_tag!=2||done_bank_count!=3||done_bank!==cmd_bank) $fatal(1,"completion metadata");
  if(invalid) begin if(!done_error||writes||read_count) $fatal(1,"invalid command side effects");end
  else begin
   if(done_error||writes!=rows*n) $fatal(1,"output/completion count");
   for(int i=0;i<rows*n;i++) if(!written[i]) $fatal(1,"missing output");
  end
  // Completion must remain stable under backpressure and must be consumed once.
  repeat(3) begin @(negedge aclk); if(!done_valid) $fatal(1,"completion lost");end
  done_ready=1;@(negedge aclk);done_ready=0;
  repeat(2) @(negedge aclk);
  if(done_valid) $fatal(1,"duplicate completion");
 end
endtask
initial begin
 baseline=$test$plusargs("baseline"); repeat(4) @(negedge aclk);aresetn=1;
 for(int count=1;count<=32;count++) if(selected(count)) begin
  execute(baseline?count:count-1,32-count,count,17,16,0);
 end
 execute(baseline?1:0,0,1,192,64,0);
 for(int count=1;count<=32;count++) if(selected(count)) execute(baseline?count:count-1,33-count,count,1,16,1);
 for(int raw=baseline?33:32;raw<64;raw++) execute(raw,0,1,1,16,1);
 if(baseline) execute(0,0,1,1,16,1);
 $display("T03_EXECUTOR_PASS");$finish;
end
endmodule
