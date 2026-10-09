`timescale 1ns/1ps

module tb_bank_subsystem;
  import bank_config_pkg::*;
  logic aclk=0,aresetn=0; always #2.5 aclk=~aclk;
  logic[0:15] bank_acquire_valid,bank_release_valid,bank_busy;
  logic[0:15][2:0] bank_acquire_port,bank_release_port,bank_owner_port;
  logic mm2s_write_valid,mm2s_write_ready;logic[3:0]mm2s_write_bank;
  logic[31:0]mm2s_write_addr;logic[15:0]mm2s_write_strb;logic[127:0]mm2s_write_data;
  logic s2mm_read_valid,s2mm_read_ready;logic[31:0]s2mm_read_addr;
  logic s2mm_rsp_valid;logic[1023:0]s2mm_rsp_data;
  logic sa_act_read_valid,sa_act_read_ready;logic[31:0]sa_act_read_addr;
  logic sa_act_rsp_valid;logic[255:0]sa_act_rsp_data;
  logic sa_wgt_read_valid,sa_wgt_read_ready;logic[31:0]sa_wgt_read_addr;
  logic sa_wgt_rsp_valid;logic[127:0]sa_wgt_rsp_data;
  logic sa_out_read_valid,sa_out_read_ready;logic[31:0]sa_out_read_addr;
  logic sa_out_rsp_valid;logic[1023:0]sa_out_rsp_data;
  logic sa_out_write_valid,sa_out_write_ready;logic[31:0]sa_out_write_addr;
  logic[127:0]sa_out_write_strb;logic[1023:0]sa_out_write_data;
  logic bank_subsystem_error,ownership_error,router_error;
  logic[2:0]bank_subsystem_error_code,ownership_error_code,router_error_code;
  integer cases=0;
  localparam logic[127:0] A0=128'h00112233445566778899aabbccddeeff;
  localparam logic[127:0] A1=128'hfedcba98765432100123456789abcdef;
  localparam logic[127:0] W2=128'h55aa55aa55aa55aa0f0ff0f00f0ff0f0;
  localparam logic[1023:0] P3={8{128'h0123456789abcdef_fedcba9876543210}};
  localparam logic[1023:0] P3_NEW={8{128'hdeadbeefcafef00d_123456789abcdef0}};

  bank_subsystem dut(.*);

  task automatic defaults;
    begin
      bank_acquire_valid='0;bank_acquire_port='0;bank_release_valid='0;bank_release_port='0;
      mm2s_write_valid=0;mm2s_write_bank=0;mm2s_write_addr=0;mm2s_write_strb='0;mm2s_write_data='0;
      s2mm_read_valid=0;s2mm_read_addr=0;sa_act_read_valid=0;sa_act_read_addr=0;
      sa_wgt_read_valid=0;sa_wgt_read_addr=0;sa_out_read_valid=0;sa_out_read_addr=0;
      sa_out_write_valid=0;sa_out_write_addr=0;sa_out_write_strb='0;sa_out_write_data='0;
    end
  endtask
  task automatic reset_dut;
    begin aresetn=0;defaults();repeat(4)@(posedge aclk);#1;aresetn=1;repeat(2)@(posedge aclk);#1;end
  endtask
  task automatic acquire_one(input integer b,input logic[2:0]p);
    begin @(negedge aclk);bank_acquire_valid[b]=1;bank_acquire_port[b]=p;
      @(posedge aclk);#1;@(negedge aclk);bank_acquire_valid='0;bank_acquire_port='0;
      @(posedge aclk);#1;if(!bank_busy[b]||bank_owner_port[b]!=p)$fatal(1,"acquire failed b=%0d",b);end
  endtask
  task automatic release_one(input integer b,input logic[2:0]p);
    begin @(negedge aclk);bank_release_valid[b]=1;bank_release_port[b]=p;
      @(posedge aclk);#1;@(negedge aclk);bank_release_valid='0;bank_release_port='0;
      @(posedge aclk);#1;if(bank_busy[b])$fatal(1,"release failed b=%0d",b);end
  endtask
  task automatic mmwrite(input logic[3:0]b,input logic[31:0]a,input logic[127:0]d);
    begin @(negedge aclk);mm2s_write_bank=b;mm2s_write_addr=a;mm2s_write_data=d;mm2s_write_strb='1;mm2s_write_valid=1;
      #1;if(!mm2s_write_ready)$fatal(1,"mm2s not ready b=%0d",b);
      @(posedge aclk);#1;@(negedge aclk);mm2s_write_valid=0;mm2s_write_strb=0;end
  endtask
  task automatic outwrite(input logic[31:0]a,input logic[1023:0]d);
    begin @(negedge aclk);sa_out_write_addr=a;sa_out_write_data=d;sa_out_write_strb='1;sa_out_write_valid=1;
      #1;if(!sa_out_write_ready)$fatal(1,"out write not ready");
      @(posedge aclk);#1;@(negedge aclk);sa_out_write_valid=0;sa_out_write_strb=0;end
  endtask
  task automatic actread(input logic[31:0]a,input logic[255:0]expected);
    integer n;begin @(negedge aclk);sa_act_read_addr=a;sa_act_read_valid=1;#1;
      if(!sa_act_read_ready)$fatal(1,"act not ready");@(posedge aclk);#1;@(negedge aclk);sa_act_read_valid=0;
      n=0;while(!sa_act_rsp_valid&&n<8)begin @(posedge aclk);#1;n=n+1;end
      if(!sa_act_rsp_valid||sa_act_rsp_data!==expected)$fatal(1,"ACT mismatch got=%h exp=%h",sa_act_rsp_data,expected);end
  endtask
  task automatic wgtread(input logic[31:0]a,input logic[127:0]expected);
    integer n;begin @(negedge aclk);sa_wgt_read_addr=a;sa_wgt_read_valid=1;#1;
      if(!sa_wgt_read_ready)$fatal(1,"wgt not ready");@(posedge aclk);#1;@(negedge aclk);sa_wgt_read_valid=0;
      n=0;while(!sa_wgt_rsp_valid&&n<8)begin @(posedge aclk);#1;n=n+1;end
      if(!sa_wgt_rsp_valid||sa_wgt_rsp_data!==expected)$fatal(1,"WGT mismatch");end
  endtask
  task automatic s2mmread(input logic[31:0]a,input logic[1023:0]expected);
    integer n;begin @(negedge aclk);s2mm_read_addr=a;s2mm_read_valid=1;#1;
      if(!s2mm_read_ready)$fatal(1,"s2mm not ready");@(posedge aclk);#1;@(negedge aclk);s2mm_read_valid=0;
      n=0;while(!s2mm_rsp_valid&&n<8)begin @(posedge aclk);#1;n=n+1;end
      if(!s2mm_rsp_valid||s2mm_rsp_data!==expected)$fatal(1,"S2MM mismatch");end
  endtask

  initial begin
    defaults();reset_dut();
    if(bank_busy!='0||bank_subsystem_error||ownership_error||router_error||
       s2mm_rsp_valid||sa_act_rsp_valid||sa_wgt_rsp_valid||sa_out_rsp_valid)$fatal(1,"reset state");
    cases++; $display("CASE reset PASS");

    // Atomic capability rejection: valid bank0 plus inactive bank4 commits neither.
    @(negedge aclk);bank_acquire_valid[0]=1;bank_acquire_port[0]=OWNER_MM2S;
    bank_acquire_valid[4]=1;bank_acquire_port[4]=OWNER_MM2S;
    @(posedge aclk);#1;if(bank_busy!='0||!bank_subsystem_error||bank_subsystem_error_code!=1)$fatal(1,"atomic capability gate");
    bank_acquire_valid='0;bank_acquire_port='0;cases++;$display("CASE capability atomic reject PASS");
    reset_dut();

    // Bank1 asymmetric ordering: low address occupies low 128 bits.
    acquire_one(1,OWNER_MM2S);mmwrite(1,0,A0);mmwrite(1,1,A1);release_one(1,OWNER_MM2S);
    acquire_one(1,OWNER_SA_ACT);actread(0,{A1,A0});release_one(1,OWNER_SA_ACT);
    cases++;$display("CASE bank1 asymmetric ordering high=addr1 low=addr0 PASS");

    acquire_one(2,OWNER_MM2S);mmwrite(2,7,W2);release_one(2,OWNER_MM2S);
    acquire_one(2,OWNER_SA_WGT);wgtread(7,W2);release_one(2,OWNER_SA_WGT);
    cases++;$display("CASE bank2 URAM payload PASS");

    acquire_one(3,OWNER_SA_OUT);outwrite(4,P3);release_one(3,OWNER_SA_OUT);
    acquire_one(3,OWNER_S2MM);s2mmread(4,P3);release_one(3,OWNER_S2MM);
    cases++;$display("CASE bank3 OUT to S2MM PASS");

    // Concurrent ACT/WGT requests and exactly aligned responses.
    @(negedge aclk);bank_acquire_valid[1]=1;bank_acquire_port[1]=OWNER_SA_ACT;
    bank_acquire_valid[2]=1;bank_acquire_port[2]=OWNER_SA_WGT;
    @(posedge aclk);#1;@(negedge aclk);bank_acquire_valid='0;bank_acquire_port='0;
    @(negedge aclk);sa_act_read_addr=0;sa_wgt_read_addr=7;sa_act_read_valid=1;sa_wgt_read_valid=1;#1;
    if(!sa_act_read_ready||!sa_wgt_read_ready)$fatal(1,"concurrent read ready");
    @(posedge aclk);#1;@(negedge aclk);sa_act_read_valid=0;sa_wgt_read_valid=0;
    @(posedge aclk);#1;if(sa_act_rsp_valid||sa_wgt_rsp_valid)$fatal(1,"response early");
    @(posedge aclk);#1;if(!sa_act_rsp_valid||!sa_wgt_rsp_valid||sa_act_rsp_data!=={A1,A0}||sa_wgt_rsp_data!==W2)$fatal(1,"concurrent response");
    release_one(1,OWNER_SA_ACT);release_one(2,OWNER_SA_WGT);
    cases++;$display("CASE concurrent latency3 PASS");

    // Read-first on simultaneous OUT read/write to one owned bank.
    acquire_one(3,OWNER_SA_OUT);
    @(negedge aclk);sa_out_read_addr=4;sa_out_read_valid=1;sa_out_write_addr=4;
    sa_out_write_data=P3_NEW;sa_out_write_strb='1;sa_out_write_valid=1;#1;
    if(!sa_out_read_ready||!sa_out_write_ready)$fatal(1,"out concurrent ready");
    @(posedge aclk);#1;@(negedge aclk);sa_out_read_valid=0;sa_out_write_valid=0;sa_out_write_strb=0;
    @(posedge aclk);#1;if(sa_out_rsp_valid)$fatal(1,"OUT response early");
    @(posedge aclk);#1;
    if(!sa_out_rsp_valid||sa_out_rsp_data!==P3)$fatal(1,"read_first mismatch");
    release_one(3,OWNER_SA_OUT);acquire_one(3,OWNER_S2MM);s2mmread(4,P3_NEW);release_one(3,OWNER_S2MM);
    cases++;$display("CASE bank3 read_first PASS");

    // Capability-valid but wrong current owner reaches ownership child.
    acquire_one(3,OWNER_SA_OUT);
    @(negedge aclk);bank_release_valid[3]=1;bank_release_port[3]=OWNER_S2MM;
    @(posedge aclk);#1;@(negedge aclk);bank_release_valid='0;bank_release_port='0;
    @(posedge aclk);#1;if(!ownership_error||!bank_busy[3]||bank_owner_port[3]!=OWNER_SA_OUT)$fatal(1,"mismatch release");
    repeat(2)@(posedge aclk);#1;if(!bank_subsystem_error||bank_subsystem_error_code!=2)$fatal(1,"ownership aggregate");
    cases++;$display("CASE mismatch release preserves owner PASS");reset_dut();

    acquire_one(0,OWNER_MM2S);mmwrite(0,3,A0);release_one(0,OWNER_MM2S);
    acquire_one(0,OWNER_MM2S);mmwrite(0,3,A1);release_one(0,OWNER_MM2S);
    cases++;$display("CASE bank0 write and reuse PASS");

    // Free-bank router rejection must not propagate a memory enable.
    @(negedge aclk);mm2s_write_bank=1;mm2s_write_addr=9;mm2s_write_data=W2;mm2s_write_strb='1;mm2s_write_valid=1;#1;
    if(mm2s_write_ready||dut.bank1_ena_w)$fatal(1,"rejected router touched memory");
    @(posedge aclk);#1;@(negedge aclk);mm2s_write_valid=0;mm2s_write_strb=0;
    @(posedge aclk);#1;if(!router_error)$fatal(1,"router error absent");
    repeat(2)@(posedge aclk);#1;if(!bank_subsystem_error||bank_subsystem_error_code!=3)$fatal(1,"router aggregate");
    cases++;$display("CASE rejected access no touch PASS");reset_dut();

    // Reset flushes an accepted read response pipeline, but not memory contents.
    acquire_one(2,OWNER_SA_WGT);
    @(negedge aclk);sa_wgt_read_addr=7;sa_wgt_read_valid=1;@(posedge aclk);#1;
    aresetn=0;sa_wgt_read_valid=0;repeat(4)@(posedge aclk);#1;
    if(sa_wgt_rsp_valid||bank_busy!='0||bank_subsystem_error||ownership_error||router_error)$fatal(1,"reset recovery");
    aresetn=1;repeat(2)@(posedge aclk);#1;acquire_one(2,OWNER_SA_WGT);wgtread(7,W2);
    cases++;$display("CASE reset flush and memory retention PASS");

    $display("BANK_SUBSYSTEM_XSIM_PASS cases=%0d asymmetric_word={addr1,addr0}",cases);
    $finish;
  end
endmodule
