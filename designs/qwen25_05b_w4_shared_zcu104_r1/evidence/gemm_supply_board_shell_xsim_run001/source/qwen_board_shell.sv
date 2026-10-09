`timescale 1ns/1ps
module qwen_board_shell(
 (* X_INTERFACE_INFO="xilinx.com:signal:clock:1.0 CLK CLK", X_INTERFACE_PARAMETER="XIL_INTERFACENAME CLK, ASSOCIATED_BUSIF S_AXI:m_axis_mm2s_cmd:s_axis_mm2s:s_axis_mm2s_sts:m_axis_s2mm_cmd:m_axis_s2mm:s_axis_s2mm_sts, ASSOCIATED_RESET rst_n, FREQ_HZ 200000000" *) input logic clk,
 (* X_INTERFACE_INFO="xilinx.com:signal:reset:1.0 RST RST", X_INTERFACE_PARAMETER="XIL_INTERFACENAME RST, POLARITY ACTIVE_LOW" *) input logic rst_n,
 output logic dma_resetn,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI AWADDR" *) input logic [15:0] s_axi_awaddr,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI AWPROT" *) input logic [2:0] s_axi_awprot,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI AWVALID" *) input logic s_axi_awvalid,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI AWREADY" *) output logic s_axi_awready,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI WDATA" *) input logic [31:0] s_axi_wdata,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI WSTRB" *) input logic [3:0] s_axi_wstrb,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI WVALID" *) input logic s_axi_wvalid,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI WREADY" *) output logic s_axi_wready,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI BRESP" *) output logic [1:0] s_axi_bresp,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI BVALID" *) output logic s_axi_bvalid,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI BREADY" *) input logic s_axi_bready,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI ARADDR" *) input logic [15:0] s_axi_araddr,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI ARPROT" *) input logic [2:0] s_axi_arprot,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI ARVALID" *) input logic s_axi_arvalid,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI ARREADY" *) output logic s_axi_arready,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI RDATA" *) output logic [31:0] s_axi_rdata,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI RRESP" *) output logic [1:0] s_axi_rresp,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI RVALID" *) output logic s_axi_rvalid,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI RREADY" *) input logic s_axi_rready,
 (* X_INTERFACE_INFO="xilinx.com:interface:bram:1.0 CMD_BRAM CLK" *) input logic cmd_bram_clk,
 (* X_INTERFACE_INFO="xilinx.com:interface:bram:1.0 CMD_BRAM RST" *) input logic cmd_bram_rst,
 (* X_INTERFACE_INFO="xilinx.com:interface:bram:1.0 CMD_BRAM EN" *) input logic cmd_bram_en,
 (* X_INTERFACE_INFO="xilinx.com:interface:bram:1.0 CMD_BRAM WE" *) input logic [3:0] cmd_bram_we,
 (* X_INTERFACE_INFO="xilinx.com:interface:bram:1.0 CMD_BRAM ADDR" *) input logic [16:0] cmd_bram_addr,
 (* X_INTERFACE_INFO="xilinx.com:interface:bram:1.0 CMD_BRAM DIN" *) input logic [31:0] cmd_bram_wrdata,
 (* X_INTERFACE_INFO="xilinx.com:interface:bram:1.0 CMD_BRAM DOUT" *) output logic [31:0] cmd_bram_rddata,
output logic [71:0] m_axis_mm2s_cmd_tdata,output logic m_axis_mm2s_cmd_tvalid,input logic m_axis_mm2s_cmd_tready,
 input logic [63:0] s_axis_mm2s_tdata,input logic [7:0] s_axis_mm2s_tkeep,input logic s_axis_mm2s_tvalid,output logic s_axis_mm2s_tready,input logic s_axis_mm2s_tlast,
 input logic [7:0] s_axis_mm2s_sts_tdata,input logic s_axis_mm2s_sts_tkeep,s_axis_mm2s_sts_tvalid,output logic s_axis_mm2s_sts_tready,input logic s_axis_mm2s_sts_tlast,
 output logic [71:0] m_axis_s2mm_cmd_tdata,output logic m_axis_s2mm_cmd_tvalid,input logic m_axis_s2mm_cmd_tready,
 output logic [63:0] m_axis_s2mm_tdata,output logic [7:0] m_axis_s2mm_tkeep,output logic m_axis_s2mm_tvalid,input logic m_axis_s2mm_tready,output logic m_axis_s2mm_tlast,
 input logic [7:0] s_axis_s2mm_sts_tdata,input logic s_axis_s2mm_sts_tkeep,s_axis_s2mm_sts_tvalid,output logic s_axis_s2mm_sts_tready,input logic s_axis_s2mm_sts_tlast
);
 logic busy,done,error,start,cmd_en,load_faulted,store_faulted;
 logic [7:0] error_code,load_error_code,store_error_code;logic [9:0] pc,cmd_addr;logic [255:0] cmd_data;
 logic accelerator_resetn;wire command_mutation=busy && cmd_bram_en && |cmd_bram_we;
 assign dma_resetn=accelerator_resetn;
 qwen_control_regs control(.clk,.rst_n,.s_axi_awaddr,.s_axi_awprot,.s_axi_awvalid,.s_axi_awready,.s_axi_wdata,.s_axi_wstrb,.s_axi_wvalid,.s_axi_wready,.s_axi_bresp,.s_axi_bvalid,.s_axi_bready,.s_axi_araddr,.s_axi_arprot,.s_axi_arvalid,.s_axi_arready,.s_axi_rdata,.s_axi_rresp,.s_axi_rvalid,.s_axi_rready,.busy,.done,.error,.error_code,.pc,.load_error_code,.store_error_code,.command_mutation,.start,.accelerator_resetn);
 // Two physical 128-bit halves form ONE logical 256-bit command memory.
 // PS 32:128 ratio4 is supported by XPM synthesis; 32:256 ratio8 is not.
 logic [1:0][31:0] command_ps_data;logic [1:0][127:0] command_pl_data;
 logic ps_half_q0,ps_half_q1;
 always_ff @(posedge cmd_bram_clk)begin
  if(cmd_bram_rst)begin ps_half_q0<=0;ps_half_q1<=0;end
  else begin if(cmd_bram_en)ps_half_q0<=cmd_bram_addr[4];ps_half_q1<=ps_half_q0;end
 end
 assign cmd_bram_rddata=command_ps_data[ps_half_q1];
 assign cmd_data={command_pl_data[1],command_pl_data[0]};
 for(genvar half=0;half<2;half=half+1)begin:command_halves
 xpm_memory_tdpram #(.ADDR_WIDTH_A(12),.ADDR_WIDTH_B(10),.AUTO_SLEEP_TIME(0),.BYTE_WRITE_WIDTH_A(8),.BYTE_WRITE_WIDTH_B(8),
  .CASCADE_HEIGHT(0),.CLOCKING_MODE("common_clock"),.ECC_MODE("no_ecc"),.MEMORY_INIT_FILE("none"),.MEMORY_INIT_PARAM(""),.MEMORY_OPTIMIZATION("true"),
  .MEMORY_PRIMITIVE("block"),.MEMORY_SIZE(131072),.MESSAGE_CONTROL(0),.READ_DATA_WIDTH_A(32),.READ_DATA_WIDTH_B(128),.READ_LATENCY_A(2),.READ_LATENCY_B(2),
  .READ_RESET_VALUE_A("0"),.READ_RESET_VALUE_B("0"),.RST_MODE_A("SYNC"),.RST_MODE_B("SYNC"),.SIM_ASSERT_CHK(0),.USE_EMBEDDED_CONSTRAINT(0),.USE_MEM_INIT(0),
  .WAKEUP_TIME("disable_sleep"),.WRITE_DATA_WIDTH_A(32),.WRITE_DATA_WIDTH_B(128),.WRITE_MODE_A("read_first"),.WRITE_MODE_B("read_first")) command_memory(
  .sleep(1'b0),.clka(cmd_bram_clk),.ena(cmd_bram_en && cmd_bram_addr[4]==half),.wea(cmd_bram_we & {4{!busy && accelerator_resetn}}),.addra({cmd_bram_addr[14:5],cmd_bram_addr[3:2]}),.dina(cmd_bram_wrdata),.douta(command_ps_data[half]),
  .rsta(cmd_bram_rst),.regcea(1'b1),.injectsbiterra(1'b0),.injectdbiterra(1'b0),.sbiterra(),.dbiterra(),
  .clkb(clk),.enb(cmd_en),.web(16'b0),.addrb(cmd_addr),.dinb(128'b0),.doutb(command_pl_data[half]),.rstb(!accelerator_resetn),.regceb(1'b1),
  .injectsbiterrb(1'b0),.injectdbiterrb(1'b0),.sbiterrb(),.dbiterrb());
 end
 qwen_dma_core executor(.clk,.rst_n(accelerator_resetn),.start,.busy,.done,.error,.error_code,.pc,.cmd_en,.cmd_addr,.cmd_data,
.m_axis_mm2s_cmd_tdata,.m_axis_mm2s_cmd_tvalid,.m_axis_mm2s_cmd_tready,.s_axis_mm2s_tdata,.s_axis_mm2s_tkeep,.s_axis_mm2s_tvalid,.s_axis_mm2s_tready,.s_axis_mm2s_tlast,.s_axis_mm2s_sts_tdata,.s_axis_mm2s_sts_tkeep,.s_axis_mm2s_sts_tvalid,.s_axis_mm2s_sts_tready,.s_axis_mm2s_sts_tlast,.m_axis_s2mm_cmd_tdata,.m_axis_s2mm_cmd_tvalid,.m_axis_s2mm_cmd_tready,.m_axis_s2mm_tdata,.m_axis_s2mm_tkeep,.m_axis_s2mm_tvalid,.m_axis_s2mm_tready,.m_axis_s2mm_tlast,.s_axis_s2mm_sts_tdata,.s_axis_s2mm_sts_tkeep,.s_axis_s2mm_sts_tvalid,.s_axis_s2mm_sts_tready,.s_axis_s2mm_sts_tlast,.load_error_code,.store_error_code,.load_faulted,.store_faulted);
endmodule
