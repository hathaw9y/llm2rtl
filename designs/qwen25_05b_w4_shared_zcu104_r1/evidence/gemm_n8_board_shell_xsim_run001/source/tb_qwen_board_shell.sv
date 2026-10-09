`timescale 1ns/1ps
module tb_qwen_board_shell;
 logic clk=0;always #2.5 clk=~clk;
 logic rst_n=0,start,busy,done,error;logic [7:0] error_code,load_error_code,store_error_code;logic [9:0] pc,cmd_addr;logic cmd_en;logic [255:0] cmd_data;
 logic [71:0] m_axis_mm2s_cmd_tdata,m_axis_s2mm_cmd_tdata;
 logic m_axis_mm2s_cmd_tvalid,m_axis_mm2s_cmd_tready,m_axis_s2mm_cmd_tvalid,m_axis_s2mm_cmd_tready;
 logic [63:0] s_axis_mm2s_tdata,m_axis_s2mm_tdata;
 logic [7:0] s_axis_mm2s_tkeep,m_axis_s2mm_tkeep,s_axis_mm2s_sts_tdata,s_axis_s2mm_sts_tdata;
 logic s_axis_mm2s_tvalid,s_axis_mm2s_tready,s_axis_mm2s_tlast,m_axis_s2mm_tvalid,m_axis_s2mm_tready,m_axis_s2mm_tlast;
 logic s_axis_mm2s_sts_tkeep,s_axis_mm2s_sts_tvalid,s_axis_mm2s_sts_tready,s_axis_mm2s_sts_tlast;
 logic s_axis_s2mm_sts_tkeep,s_axis_s2mm_sts_tvalid,s_axis_s2mm_sts_tready,s_axis_s2mm_sts_tlast;
 logic load_faulted,store_faulted;
 logic [255:0] program_words[0:1023],cp[0:1];logic [127:0] input_ddr[0:65535],expected_ddr[0:65535];
 logic load_active,store_active,inject_tag;logic [3:0] load_tag,store_tag;
 integer load_index,load_remaining,store_index,store_remaining,cycle_counter,input_words,expected_words,fd,got,count,cycles,packets,total_loads,total_stores,checked;
 string directory,filename;
 logic dma_resetn;
 logic [15:0] s_axi_awaddr=0,s_axi_araddr=0;logic [2:0] s_axi_awprot=0,s_axi_arprot=0;
 logic s_axi_awvalid=0,s_axi_awready,s_axi_wvalid=0,s_axi_wready,s_axi_bvalid,s_axi_bready=1,s_axi_arvalid=0,s_axi_arready,s_axi_rvalid,s_axi_rready=1;
 logic [31:0] s_axi_wdata=0,s_axi_rdata,status;logic [3:0] s_axi_wstrb=15;logic [1:0] s_axi_bresp,s_axi_rresp;
 wire cmd_bram_clk=clk;logic cmd_bram_rst=0,cmd_bram_en=0;logic [3:0] cmd_bram_we=0;logic [16:0] cmd_bram_addr=0;logic [31:0] cmd_bram_wrdata=0,cmd_bram_rddata;
 qwen_board_shell dut(.clk,.rst_n,.dma_resetn,.s_axi_awaddr,.s_axi_awprot,.s_axi_awvalid,.s_axi_awready,.s_axi_wdata,.s_axi_wstrb,.s_axi_wvalid,.s_axi_wready,.s_axi_bresp,.s_axi_bvalid,.s_axi_bready,.s_axi_araddr,.s_axi_arprot,.s_axi_arvalid,.s_axi_arready,.s_axi_rdata,.s_axi_rresp,.s_axi_rvalid,.s_axi_rready,.cmd_bram_clk,.cmd_bram_rst,.cmd_bram_en,.cmd_bram_we,.cmd_bram_addr,.cmd_bram_wrdata,.cmd_bram_rddata,
 .m_axis_mm2s_cmd_tdata,.m_axis_mm2s_cmd_tvalid,.m_axis_mm2s_cmd_tready,.m_axis_s2mm_cmd_tdata,.m_axis_s2mm_cmd_tvalid,.m_axis_s2mm_cmd_tready,.s_axis_mm2s_tdata,.s_axis_mm2s_tkeep,.s_axis_mm2s_tvalid,.s_axis_mm2s_tready,.s_axis_mm2s_tlast,.m_axis_s2mm_tdata,.m_axis_s2mm_tkeep,.m_axis_s2mm_tvalid,.m_axis_s2mm_tready,.m_axis_s2mm_tlast,.s_axis_mm2s_sts_tdata,.s_axis_mm2s_sts_tkeep,.s_axis_mm2s_sts_tvalid,.s_axis_mm2s_sts_tready,.s_axis_mm2s_sts_tlast,.s_axis_s2mm_sts_tdata,.s_axis_s2mm_sts_tkeep,.s_axis_s2mm_sts_tvalid,.s_axis_s2mm_sts_tready,.s_axis_s2mm_sts_tlast);
 task automatic csr_write(input [15:0] address,input [31:0] value);
  @(negedge clk);s_axi_awaddr=address;s_axi_awvalid=1;
  do @(posedge clk);while(!s_axi_awready);
  @(negedge clk);s_axi_awvalid=0;s_axi_wdata=value;s_axi_wvalid=1;
  do @(posedge clk);while(!s_axi_wready);
  @(negedge clk);s_axi_wvalid=0;
  while(!s_axi_bvalid)@(negedge clk);
  if(s_axi_bresp!=0)$fatal(1,"AXI write response");@(negedge clk);
 endtask
 task automatic csr_read(input [15:0] address,output [31:0] value);
  @(negedge clk);s_axi_araddr=address;s_axi_arvalid=1;
  do @(posedge clk);while(!s_axi_arready);
  @(negedge clk);s_axi_arvalid=0;
  while(!s_axi_rvalid)@(negedge clk);
  if(s_axi_rresp!=0)$fatal(1,"AXI read response");value=s_axi_rdata;@(negedge clk);
 endtask
 task automatic publish(input integer length);
  for(integer i=0;i<length;i=i+1)for(integer j=0;j<8;j=j+1)begin
   @(negedge clk);cmd_bram_en=1;cmd_bram_we=15;cmd_bram_addr=i*32+j*4;cmd_bram_wrdata=program_words[i][j*32+:32];
  end
  @(negedge clk);cmd_bram_en=0;cmd_bram_we=0;
  // PS readback verifies half selection, byte order and two-cycle latency.
  for(integer i=0;i<2;i=i+1)for(integer j=0;j<8;j=j+1)begin
   @(negedge clk);cmd_bram_en=1;cmd_bram_addr=(i==0?0:length-1)*32+j*4;
   repeat(2)@(posedge clk);#1;
   if(cmd_bram_rddata!==program_words[i==0?0:length-1][j*32+:32])$fatal(1,"command PS readback half/order word%0d",j);
   @(negedge clk);cmd_bram_en=0;
  end
 endtask
 always @*begin
  m_axis_mm2s_cmd_tready=!load_active && !s_axis_mm2s_sts_tvalid && cycle_counter%7!=0;
  m_axis_s2mm_cmd_tready=!store_active && !s_axis_s2mm_sts_tvalid;
  s_axis_mm2s_tvalid=load_active;s_axis_mm2s_tdata=input_ddr[load_index/2][(load_index%2)*64+:64];
  s_axis_mm2s_tkeep=8'hff;s_axis_mm2s_tlast=load_remaining==1;
  m_axis_s2mm_tready=store_active && cycle_counter%5!=0;
  s_axis_mm2s_sts_tkeep=1;s_axis_mm2s_sts_tlast=1;s_axis_s2mm_sts_tkeep=1;s_axis_s2mm_sts_tlast=1;
 end
 always @(posedge clk)begin
  if(dma_resetn)begin
   if(|(dut.executor.core.write_pending & ~dut.executor.core.bank_busy))
    $fatal(1,"bank ownership released before accepted write reached memory");
   for(integer b=0;b<23;b=b+1)
    if(dut.executor.core.write_pending[b] && dut.executor.core.release_bank[b])
     $fatal(1,"bank%0d released with pending write",b);
   if(dut.done && (|dut.executor.core.write_pending))
    $fatal(1,"END/DONE before physical write drain");
  end
  if(!dma_resetn)begin load_active<=0;store_active<=0;s_axis_mm2s_sts_tvalid<=0;s_axis_s2mm_sts_tvalid<=0;s_axis_mm2s_sts_tdata<=0;s_axis_s2mm_sts_tdata<=0;cycle_counter<=0;end
  else begin
   cycle_counter<=cycle_counter+1;
   if(s_axis_mm2s_sts_tvalid && s_axis_mm2s_sts_tready)s_axis_mm2s_sts_tvalid<=0;
   if(s_axis_s2mm_sts_tvalid && s_axis_s2mm_sts_tready)s_axis_s2mm_sts_tvalid<=0;
   if(m_axis_mm2s_cmd_tvalid && m_axis_mm2s_cmd_tready)begin
    if(m_axis_mm2s_cmd_tdata[63:32]<32'h10000000 || (m_axis_mm2s_cmd_tdata[63:32]-32'h10000000)/16+m_axis_mm2s_cmd_tdata[22:0]/16>input_words)$fatal(1,"load DDR extent");
    load_index<=int'((m_axis_mm2s_cmd_tdata[63:32]-32'h10000000)/8);load_remaining<=int'(m_axis_mm2s_cmd_tdata[22:0]/8);load_tag<=m_axis_mm2s_cmd_tdata[67:64];load_active<=1;total_loads<=total_loads+1;
   end
   if(s_axis_mm2s_tvalid && s_axis_mm2s_tready)begin
    load_index<=load_index+1;load_remaining<=load_remaining-1;
    if(load_remaining==1)begin load_active<=0;s_axis_mm2s_sts_tvalid<=1;s_axis_mm2s_sts_tdata<=8'h80|{4'b0,(inject_tag?load_tag+4'd1:load_tag)};end
   end
   if(m_axis_s2mm_cmd_tvalid && m_axis_s2mm_cmd_tready)begin
    if(m_axis_s2mm_cmd_tdata[63:32]<32'h18000000 || (m_axis_s2mm_cmd_tdata[63:32]-32'h18000000)/16+m_axis_s2mm_cmd_tdata[22:0]/16>expected_words)$fatal(1,"store DDR extent");
    store_index<=int'((m_axis_s2mm_cmd_tdata[63:32]-32'h18000000)/8);store_remaining<=int'(m_axis_s2mm_cmd_tdata[22:0]/8);store_tag<=m_axis_s2mm_cmd_tdata[67:64];store_active<=1;total_stores<=total_stores+1;
   end
   if(m_axis_s2mm_tvalid && m_axis_s2mm_tready)begin
    if(m_axis_s2mm_tkeep!=8'hff || m_axis_s2mm_tlast!=(store_remaining==1))$fatal(1,"store keep/last");
    if(m_axis_s2mm_tdata!==expected_ddr[store_index/2][(store_index%2)*64+:64])$fatal(1,"packet%0d DDR beat%0d got=%h expected=%h",packets,store_index,m_axis_s2mm_tdata,expected_ddr[store_index/2][(store_index%2)*64+:64]);
    checked<=checked+1;store_index<=store_index+1;store_remaining<=store_remaining-1;
    if(store_remaining==1)begin store_active<=0;s_axis_s2mm_sts_tvalid<=1;s_axis_s2mm_sts_tdata<=8'h80|{4'b0,store_tag};end
   end
  end
 end
 initial begin
  if(!$value$plusargs("VECTORS=%s",directory))directory="/home/shmin/llm2rtl/designs/qwen25_05b_w4_shared_zcu104_r1/evidence/core_packet_run002";
  start=0;load_index=0;load_remaining=0;store_index=0;store_remaining=0;load_tag=0;store_tag=0;inject_tag=0;packets=0;checked=0;total_loads=0;total_stores=0;
  fd=$fopen({directory,"/sizes.txt"},"r");got=$fscanf(fd,"%d %d\n",input_words,expected_words);$fclose(fd);if(got!=2)$fatal(1,"sizes");
  $readmemh({directory,"/ddr_input.mem"},input_ddr,0,input_words-1);$readmemh({directory,"/ddr_expected.mem"},expected_ddr,0,expected_words-1);
  repeat(4)@(negedge clk);rst_n=1;csr_read(16'h18,status);if(status!=32'h51574e31)$fatal(1,"CSR identity");csr_write(0,2);repeat(20)@(negedge clk);fd=$fopen({directory,"/headers.txt"},"r");if(fd==0)$fatal(1,"headers");
  while(!$feof(fd))begin
   got=$fscanf(fd,"%s %d\n",filename,count);if(got!=2)$fatal(1,"header invalid");
   @(negedge clk);if(dut.busy || load_active || store_active)$fatal(1,"publish busy");
   $readmemh({directory,"/",filename},program_words,0,count-1);publish(count);csr_write(0,1);cycles=0;status=0;
   while(!status[1] && !status[2])begin csr_read(4,status);cycles=cycles+1;if(cycles>1000000)$fatal(1,"timeout packet%0d PC%0d",packets,pc);end
   if(status[2])$fatal(1,"board shell status error packet%0d status%h",packets,status);
   if(|dut.executor.core.bank_busy || load_active || store_active)$fatal(1,"terminal ownership/transfer drain");
   $display("PASS DMA core packet%0d %s cycles%0d checkedBeats%0d",packets,filename,cycles,checked);$fflush();packets=packets+1;
  end
  $fclose(fd);if(checked!=expected_words*2 || total_stores!=13 || total_loads<=16)$fatal(1,"coverage/tag wrap");
  // Full physical command memory boundary:1023 real loads plus END at PC1023.
  // This exercises PS offsets through32764, native high PC bits and tag wrap.
  for(integer i=0;i<1023;i=i+1)program_words[i]=256'h1b00000000000000040400000005800101000000000000001848000000000000;
  program_words[1023]=0;publish(1024);csr_write(0,1);status=0;cycles=0;
  while(!status[1] && !status[2])begin csr_read(4,status);cycles=cycles+1;if(cycles>100000)$fatal(1,"full command memory timeout");end
  if(status[2] || status[25:16]!=1023 || |dut.executor.core.bank_busy || !dut.executor.core.valid[22])$fatal(1,"full command memory END/PC/drain/state");
  packets=packets+1;
  $display("PASS full1024-record command memory, END atPC1023, retained descriptor");
  csr_read(16'h10,status);if(status!=packets)$fatal(1,"completion count %0d",status);
  csr_write(0,2);repeat(20)@(negedge clk);
  if(|dut.executor.core.valid || |dut.executor.core.bank_busy)$fatal(1,"soft reset semantic state");
  $display("PASS board shell: PS32 command writes/XPM256 fetch, CSR START/sticky DONE/chunk restart, all bounded compute golden payloads, actual bank XPM, coordinated soft reset. Vendor AXI/DDR model; no board proof.");$finish;
 end
endmodule
