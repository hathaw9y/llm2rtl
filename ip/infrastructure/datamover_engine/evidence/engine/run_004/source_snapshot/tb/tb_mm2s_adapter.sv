`timescale 1ns/1ps
module tb_mm2s_adapter;
  parameter integer BANK_WIDTH=32;
  logic clk=0,rstn=0,start=0,done,abort_req=0,valid=0,ready,last=0,en;
  logic [63:0] data=0;
  logic [7:0] keep=0;
  logic [5:0] addr;
  logic [BANK_WIDTH-1:0] wrdata;
  logic [BANK_WIDTH/8-1:0] we;
  logic [22:0] offset=0;
  integer accepted=0,written=0;
  logic [7:0] memory[512];
  always #5 clk=~clk;
  always @(posedge clk) if(rstn) begin
    if(valid && ready) accepted=accepted+1;
    if(en) for(integer j=0;j<BANK_WIDTH/8;j=j+1) if(we[j]) begin
      memory[int'(addr)*(BANK_WIDTH/8)+j]=wrdata[j*8+:8];written=written+1;
    end
  end
  mm2s_adapter #(.BANK_ADDRA_WIDTH(6),.BANK_DINA_WIDTH(BANK_WIDTH)) dut(
    .aclk(clk),.aresetn(rstn),.s_ctrl_mm2s_adapter_start(start),
    .s_ctrl_mm2s_adapter_done(done),.s_ctrl_mm2s_adapter_abort(abort_req),
    .s_ctrl_mm2s_adapter_offset(offset),.s_axis_mm2s_tdata(data),
    .s_axis_mm2s_tkeep(keep),.s_axis_mm2s_tvalid(valid),
    .s_axis_mm2s_tready(ready),.s_axis_mm2s_tlast(last),
    .bank_ena(en),.bank_addra(addr),.bank_dina(wrdata),.bank_wea(we));
  task automatic send(input logic [63:0] d,input logic [7:0] k,input logic l);
    @(negedge clk);valid=1;data=d;keep=k;last=l;
    do @(posedge clk);while(!ready);
  endtask
  initial begin
    for(integer i=0;i<512;i=i+1) memory[i]=8'hee;
    repeat(3) @(negedge clk);rstn=1;start=1;
    fork
      begin
        send(64'h0706050403020100,8'hff,1);
        send(64'h1716151413121110,8'hff,1);
        @(negedge clk);valid=0;
      end
      begin
        wait(done);@(negedge clk);
        if(accepted!=1 || written!=8) $fatal(1,"next packet consumed too early");
        start=0;repeat(2) @(negedge clk);
        offset=23'd32;start=1;
        wait(done);@(negedge clk);start=0;
      end
    join
    if(accepted!=2 || written!=16) $fatal(1,"packet loss");
    for(integer i=0;i<8;i=i+1)
      if(memory[i]!==8'(i) || memory[32+i]!==8'(16+i)) $fatal(1,"wrong bank payload");
    repeat(2) @(negedge clk);offset=23'd64;start=1;
    send(64'h2726252423222120,8'h1f,1);
    @(negedge clk);valid=0;
    wait(done);@(negedge clk);start=0;
    if(written!=21 || memory[69]!==8'hee) $fatal(1,"tail mask failure");
    for(integer i=0;i<5;i=i+1) if(memory[64+i]!==8'(32+i)) $fatal(1,"tail byte failure");
    repeat(2) @(negedge clk);start=1;abort_req=1;
    @(negedge clk);
    if(en || ready) $fatal(1,"abort did not block writes/input");
    wait(done);@(negedge clk);abort_req=0;start=0;
    repeat(2) @(negedge clk);offset=23'd96;start=1;
    send(64'h3736353433323130,8'hff,1);
    @(negedge clk);valid=0;wait(done);
    for(integer i=0;i<8;i=i+1) if(memory[96+i]!==8'(48+i)) $fatal(1,"retry failure");
    $display("PASS mm2s bank=%0d packet-boundary/offset/tail/abort/rearm",BANK_WIDTH);
    $finish;
  end
  initial begin #100000;$fatal(1,"timeout");end
endmodule
