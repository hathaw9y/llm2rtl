`timescale 1ns/1ps
module tb_qwen_core;
 logic clk=0;always #2.5 clk=~clk;
 logic rst_n=0,start,busy,done,error;logic [7:0] error_code;logic [9:0] pc,cmd_addr;logic cmd_en;logic [255:0] cmd_data;
 logic load_valid,load_ready,load_rsp_valid,load_rsp_ready,load_rsp_error;
 logic store_valid,store_ready,store_rsp_valid,store_rsp_ready,store_rsp_error;
 logic [31:0] load_address,store_address;logic [22:0] load_bytes,load_offset,store_bytes,store_offset;
 logic [4:0] load_bank,store_bank,load_rsp_bank,store_rsp_bank,dma_write_bank,dma_read_bank;
 logic [22:0] dma_write_grant,dma_read_grant;
 logic dma_write_en,dma_read_en;logic [12:0] dma_write_addr,dma_read_addr;
 logic [127:0] dma_write_data,dma_read_data;logic [15:0] dma_write_mask;
 logic [255:0] program_words[0:1023],cp[0:1];
 logic [127:0] input_ddr[0:65535],expected_ddr[0:65535];
 integer load_index,load_remaining,load_word,store_index,store_remaining,store_word,read_wait;
 integer input_words,expected_words,fd,got,count,cycles,packets,total_loads,total_stores,checked;
 logic load_active,store_active;string directory,filename;
 qwen_core dut(.*);
 always @*begin cmd_data=cp[1];load_ready=!load_active && !load_rsp_valid;store_ready=!store_active && !store_rsp_valid;end
 always @(posedge clk)begin
  cp[0]<=cmd_en?program_words[cmd_addr]:256'b0;cp[1]<=cp[0];
  if(rst_n)begin
   if(load_valid && load_ready)begin
    if(load_address<32'h10000000 || (load_address-32'h10000000)/16+load_bytes/16>input_words || load_bytes[3:0]!=0)$fatal(1,"load range");
    load_index=int'((load_address-32'h10000000)/16);load_remaining=int'(load_bytes/16);load_word=int'(load_offset/16);dma_write_bank=load_bank;load_active<=1;total_loads=total_loads+1;
   end
   if(store_valid && store_ready)begin
    if(store_address<32'h18000000 || (store_address-32'h18000000)/16+store_bytes/16>expected_words || store_bytes[3:0]!=0)$fatal(1,"store range");
    store_index=int'((store_address-32'h18000000)/16);store_remaining=int'(store_bytes/16);store_word=int'(store_offset/16);dma_read_bank=store_bank;store_active<=1;read_wait=0;total_stores=total_stores+1;
   end
  end
 end
 // Deliberately simple native DMA model. Real engine/adapter verification is separate.
 always @(negedge clk)begin
  if(!rst_n)begin dma_write_en=0;dma_read_en=0;load_active=0;store_active=0;load_rsp_valid=0;store_rsp_valid=0;read_wait=0;end
  else begin
   if(load_rsp_valid && load_rsp_ready)load_rsp_valid=0;
   if(store_rsp_valid && store_rsp_ready)store_rsp_valid=0;
   dma_write_en=0;dma_read_en=0;
   if(load_active)begin
    if(load_remaining!=0)begin
     dma_write_en=1;dma_write_addr=13'(load_word);dma_write_data=input_ddr[load_index];dma_write_mask=16'hffff;
     load_word=load_word+1;load_index=load_index+1;load_remaining=load_remaining-1;
    end else begin load_active=0;load_rsp_valid=1;load_rsp_bank=dma_write_bank;end
   end
   if(store_active)begin
    if(read_wait==0)begin dma_read_en=1;dma_read_addr=13'(store_word);read_wait=3;end
    else if(read_wait==1)begin
     if(dma_read_data!==expected_ddr[store_index])$fatal(1,"packet%0d DDR word%0d bank%0d got=%h expected=%h",packets,store_index,dma_read_bank,dma_read_data,expected_ddr[store_index]);
     checked=checked+1;store_index=store_index+1;store_word=store_word+1;store_remaining=store_remaining-1;read_wait=0;
     if(store_remaining==0)begin store_active=0;store_rsp_valid=1;store_rsp_bank=dma_read_bank;end
    end else read_wait=read_wait-1;
   end
  end
 end
 always @(negedge clk)if($test$plusargs("DEBUG") && $time<2000)$display("t%0t pc%0d state%0d lv%b lr%b active%b remain%0d rsp%b/%b busy%h legal%b elig%b issue%b",$time,pc,dut.dispatcher.state_r,load_valid,load_ready,load_active,load_remaining,load_rsp_valid,load_rsp_ready,dut.bank_busy,dut.descriptor_legal,dut.descriptor_eligible,dut.issue);
 initial begin
  if(!$value$plusargs("VECTORS=%s",directory))directory="/home/shmin/llm2rtl/designs/qwen25_05b_w4_shared_zcu104_r1/evidence/core_packet_run002";
  start=0;dma_write_en=0;dma_read_en=0;load_active=0;store_active=0;load_rsp_valid=0;store_rsp_valid=0;load_rsp_error=0;store_rsp_error=0;load_rsp_bank=0;store_rsp_bank=0;dma_write_bank=0;dma_read_bank=0;dma_write_addr=0;dma_read_addr=0;dma_write_data=0;dma_write_mask=0;packets=0;checked=0;total_loads=0;total_stores=0;
  fd=$fopen({directory,"/sizes.txt"},"r");got=$fscanf(fd,"%d %d\n",input_words,expected_words);$fclose(fd);if(got!=2 || input_words>65536 || expected_words>65536)$fatal(1,"sizes");
  $readmemh({directory,"/ddr_input.mem"},input_ddr,0,input_words-1);$readmemh({directory,"/ddr_expected.mem"},expected_ddr,0,expected_words-1);
  repeat(4)@(negedge clk);rst_n=1;fd=$fopen({directory,"/headers.txt"},"r");if(fd==0)$fatal(1,"headers");
  while(!$feof(fd))begin
   got=$fscanf(fd,"%s %d\n",filename,count);if(got!=2 || count>1024)$fatal(1,"header invalid");
   @(negedge clk);if(busy || load_active || store_active)$fatal(1,"publication while busy");
   $readmemh({directory,"/",filename},program_words,0,count-1);start=1;@(negedge clk);start=0;cycles=0;
   while(!done && !error)begin @(negedge clk);cycles=cycles+1;if(cycles>1000000)$fatal(1,"timeout packet%0d PC%0d",packets,pc);end
   if(error)$fatal(1,"core error packet%0d PC%0d code%0d command=%h",packets,pc,error_code,dut.command);
   if(|dut.bank_busy || load_active || store_active)$fatal(1,"END ownership/data drain");
   $display("PASS core packet%0d %s cycles%0d checkedWords%0d",packets,filename,cycles,checked);$fflush();packets=packets+1;
  end
  $fclose(fd);if(checked!=expected_words || total_stores!=13)$fatal(1,"payload coverage");
  $display("PASS core all compute opcodes native bank payloads, source last-use, partial sums across END; logical DMA/bank models only");$finish;
 end
endmodule
