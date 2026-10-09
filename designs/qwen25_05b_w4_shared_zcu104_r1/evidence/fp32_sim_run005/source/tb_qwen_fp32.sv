`timescale 1ns/1ps
module tb_qwen_fp32;
  import qwen_fp32_pkg::*;
  localparam integer COUNT=16384;
  logic clk=0;always #5 clk=~clk;
  logic rst_n=0,cmd_valid,cmd_ready,cmd_multiply,rsp_valid,rsp_ready,rsp_error;
  logic [9:0] cmd_id,rsp_id;
  logic [31:0] cmd_a,cmd_b,rsp_data;
  logic [97:0] vectors[0:COUNT-1];
  logic [47:0] cast_vectors[0:COUNT-1];
  integer sent=0,received=0,cycles=0;
  logic request_stalled=0;
  string vector_dir;
  qwen_fp32_pipe dut(.*);
  initial begin
    if(!$value$plusargs("VECTORS=%s",vector_dir)) $fatal(1,"VECTORS directory required");
    $readmemh({vector_dir,"/arithmetic.mem"},vectors);
    $readmemh({vector_dir,"/bf16.mem"},cast_vectors);
    for(integer i=0;i<COUNT;i=i+1) begin
      if(cast_vectors[i][46:39]!=8'hff && to_bf16(cast_vectors[i][47:16])!==cast_vectors[i][15:0])
        $fatal(1,"BF16 conversion mismatch vector %0d",i);
    end
    cmd_valid=0;rsp_ready=0;cmd_multiply=0;cmd_id=0;cmd_a=0;cmd_b=0;
    repeat(4) @(negedge clk);rst_n=1;
    while(received<COUNT) begin
      @(negedge clk);
      cycles=cycles+1;
      if(cycles>200000) $fatal(1,"timeout");
      rsp_ready=($urandom_range(0,3)!=0);
      cmd_valid=(sent<COUNT)&&(request_stalled || ($urandom_range(0,3)!=0));
      if(sent<COUNT) begin
        cmd_multiply=vectors[sent][97];cmd_a=vectors[sent][96:65];cmd_b=vectors[sent][64:33];cmd_id=10'(sent);
      end
      @(posedge clk);
      if(rsp_valid && rsp_ready) begin
        if(rsp_id!==10'(received) || rsp_error!==vectors[received][0])
          $fatal(1,"identity/error mismatch %0d",received);
        if(!rsp_error && rsp_data!==vectors[received][32:1])
          $fatal(1,"arithmetic mismatch %0d: a=%h b=%h multiply=%b got=%h expected=%h",received,vectors[received][96:65],vectors[received][64:33],vectors[received][97],rsp_data,vectors[received][32:1]);
        received=received+1;
      end
      if(cmd_valid && cmd_ready) sent=sent+1;
      request_stalled=cmd_valid && !cmd_ready;
    end
    @(negedge clk);cmd_valid=0;rsp_ready=1;
    repeat(4) @(negedge clk);
    if(rsp_valid) $fatal(1,"extra completion");
    // Cancel outstanding operations while output is stalled.
    rsp_ready=0;cmd_valid=1;cmd_a=32'h3f800000;cmd_b=32'h40000000;
    repeat(4) @(negedge clk);
    rst_n=0;cmd_valid=0;repeat(3) @(negedge clk);rst_n=1;
    repeat(4) @(negedge clk);
    if(rsp_valid) $fatal(1,"reset did not cancel pipeline");
    $display("PASS FP32 arithmetic/conversion=%0d, backpressure/ID/reset",COUNT);
    $finish;
  end
  logic stalled_r=0;
  logic [42:0] held_r;
  always @(posedge clk) begin
    if(rst_n && stalled_r && {rsp_valid,rsp_id,rsp_data}!==held_r) $fatal(1,"unstable stalled response");
    stalled_r<=rst_n && rsp_valid && !rsp_ready;
    held_r<={rsp_valid,rsp_id,rsp_data};
  end
endmodule
