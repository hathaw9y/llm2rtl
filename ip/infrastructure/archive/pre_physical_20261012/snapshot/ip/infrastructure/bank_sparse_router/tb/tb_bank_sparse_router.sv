`timescale 1ns/1ps
module tb_bank_sparse_router;
  import bank_config_pkg::*;
  logic aclk=0,aresetn=0;logic[0:15]bank_busy='0;logic[0:15][2:0]bank_owner_port='0;
  logic mm2s_write_valid=0,mm2s_write_ready;logic[3:0]mm2s_write_bank=0;logic[31:0]mm2s_write_addr=0;logic[15:0]mm2s_write_strb=0;logic[127:0]mm2s_write_data=0;
  logic s2mm_read_valid=0,s2mm_read_ready;logic[31:0]s2mm_read_addr=0;logic s2mm_rsp_valid;logic[1023:0]s2mm_rsp_data;
  logic sa_act_read_valid=0,sa_act_read_ready;logic[31:0]sa_act_read_addr=0;logic sa_act_rsp_valid;logic[255:0]sa_act_rsp_data;
  logic sa_wgt_read_valid=0,sa_wgt_read_ready;logic[31:0]sa_wgt_read_addr=0;logic sa_wgt_rsp_valid;logic[127:0]sa_wgt_rsp_data;
  logic sa_out_read_valid=0,sa_out_read_ready;logic[31:0]sa_out_read_addr=0;logic sa_out_rsp_valid;logic[1023:0]sa_out_rsp_data;
  logic sa_out_write_valid=0,sa_out_write_ready;logic[31:0]sa_out_write_addr=0;logic[127:0]sa_out_write_strb=0;logic[1023:0]sa_out_write_data=0;
  logic bank0_ena;logic[15:0]bank0_wea;logic[31:0]bank0_addra;logic[127:0]bank0_dina;
  logic bank1_ena;logic[15:0]bank1_wea;logic[31:0]bank1_addra;logic[127:0]bank1_dina;logic bank1_enb;logic[31:0]bank1_addrb;logic[255:0]bank1_doutb;
  logic bank2_ena;logic[15:0]bank2_wea;logic[31:0]bank2_addra;logic[127:0]bank2_dina;logic bank2_enb;logic[31:0]bank2_addrb;logic[127:0]bank2_doutb;
  logic bank3_ena;logic[127:0]bank3_wea;logic[31:0]bank3_addra;logic[1023:0]bank3_dina;logic bank3_enb;logic[31:0]bank3_addrb;logic[1023:0]bank3_doutb;
  logic router_error;logic[2:0]router_error_code,router_error_owner;logic[3:0]router_error_bank;
  logic[255:0]mem1[0:15];logic[127:0]mem2[0:15];logic[1023:0]mem3[0:15];
  logic[31:0]addr1_pipe[0:2],addr2_pipe[0:2],addr3_pipe[0:2];logic[2:0]v1='0,v2='0,v3='0;
  integer model_i,model_j,init_i,loop_i,failures=0,cases=0;
  bank_sparse_router dut(.*);always #2.5 aclk=~aclk;
  always_ff @(posedge aclk)begin
    if(!aresetn)begin v1<='0;v2<='0;v3<='0;end else begin
      v1<={v1[1:0],bank1_enb};v2<={v2[1:0],bank2_enb};v3<={v3[1:0],bank3_enb};
      addr1_pipe[0]<=bank1_addrb;addr2_pipe[0]<=bank2_addrb;addr3_pipe[0]<=bank3_addrb;
      for(model_j=1;model_j<3;model_j=model_j+1)begin addr1_pipe[model_j]<=addr1_pipe[model_j-1];addr2_pipe[model_j]<=addr2_pipe[model_j-1];addr3_pipe[model_j]<=addr3_pipe[model_j-1];end
      if(bank1_ena)mem1[bank1_addra][127:0]<=bank1_dina;
      if(bank2_ena)mem2[bank2_addra]<=bank2_dina;
      if(bank3_ena)for(model_i=0;model_i<128;model_i=model_i+1)if(bank3_wea[model_i])mem3[bank3_addra][model_i*8+:8]<=bank3_dina[model_i*8+:8];
    end
  end
  always_comb begin bank1_doutb=v1[2]?mem1[addr1_pipe[2]]:'0;bank2_doutb=v2[2]?mem2[addr2_pipe[2]]:'0;bank3_doutb=v3[2]?mem3[addr3_pipe[2]]:'0;end
  task automatic check(input logic ok,input string why);
    begin if(!ok)begin $error("FAIL %s",why);failures=failures+1;end end
  endtask
  task automatic clear_req;begin mm2s_write_valid=0;s2mm_read_valid=0;sa_act_read_valid=0;sa_wgt_read_valid=0;sa_out_read_valid=0;sa_out_write_valid=0;end endtask
  task automatic reset;begin @(negedge aclk);aresetn=0;clear_req();bank_busy='0;bank_owner_port='0;repeat(2)@(posedge aclk);@(negedge aclk);aresetn=1;@(posedge aclk);#1;check(!router_error&&!s2mm_rsp_valid&&!sa_act_rsp_valid&&!sa_wgt_rsp_valid&&!sa_out_rsp_valid,"reset");end endtask
  task automatic own(input integer bank,input integer owner);begin bank_busy[bank]=1;bank_owner_port[bank]=owner;end endtask
  task automatic wait_latency;begin repeat(BANK_READ_LATENCY-1)@(posedge aclk);#1;end endtask
  initial begin
    for(init_i=0;init_i<16;init_i=init_i+1)begin mem1[init_i]={8{32'h11000000+init_i}};mem2[init_i]={4{32'h22000000+init_i}};mem3[init_i]={32{32'h33000000+init_i}};end
    reset();cases++;$display("CASE package_inventory");
    check(BANK_NUM==16&&BANK_ADDR_WIDTH==32&&OPCODE_WIDTH==4&&BANK_READ_LATENCY==3,"package constants");
    check(ACTIVE_BANK_MASK==16'hf&&bank_type(0)==BANK_BRAM&&bank_type(1)==BANK_BRAM&&bank_type(2)==BANK_URAM&&bank_type(3)==BANK_BRAM&&bank_type(4)==BANK_NONE,"types");
    check(bank_write_width(0)==128&&bank_read_width(1)==256&&bank_write_depth(2)==65536&&bank_write_width(3)==1024,"inventory widths/depth");
    check(MM2S_BANK_MASK==16'h7&&S2MM_BANK_MASK==16'h8&&SA_ACT_BANK_MASK==16'h2&&SA_WGT_BANK_MASK==16'h4&&SA_OUT_BANK_MASK==16'h8,"role lists");

    reset();cases++;$display("CASE mm2s_banks_0_1_2");
    for(loop_i=0;loop_i<3;loop_i=loop_i+1)begin @(negedge aclk);bank_busy='0;bank_owner_port='0;own(loop_i,1);mm2s_write_bank=loop_i;mm2s_write_addr=loop_i+1;mm2s_write_strb=16'hffff;mm2s_write_data={4{32'hA0000000+loop_i}};mm2s_write_valid=1;#1;
      check(mm2s_write_ready&&(loop_i==0?bank0_ena:(loop_i==1?bank1_ena:bank2_ena)),"MM2S sparse decode");@(posedge aclk);@(negedge aclk);mm2s_write_valid=0;end

    reset();cases++;$display("CASE mm2s_reject_bank3_and_none");
    @(negedge aclk);own(3,1);mm2s_write_bank=3;mm2s_write_valid=1;#1;check(!mm2s_write_ready&&!bank3_ena,"bank3 capability reject");@(posedge aclk);#1;check(router_error_code==2,"role unsupported code");
    reset();@(negedge aclk);mm2s_write_bank=4;mm2s_write_valid=1;#1;check(!mm2s_write_ready&&!bank0_ena&&!bank1_ena&&!bank2_ena,"NONE reject");@(posedge aclk);#1;check(router_error_code==1,"inactive code");

    reset();cases++;$display("CASE act_256_latency_and_ii1");
    @(negedge aclk);own(1,3);sa_act_read_addr=2;sa_act_read_valid=1;#1;check(sa_act_read_ready&&bank1_enb,"ACT accept");@(posedge aclk);@(negedge aclk);sa_act_read_addr=3;#1;check(sa_act_read_ready,"ACT consecutive");@(posedge aclk);@(negedge aclk);sa_act_read_valid=0;@(posedge aclk);#1;
    check(sa_act_rsp_valid&&sa_act_rsp_data==mem1[2],"ACT first full payload");@(posedge aclk);#1;check(sa_act_rsp_valid&&sa_act_rsp_data==mem1[3],"ACT second full payload");

    reset();cases++;$display("CASE wgt_128_latency");
    @(negedge aclk);own(2,4);sa_wgt_read_addr=5;sa_wgt_read_valid=1;#1;check(sa_wgt_read_ready&&bank2_enb,"WGT accept");@(posedge aclk);@(negedge aclk);sa_wgt_read_valid=0;wait_latency();check(sa_wgt_rsp_valid&&sa_wgt_rsp_data==mem2[5],"WGT full response");

    reset();cases++;$display("CASE out_1024_read_write");
    @(negedge aclk);own(3,5);sa_out_read_addr=6;sa_out_read_valid=1;sa_out_write_addr=7;sa_out_write_strb={128{1'b1}};sa_out_write_data={32{32'hDEADBEEF}};sa_out_write_valid=1;#1;
    check(sa_out_read_ready&&sa_out_write_ready&&bank3_enb&&bank3_ena,"OUT simultaneous ports");@(posedge aclk);@(negedge aclk);clear_req();wait_latency();check(sa_out_rsp_valid&&sa_out_rsp_data==mem3[6],"OUT 1024 response");check(mem3[7]=={32{32'hDEADBEEF}},"OUT 1024 write");

    reset();cases++;$display("CASE s2mm_1024_read");
    @(negedge aclk);own(3,2);s2mm_read_addr=8;s2mm_read_valid=1;#1;check(s2mm_read_ready&&bank3_enb,"S2MM accept");@(posedge aclk);@(negedge aclk);s2mm_read_valid=0;wait_latency();check(s2mm_rsp_valid&&s2mm_rsp_data==mem3[8],"S2MM full response");check(!sa_out_rsp_valid,"destination only");

    reset();cases++;$display("CASE bank3_read_collision");
    @(negedge aclk);own(3,2);s2mm_read_valid=1;sa_out_read_valid=1;#1;check(!s2mm_read_ready&&!sa_out_read_ready&&!bank3_enb,"collision blocked");@(posedge aclk);#1;check(router_error&&router_error_code==5&&router_error_owner==2,"collision metadata");

    reset();cases++;$display("CASE distinct_banks_concurrent");
    @(negedge aclk);own(1,3);own(2,4);own(3,5);sa_act_read_addr=1;sa_act_read_valid=1;sa_wgt_read_addr=1;sa_wgt_read_valid=1;sa_out_write_addr=1;sa_out_write_strb='1;sa_out_write_data={32{32'hCAFEBABE}};sa_out_write_valid=1;#1;
    check(sa_act_read_ready&&sa_wgt_read_ready&&sa_out_write_ready&&bank1_enb&&bank2_enb&&bank3_ena,"three-bank concurrent");

    reset();cases++;$display("CASE wrong_owner_and_free");
    @(negedge aclk);own(1,4);sa_act_read_valid=1;#1;check(!sa_act_read_ready&&!bank1_enb,"wrong owner blocked");@(posedge aclk);#1;check(router_error_code==4&&router_error_owner==3,"wrong owner fault");
    reset();@(negedge aclk);sa_wgt_read_valid=1;#1;check(!sa_wgt_read_ready&&!bank2_enb,"free blocked");@(posedge aclk);#1;check(router_error_code==3&&router_error_owner==4,"free fault");

    reset();cases++;$display("CASE reset_flush_pipeline_fault");
    @(negedge aclk);own(1,3);sa_act_read_valid=1;@(posedge aclk);@(negedge aclk);sa_act_read_valid=0;mm2s_write_bank=9;mm2s_write_valid=1;@(posedge aclk);@(negedge aclk);aresetn=0;clear_req();@(posedge aclk);#1;check(!router_error&&!sa_act_rsp_valid,"active reset flush");@(negedge aclk);aresetn=1;
    repeat(4) begin @(posedge aclk);#1;check(!sa_act_rsp_valid,"no stale response");end

    if(failures==0) begin $display("PASS: bank_sparse_router verification cases=%0d",cases);$finish;end
    $fatal(1,"failures=%0d",failures);
  end
endmodule
