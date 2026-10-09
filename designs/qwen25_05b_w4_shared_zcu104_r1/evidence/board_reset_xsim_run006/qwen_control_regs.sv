`timescale 1ns/1ps
module qwen_control_regs(
 input logic clk,rst_n,
 input logic [15:0] s_axi_awaddr,input logic [2:0] s_axi_awprot,input logic s_axi_awvalid,output logic s_axi_awready,
 input logic [31:0] s_axi_wdata,input logic [3:0] s_axi_wstrb,input logic s_axi_wvalid,output logic s_axi_wready,
 output logic [1:0] s_axi_bresp,output logic s_axi_bvalid,input logic s_axi_bready,
 input logic [15:0] s_axi_araddr,input logic [2:0] s_axi_arprot,input logic s_axi_arvalid,output logic s_axi_arready,
 output logic [31:0] s_axi_rdata,output logic [1:0] s_axi_rresp,output logic s_axi_rvalid,input logic s_axi_rready,
 input logic busy,done,error,input logic [7:0] error_code,input logic [9:0] pc,
 input logic [7:0] load_error_code,store_error_code,input logic command_mutation,
 output logic start,output logic accelerator_resetn
);
 logic aw_pending,w_pending;logic [15:0] address_r;logic [31:0] data_r;logic [3:0] strobes_r;
 logic resetn_r;
 logic [4:0] reset_cycles_r;logic previous_done_r,sticky_done_r,sticky_error_r,mutation_r;
 logic [7:0] error_code_r;logic [63:0] active_cycles_r,cycle_snapshot_r;logic [31:0] completed_chunks_r;
 assign s_axi_awready=rst_n && !aw_pending && !s_axi_bvalid;
 assign s_axi_wready=rst_n && !w_pending && !s_axi_bvalid;
 assign s_axi_arready=rst_n && !s_axi_rvalid;
 assign accelerator_resetn=rst_n && resetn_r;
 always_ff @(posedge clk)begin
  if(!rst_n)begin
   aw_pending<=0;w_pending<=0;address_r<=0;data_r<=0;strobes_r<=0;s_axi_bresp<=0;s_axi_bvalid<=0;s_axi_rdata<=0;s_axi_rresp<=0;s_axi_rvalid<=0;
   resetn_r<=0;reset_cycles_r<=16;previous_done_r<=0;sticky_done_r<=0;sticky_error_r<=0;mutation_r<=0;error_code_r<=0;active_cycles_r<=0;cycle_snapshot_r<=0;completed_chunks_r<=0;start<=0;
  end else begin
   start<=0;
   if(reset_cycles_r!=0)begin reset_cycles_r<=reset_cycles_r-1'b1;previous_done_r<=0;if(reset_cycles_r==1)resetn_r<=1;end
   else begin
    previous_done_r<=done;
    if(done && !previous_done_r)begin sticky_done_r<=1;completed_chunks_r<=completed_chunks_r+1'b1;end
    if(busy)active_cycles_r<=active_cycles_r+1'b1;
    if(error)begin sticky_error_r<=1;error_code_r<=error_code;end
   end
   if(command_mutation)begin mutation_r<=1;sticky_error_r<=1;error_code_r<=8'he1;end
   if(s_axi_bvalid && s_axi_bready)s_axi_bvalid<=0;
   if(s_axi_rvalid && s_axi_rready)s_axi_rvalid<=0;
   if(s_axi_awvalid && s_axi_awready)begin aw_pending<=1;address_r<=s_axi_awaddr;end
   if(s_axi_wvalid && s_axi_wready)begin w_pending<=1;data_r<=s_axi_wdata;strobes_r<=s_axi_wstrb;end
   if(aw_pending && w_pending && !s_axi_bvalid)begin
    aw_pending<=0;w_pending<=0;s_axi_bvalid<=1;s_axi_bresp<=2'b00;
    if(address_r!=0 || !strobes_r[0] || (data_r[1:0]==3))s_axi_bresp<=2'b10;
    else if(data_r[1])begin
     resetn_r<=0;reset_cycles_r<=16;previous_done_r<=0;sticky_done_r<=0;sticky_error_r<=0;mutation_r<=0;error_code_r<=0;active_cycles_r<=0;cycle_snapshot_r<=0;completed_chunks_r<=0;
    end else if(data_r[0])begin
     if(busy || reset_cycles_r!=0 || sticky_error_r)s_axi_bresp<=2'b10;
     else begin start<=1;sticky_done_r<=0;end
    end
   end
   if(s_axi_arvalid && s_axi_arready)begin
    s_axi_rvalid<=1;s_axi_rresp<=2'b00;
    case(s_axi_araddr)
     16'h0000:s_axi_rdata<=0;
     16'h0004:s_axi_rdata<={6'b0,pc,error_code_r,4'b0,(reset_cycles_r!=0),sticky_error_r,sticky_done_r,busy};
     16'h0008:begin s_axi_rdata<=active_cycles_r[31:0];cycle_snapshot_r<=active_cycles_r;end
     16'h000c:s_axi_rdata<=cycle_snapshot_r[63:32];
     16'h0010:s_axi_rdata<=completed_chunks_r;
     16'h0014:s_axi_rdata<={15'b0,mutation_r,store_error_code,load_error_code};
     16'h0018:s_axi_rdata<=32'h51574e31; // QWN1 register/ISA profile identity
     default:begin s_axi_rdata<=0;s_axi_rresp<=2'b10;end
    endcase
   end
  end
 end
endmodule
