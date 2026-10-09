`timescale 1ns/1ps
module tb_qwen_board_reset;
 logic clk=0;always #2.5 clk=~clk;
 logic ps_resetn=0;wire fixed_resetn,bad_resetn;
 proc_sys_reset #(.C_FAMILY("zynquplus"),.C_EXT_RESET_HIGH(1'b0),.C_AUX_RESET_HIGH(1'b1)) fixed_reset(
  .slowest_sync_clk(clk),.ext_reset_in(ps_resetn),.aux_reset_in(1'b0),.mb_debug_sys_rst(1'b0),.dcm_locked(1'b1),
  .mb_reset(),.bus_struct_reset(),.peripheral_reset(),.interconnect_aresetn(),.peripheral_aresetn(fixed_resetn));
 proc_sys_reset #(.C_FAMILY("zynquplus"),.C_EXT_RESET_HIGH(1'b0),.C_AUX_RESET_HIGH(1'b0)) old_reset(
  .slowest_sync_clk(clk),.ext_reset_in(ps_resetn),.aux_reset_in(1'b0),.mb_debug_sys_rst(1'b0),.dcm_locked(1'b1),
  .mb_reset(),.bus_struct_reset(),.peripheral_reset(),.interconnect_aresetn(),.peripheral_aresetn(bad_resetn));
 logic [15:0] araddr=0;logic arvalid=0,rready=0;
 wire arready,rvalid,accelerator_resetn;wire [31:0] rdata;wire [1:0] rresp;
 qwen_control_regs control(.clk,.rst_n(fixed_resetn),
  .s_axi_awaddr(16'b0),.s_axi_awprot(3'b0),.s_axi_awvalid(1'b0),.s_axi_awready(),
  .s_axi_wdata(32'b0),.s_axi_wstrb(4'b0),.s_axi_wvalid(1'b0),.s_axi_wready(),.s_axi_bresp(),.s_axi_bvalid(),.s_axi_bready(1'b1),
  .s_axi_araddr(araddr),.s_axi_arprot(3'b0),.s_axi_arvalid(arvalid),.s_axi_arready(arready),
  .s_axi_rdata(rdata),.s_axi_rresp(rresp),.s_axi_rvalid(rvalid),.s_axi_rready(rready),
  .busy(1'b0),.done(1'b0),.error(1'b0),.error_code(8'b0),.pc(10'b0),.load_error_code(8'b0),.store_error_code(8'b0),.command_mutation(1'b0),.start(),.accelerator_resetn);
 task automatic profile;
  @(negedge clk);araddr=16'h18;arvalid=1;
  do @(posedge clk);while(!arready);
  @(negedge clk);arvalid=0;
  wait(rvalid);
  if(rdata!==32'h51574e31 || rresp!==0)$fatal(1,"profile read after board reset release failed");
  repeat(4)begin @(posedge clk);if(!rvalid || rdata!==32'h51574e31)$fatal(1,"read response not held");end
  @(negedge clk);rready=1;@(negedge clk);rready=0;
 endtask
 initial begin
  repeat(200)@(posedge clk);
  if(fixed_resetn!==0 || bad_resetn!==0)$fatal(1,"PS reset must assert peripheral reset");
  @(negedge clk);ps_resetn=1;
  repeat(300)@(posedge clk);
  if(fixed_resetn!==1 || accelerator_resetn!==1)$fatal(1,"fixed board reset did not release");
  if(bad_resetn!==0)$fatal(1,"old auxiliary low reset failure not reproduced");
  profile();
  @(negedge clk);ps_resetn=0;repeat(100)@(posedge clk);
  if(fixed_resetn!==0 || arready!==0)$fatal(1,"PS reset reassertion failed");
  @(negedge clk);ps_resetn=1;repeat(300)@(posedge clk);profile();
  $display("PASS_ACTUAL_VENDOR_BOARD_RESET_200MHZ_OLD_FAILURE_FIXED_RELEASE_PROFILE_REASSERT");$finish;
 end
 initial begin #20000;$fatal(1,"reset/AXI test timed out");end
endmodule
