`timescale 1ns/1ps
module tb_qwen_dma_core;
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
 qwen_dma_core dut(.*);
 always @*begin
  cmd_data=cp[1];m_axis_mm2s_cmd_tready=!load_active && !s_axis_mm2s_sts_tvalid && cycle_counter%7!=0;
  m_axis_s2mm_cmd_tready=!store_active && !s_axis_s2mm_sts_tvalid;
  s_axis_mm2s_tvalid=load_active;s_axis_mm2s_tdata=input_ddr[load_index/2][(load_index%2)*64+:64];
  s_axis_mm2s_tkeep=8'hff;s_axis_mm2s_tlast=load_remaining==1;
  m_axis_s2mm_tready=store_active && cycle_counter%5!=0;
  s_axis_mm2s_sts_tkeep=1;s_axis_mm2s_sts_tlast=1;s_axis_s2mm_sts_tkeep=1;s_axis_s2mm_sts_tlast=1;
 end
 always @(posedge clk)begin
  cp[0]<=cmd_en?program_words[cmd_addr]:256'b0;cp[1]<=cp[0];
  if(!rst_n)begin load_active<=0;store_active<=0;s_axis_mm2s_sts_tvalid<=0;s_axis_s2mm_sts_tvalid<=0;s_axis_mm2s_sts_tdata<=0;s_axis_s2mm_sts_tdata<=0;cycle_counter<=0;end
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
  repeat(4)@(negedge clk);rst_n=1;fd=$fopen({directory,"/headers.txt"},"r");if(fd==0)$fatal(1,"headers");
  while(!$feof(fd))begin
   got=$fscanf(fd,"%s %d\n",filename,count);if(got!=2)$fatal(1,"header invalid");
   @(negedge clk);if(busy || load_active || store_active)$fatal(1,"publish busy");
   $readmemh({directory,"/",filename},program_words,0,count-1);start=1;@(negedge clk);start=0;cycles=0;
   while(!done && !error)begin @(negedge clk);cycles=cycles+1;if(cycles>1000000)$fatal(1,"timeout packet%0d PC%0d",packets,pc);end
   if(error)$fatal(1,"DMA core error packet%0d PC%0d code%0d loadCode%0d storeCode%0d",packets,pc,error_code,load_error_code,store_error_code);
   if(|dut.core.bank_busy || load_active || store_active)$fatal(1,"terminal ownership/transfer drain");
   $display("PASS DMA core packet%0d %s cycles%0d checkedBeats%0d",packets,filename,cycles,checked);$fflush();packets=packets+1;
  end
  $fclose(fd);if(checked!=expected_words*2 || total_stores!=13 || total_loads<=16)$fatal(1,"coverage/tag wrap");
  // Corrupt the vendor4-bit returned tag. Engine must diagnose and halt; no DONE.
  @(negedge clk);$readmemh({directory,"/2_0.mem"},program_words,0,3);inject_tag=1;start=1;@(negedge clk);start=0;cycles=0;
  while(!error)begin @(negedge clk);cycles=cycles+1;if(cycles>1000)$fatal(1,"missing tag fault");end
  if(!load_faulted || load_error_code!=8'h20 || done)$fatal(1,"fault identity/terminal");
  // Recovery is an explicit coordinated reset, not END or a hidden engine retry.
  @(negedge clk);rst_n=0;repeat(6)@(negedge clk);rst_n=1;inject_tag=0;#1;
  if(error || |dut.core.valid || |dut.core.bank_busy)$fatal(1,"reset did not invalidate semantic state");
  $display("PASS DMA core: common engine/adapters64-to128, all compute golden payloads, backpressure, tag wrap and mismatch, partial state over END, coordinated reset. Vendor DataMover AXI/DDR model, no board proof.");$finish;
 end
endmodule
