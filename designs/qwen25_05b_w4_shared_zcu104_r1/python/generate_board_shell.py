"""Board-facing interfaces. No vendor board design is copied."""
from pathlib import Path
BASE=Path(__file__).resolve().parents[1]
def main():
 ctrl=['input logic [15:0] s_axi_awaddr','input logic [2:0] s_axi_awprot','input logic s_axi_awvalid','output logic s_axi_awready','input logic [31:0] s_axi_wdata','input logic [3:0] s_axi_wstrb','input logic s_axi_wvalid','output logic s_axi_wready','output logic [1:0] s_axi_bresp','output logic s_axi_bvalid','input logic s_axi_bready','input logic [15:0] s_axi_araddr','input logic [2:0] s_axi_arprot','input logic s_axi_arvalid','output logic s_axi_arready','output logic [31:0] s_axi_rdata','output logic [1:0] s_axi_rresp','output logic s_axi_rvalid','input logic s_axi_rready']
 dma=(BASE/'rtl/qwen_dma_core.sv').read_text();a=dma.index(' output logic [71:0]');b=dma.index(' output logic [7:0] load_error_code',a);axis=dma[a:b].strip().rstrip(',')
 ports=[''' (* X_INTERFACE_INFO="xilinx.com:signal:clock:1.0 CLK CLK", X_INTERFACE_PARAMETER="XIL_INTERFACENAME CLK, ASSOCIATED_BUSIF S_AXI:m_axis_mm2s_cmd:s_axis_mm2s:s_axis_mm2s_sts:m_axis_s2mm_cmd:m_axis_s2mm:s_axis_s2mm_sts, ASSOCIATED_RESET rst_n, FREQ_HZ 200000000" *) input logic clk,
 (* X_INTERFACE_INFO="xilinx.com:signal:reset:1.0 RST RST", X_INTERFACE_PARAMETER="XIL_INTERFACENAME RST, POLARITY ACTIVE_LOW" *) input logic rst_n,
 output logic dma_resetn''']
 for p in ctrl:
  name=p.split()[-1];role=name.removeprefix('s_axi_').upper();ports.append(f' (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI {role}" *) {p}')
 for p in ['input logic cmd_bram_clk','input logic cmd_bram_rst','input logic cmd_bram_en','input logic [3:0] cmd_bram_we','input logic [16:0] cmd_bram_addr','input logic [31:0] cmd_bram_wrdata','output logic [31:0] cmd_bram_rddata']:
  role={'clk':'CLK','rst':'RST','en':'EN','we':'WE','addr':'ADDR','wrdata':'DIN','rddata':'DOUT'}[p.split()[-1].removeprefix('cmd_bram_')];ports.append(f' (* X_INTERFACE_INFO="xilinx.com:interface:bram:1.0 CMD_BRAM {role}" *) {p}')
 ports.append(axis)
 source='`timescale 1ns/1ps\nmodule qwen_board_shell(\n'+',\n'.join(ports)+'\n);\n'
 source+=''' logic busy,done,error,start,cmd_en,load_faulted,store_faulted;
 logic [7:0] error_code,load_error_code,store_error_code;logic [9:0] pc,cmd_addr;logic [255:0] cmd_data;
 logic accelerator_resetn;wire command_mutation=busy && cmd_bram_en && |cmd_bram_we;
 assign dma_resetn=accelerator_resetn;
 qwen_control_regs control(.clk,.rst_n,'''+','.join('.'+p.split()[-1] for p in ctrl)+''',.busy,.done,.error,.error_code,.pc,.load_error_code,.store_error_code,.command_mutation,.start,.accelerator_resetn);
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
'''
 import re
 names=[part.strip().split()[-1] for part in axis.split(',')]
 source+=','.join('.'+n for n in names)+',.load_error_code,.store_error_code,.load_faulted,.store_faulted);\nendmodule\n'
 (BASE/'rtl/qwen_board_shell.sv').write_text(source)
 header=source[:source.index(');\n')+3].replace('module qwen_board_shell','module qwen_board_ip').replace('input logic','input wire').replace('output logic','output wire')
 clean=re.sub(r'\(\*.*?\*\)','',header,flags=re.S)
 port_names=[part.strip().split()[-1] for part in clean[clean.index('(')+1:clean.rindex(')')].split(',')]
 wrapper=header+' qwen_board_shell implementation('+','.join('.'+n+'('+n+')' for n in port_names)+');\nendmodule\n'
 (BASE/'rtl/qwen_board_ip.v').write_text(wrapper)
if __name__=='__main__':main()
