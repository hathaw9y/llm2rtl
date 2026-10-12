`timescale 1ns/1ps
module tb_bank_port_router;
  localparam integer BANK_NUM=8,BANK_NUM_WIDTH=4,PORT_ROLE_WIDTH=3;
  localparam integer ADDR_WIDTH=8,WRITE_DATA_WIDTH=32,READ_DATA_WIDTH=32;
  localparam integer BYTE_WRITE_WIDTH=8,READ_LATENCY=3,DEPTH=32;
  logic aclk=0,aresetn=0;
  logic [0:BANK_NUM-1] bank_busy='0;
  logic [0:BANK_NUM-1][PORT_ROLE_WIDTH-1:0] bank_owner_port='0;
  logic mm2s_write_valid=0,mm2s_write_ready;logic[BANK_NUM_WIDTH-1:0]mm2s_write_bank=0;
  logic[ADDR_WIDTH-1:0]mm2s_write_addr=0;logic[3:0]mm2s_write_strb=0;logic[31:0]mm2s_write_data=0;
  logic s2mm_read_valid=0,s2mm_read_ready;logic[3:0]s2mm_read_bank=0;logic[7:0]s2mm_read_addr=0;
  logic s2mm_rsp_valid;logic[3:0]s2mm_rsp_bank;logic[31:0]s2mm_rsp_data;
  logic gemm_act_read_valid=0,gemm_act_read_ready;logic[3:0]gemm_act_read_bank=0;logic[7:0]gemm_act_read_addr=0;
  logic gemm_act_rsp_valid;logic[3:0]gemm_act_rsp_bank;logic[31:0]gemm_act_rsp_data;
  logic gemm_wgt_read_valid=0,gemm_wgt_read_ready;logic[3:0]gemm_wgt_read_bank=0;logic[7:0]gemm_wgt_read_addr=0;
  logic gemm_wgt_rsp_valid;logic[3:0]gemm_wgt_rsp_bank;logic[31:0]gemm_wgt_rsp_data;
  logic gemm_psum_read_valid=0,gemm_psum_read_ready;logic[3:0]gemm_psum_read_bank=0;logic[7:0]gemm_psum_read_addr=0;
  logic gemm_psum_rsp_valid;logic[3:0]gemm_psum_rsp_bank;logic[31:0]gemm_psum_rsp_data;
  logic gemm_psum_write_valid=0,gemm_psum_write_ready;logic[3:0]gemm_psum_write_bank=0;
  logic[7:0]gemm_psum_write_addr=0;logic[3:0]gemm_psum_write_strb=0;logic[31:0]gemm_psum_write_data=0;
  logic[0:BANK_NUM-1]bank_ena,bank_enb;logic[0:BANK_NUM-1][3:0]bank_wea;
  logic[0:BANK_NUM-1][7:0]bank_addra,bank_addrb;logic[0:BANK_NUM-1][31:0]bank_dina,bank_doutb='0;
  logic router_error;logic[2:0]router_error_code,router_error_owner;logic[3:0]router_error_bank;
  logic[31:0]mem[0:BANK_NUM-1][0:DEPTH-1];
  logic[0:BANK_NUM-1][READ_LATENCY-1:0] model_rd_valid='0;
  logic[7:0]model_rd_addr[0:BANK_NUM-1][0:READ_LATENCY-1];
  integer model_b,model_p,init_b,init_p,failures=0,cases=0;

  bank_port_router #(.BANK_NUM(BANK_NUM),.BANK_NUM_WIDTH(BANK_NUM_WIDTH),
    .PORT_ROLE_WIDTH(PORT_ROLE_WIDTH),.ADDR_WIDTH(ADDR_WIDTH),
    .WRITE_DATA_WIDTH(WRITE_DATA_WIDTH),.READ_DATA_WIDTH(READ_DATA_WIDTH),
    .BYTE_WRITE_WIDTH(BYTE_WRITE_WIDTH),.READ_LATENCY(READ_LATENCY)) dut(.*);
  always #2.5 aclk=~aclk;

  always_ff @(posedge aclk) begin
    if(!aresetn) begin model_rd_valid<='0; end else begin
      for(model_b=0;model_b<BANK_NUM;model_b=model_b+1) begin
        model_rd_valid[model_b][0]<=bank_enb[model_b];model_rd_addr[model_b][0]<=bank_addrb[model_b];
        for(model_p=1;model_p<READ_LATENCY;model_p=model_p+1) begin
          model_rd_valid[model_b][model_p]<=model_rd_valid[model_b][model_p-1];model_rd_addr[model_b][model_p]<=model_rd_addr[model_b][model_p-1];
        end
        if(bank_ena[model_b]) begin
          if(bank_wea[model_b][0])mem[model_b][bank_addra[model_b]][7:0]<=bank_dina[model_b][7:0];
          if(bank_wea[model_b][1])mem[model_b][bank_addra[model_b]][15:8]<=bank_dina[model_b][15:8];
          if(bank_wea[model_b][2])mem[model_b][bank_addra[model_b]][23:16]<=bank_dina[model_b][23:16];
          if(bank_wea[model_b][3])mem[model_b][bank_addra[model_b]][31:24]<=bank_dina[model_b][31:24];
        end
      end
    end
  end
  always_comb for(integer k=0;k<BANK_NUM;k=k+1)
    bank_doutb[k]=model_rd_valid[k][READ_LATENCY-1]?mem[k][model_rd_addr[k][READ_LATENCY-1]]:'0;

  task automatic check(input logic ok,input string why);
    begin if(!ok)begin $error("FAIL %s",why);failures=failures+1;end end
  endtask
  task automatic clear_requests;
    begin mm2s_write_valid=0;s2mm_read_valid=0;gemm_act_read_valid=0;gemm_wgt_read_valid=0;
      gemm_psum_read_valid=0;gemm_psum_write_valid=0; end
  endtask
  task automatic reset_dut;
    begin @(negedge aclk);aresetn=0;clear_requests();bank_busy='0;bank_owner_port='0;
      repeat(2)@(posedge aclk);@(negedge aclk);aresetn=1;@(posedge aclk);#1;
      check(!router_error&&!s2mm_rsp_valid&&!gemm_act_rsp_valid&&!gemm_wgt_rsp_valid&&!gemm_psum_rsp_valid,"reset clear");end
  endtask
  task automatic own(input integer bank,input integer owner);
    begin bank_busy[bank]=1;bank_owner_port[bank]=owner;end
  endtask

  initial begin
    for(init_b=0;init_b<BANK_NUM;init_b=init_b+1)
      for(init_p=0;init_p<DEPTH;init_p=init_p+1)
        mem[init_b][init_p]=32'h1000_0000+(init_b<<12)+init_p;

    reset_dut();cases=cases+1;$display("CASE bank0_mm2s_write");
    @(negedge aclk);own(0,1);mm2s_write_bank=0;mm2s_write_addr=3;mm2s_write_strb=4'hf;
    mm2s_write_data=32'hAABBCCDD;mm2s_write_valid=1;#1;
    check(mm2s_write_ready&&bank_ena[0]&&bank_wea[0]==4'hf&&!bank_ena[1],"bank0 MM2S route");
    @(posedge aclk);@(negedge aclk);clear_requests();check(mem[0][3]==32'hAABBCCDD,"MM2S write commit");

    reset_dut();cases=cases+1;$display("CASE s2mm_latency_three");
    @(negedge aclk);own(2,2);s2mm_read_bank=2;s2mm_read_addr=5;s2mm_read_valid=1;#1;
    check(s2mm_read_ready&&bank_enb[2],"S2MM accepted");
    @(posedge aclk);@(negedge aclk);s2mm_read_valid=0;
    repeat(READ_LATENCY-1)begin check(!s2mm_rsp_valid,"S2MM no early response");@(posedge aclk);#1;end
    check(s2mm_rsp_valid&&s2mm_rsp_bank==2&&s2mm_rsp_data==mem[2][5],"S2MM exact latency/data");
    check(!gemm_act_rsp_valid&&!gemm_wgt_rsp_valid&&!gemm_psum_rsp_valid,"S2MM destination only");

    reset_dut();cases=cases+1;$display("CASE act_wgt_concurrent");
    @(negedge aclk);own(1,3);own(4,4);gemm_act_read_bank=1;gemm_act_read_addr=7;gemm_act_read_valid=1;
    gemm_wgt_read_bank=4;gemm_wgt_read_addr=9;gemm_wgt_read_valid=1;#1;
    check(gemm_act_read_ready&&gemm_wgt_read_ready&&bank_enb[1]&&bank_enb[4],"ACT/WGT concurrent accept");
    @(posedge aclk);@(negedge aclk);clear_requests();repeat(READ_LATENCY-1)@(posedge aclk);#1;
    check(gemm_act_rsp_valid&&gemm_act_rsp_bank==1&&gemm_act_rsp_data==mem[1][7],"ACT response");
    check(gemm_wgt_rsp_valid&&gemm_wgt_rsp_bank==4&&gemm_wgt_rsp_data==mem[4][9],"WGT response");

    reset_dut();cases=cases+1;$display("CASE psum_read_write_same_bank");
    @(negedge aclk);own(3,5);gemm_psum_read_bank=3;gemm_psum_read_addr=1;gemm_psum_read_valid=1;
    gemm_psum_write_bank=3;gemm_psum_write_addr=2;gemm_psum_write_strb=4'hf;
    gemm_psum_write_data=32'h55AA1234;gemm_psum_write_valid=1;#1;
    check(gemm_psum_read_ready&&gemm_psum_write_ready&&bank_enb[3]&&bank_ena[3],"PSUM dual ports");
    @(posedge aclk);@(negedge aclk);clear_requests();repeat(READ_LATENCY-1)@(posedge aclk);#1;
    check(gemm_psum_rsp_valid&&gemm_psum_rsp_data==mem[3][1]&&mem[3][2]==32'h55AA1234,"PSUM read/write results");

    reset_dut();cases=cases+1;$display("CASE three_ports_distinct_and_overlap_reads");
    @(negedge aclk);own(0,2);own(1,3);own(2,4);s2mm_read_bank=0;s2mm_read_addr=4;s2mm_read_valid=1;
    gemm_act_read_bank=1;gemm_act_read_addr=5;gemm_act_read_valid=1;gemm_wgt_read_bank=2;gemm_wgt_read_addr=6;gemm_wgt_read_valid=1;#1;
    check(s2mm_read_ready&&gemm_act_read_ready&&gemm_wgt_read_ready,"three distinct ports ready");
    @(posedge aclk);@(negedge aclk);s2mm_read_addr=8;gemm_act_read_addr=9;gemm_wgt_read_addr=10;#1;
    check(s2mm_read_ready&&gemm_act_read_ready&&gemm_wgt_read_ready,"consecutive overlapping accepts");
    @(posedge aclk);@(negedge aclk);clear_requests();repeat(READ_LATENCY-2)@(posedge aclk);#1;
    check(s2mm_rsp_valid&&s2mm_rsp_data==mem[0][4]&&gemm_act_rsp_data==mem[1][5]&&gemm_wgt_rsp_data==mem[2][6],"first overlap responses");
    @(posedge aclk);#1;check(s2mm_rsp_valid&&s2mm_rsp_data==mem[0][8]&&gemm_act_rsp_data==mem[1][9]&&gemm_wgt_rsp_data==mem[2][10],"second overlap responses");

    reset_dut();cases=cases+1;$display("CASE wrong_owner_fault_sticky");
    @(negedge aclk);own(1,4);gemm_act_read_bank=1;gemm_act_read_addr=1;gemm_act_read_valid=1;#1;
    check(!gemm_act_read_ready&&bank_enb=='0,"wrong owner blocked");@(posedge aclk);#1;
    check(router_error&&router_error_code==3&&router_error_owner==3&&router_error_bank==1,"wrong owner metadata");
    @(negedge aclk);clear_requests();own(2,2);s2mm_read_bank=2;s2mm_read_valid=1;@(posedge aclk);#1;
    check(router_error_code==3&&router_error_owner==3&&router_error_bank==1,"first fault sticky");

    reset_dut();cases=cases+1;$display("CASE free_bank_fault");
    @(negedge aclk);s2mm_read_bank=2;s2mm_read_valid=1;#1;check(!s2mm_read_ready&&bank_enb=='0,"free blocked");
    @(posedge aclk);#1;check(router_error&&router_error_code==2&&router_error_owner==2&&router_error_bank==2,"free metadata");

    reset_dut();cases=cases+1;$display("CASE out_of_range_fault");
    @(negedge aclk);mm2s_write_bank=12;mm2s_write_valid=1;#1;check(!mm2s_write_ready&&bank_ena=='0,"range blocked");
    @(posedge aclk);#1;check(router_error&&router_error_code==1&&router_error_owner==1&&router_error_bank==12,"range metadata");

    reset_dut();cases=cases+1;$display("CASE write_and_read_collisions");
    @(negedge aclk);own(3,1);mm2s_write_bank=3;mm2s_write_valid=1;gemm_psum_write_bank=3;gemm_psum_write_valid=1;#1;
    check(!mm2s_write_ready&&!gemm_psum_write_ready&&bank_ena=='0,"write collision no route");
    @(posedge aclk);#1;check(router_error_code==4&&router_error_owner==1,"write collision priority");
    reset_dut();@(negedge aclk);own(4,2);s2mm_read_bank=4;s2mm_read_valid=1;gemm_act_read_bank=4;gemm_act_read_valid=1;#1;
    check(!s2mm_read_ready&&!gemm_act_read_ready&&bank_enb=='0,"read collision no route");
    @(posedge aclk);#1;check(router_error_code==5&&router_error_owner==2,"read collision priority");

    reset_dut();cases=cases+1;$display("CASE reset_flush_active_pipeline_and_fault");
    @(negedge aclk);own(1,3);gemm_act_read_bank=1;gemm_act_read_addr=2;gemm_act_read_valid=1;
    @(posedge aclk);@(negedge aclk);gemm_act_read_valid=0;gemm_wgt_read_bank=7;gemm_wgt_read_valid=1;
    @(posedge aclk);@(negedge aclk);aresetn=0;clear_requests();@(posedge aclk);#1;
    check(!router_error&&!gemm_act_rsp_valid&&!gemm_wgt_rsp_valid,"reset flushes pipeline/fault");
    @(negedge aclk);aresetn=1;repeat(READ_LATENCY+1)begin @(posedge aclk);#1;check(!gemm_act_rsp_valid,"no stale response");end

    reset_dut();cases=cases+1;$display("CASE fault_priority_owner_then_write");
    @(negedge aclk);gemm_psum_read_bank=10;gemm_psum_read_valid=1;mm2s_write_bank=11;mm2s_write_valid=1;#1;
    @(posedge aclk);#1;check(router_error_code==1&&router_error_owner==1&&router_error_bank==11,"lowest owner priority");

    if(failures==0)begin $display("PASS: bank_port_router verification cases=%0d",cases);$finish;end
    $fatal(1,"bank_port_router failures=%0d",failures);
  end
endmodule
