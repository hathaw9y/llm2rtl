`timescale 1ns/1ps
module tb_bank_extension;
  import native_extension_config_pkg::*;
  logic aclk=0,aresetn=0;always #2.5 aclk=~aclk;
  logic[1:0]bank_wr_acquire_valid=0,bank_rd_acquire_valid=0,bank_wr_release_valid=0,bank_rd_release_valid=0;
  logic[1:0][2:0]bank_wr_acquire_port=0,bank_rd_acquire_port=0,bank_wr_release_port=0,bank_rd_release_port=0;
  wire[1:0]bank_wr_busy,bank_rd_busy;wire[1:0][2:0]bank_wr_owner_port,bank_rd_owner_port;
  logic mm2s_bank_ena[0:1];logic[31:0]mm2s_bank_addra[0:1];logic[127:0]mm2s_bank_dina[0:1];logic[15:0]mm2s_bank_wea[0:1];wire mm2s_bank_ready[0:1];
  logic s2mm_bank_enb[0:1];logic[31:0]s2mm_bank_addrb[0:1];wire[255:0]s2mm_bank_doutb[0:1];wire s2mm_bank_read_ready[0:1],s2mm_bank_valid[0:1];
  logic probe_enb=0;logic[31:0]probe_addrb=0;wire probe_ready,probe_valid;wire[255:0]probe_doutb;
  wire[1:0][32:0]bank_committed_prefix;wire bank_subsystem_error,ownership_error,router_error;wire[2:0]bank_subsystem_error_code,ownership_error_code,router_error_code;
  wire[1:0]bank_wr_acquire_accepted,bank_rd_acquire_accepted,bank_wr_release_accepted,bank_rd_release_accepted;
  native_extension_bank_subsystem dut(.*);
  wire tag_probe_done; native_router_tag_probe tag_probe(.aclk(aclk),.done(tag_probe_done));
  localparam logic[127:0]LO=128'h11223344556677889900aabbccddeeff,HI=128'hffeeccbbaa0099887766554433221100;
  task automatic tick;@(posedge aclk);#1;@(negedge aclk);endtask
  initial begin
    for(integer b=0;b<2;b++)begin mm2s_bank_ena[b]=0;mm2s_bank_addra[b]=0;mm2s_bank_dina[b]=0;mm2s_bank_wea[b]=0;s2mm_bank_enb[b]=0;s2mm_bank_addrb[b]=0;end
    repeat(3)tick();aresetn=1;tick();
    bank_wr_acquire_valid=1;bank_wr_acquire_port[0]=1;bank_rd_acquire_valid=1;bank_rd_acquire_port[0]=3;tick();bank_wr_acquire_valid=0;bank_rd_acquire_valid=0;
    mm2s_bank_ena[0]=1;mm2s_bank_wea[0]='1;mm2s_bank_dina[0]=LO;tick();
    if(bank_committed_prefix[0]!=0)$fatal(1,"half read word committed early");
    mm2s_bank_addra[0]=1;mm2s_bank_dina[0]=HI;tick();mm2s_bank_ena[0]=0;
    if(bank_committed_prefix[0]!=1)$fatal(1,"asymmetric prefix floor calculation");
    probe_enb=1;#0.1;if(!probe_ready||s2mm_bank_read_ready[0])$fatal(1,"custom ready isolation");tick();probe_enb=0;
    repeat(2)begin if(probe_valid||s2mm_bank_valid[0])$fatal(1,"early probe response");tick();end
    tick();if(!probe_valid||probe_doutb!=={HI,LO}||s2mm_bank_valid[0])$fatal(1,"custom tagged asymmetric payload");
    repeat(2)tick();bank_rd_release_valid=1;bank_rd_release_port[0]=3;tick();bank_rd_release_valid=0;
    bank_rd_acquire_valid=1;bank_rd_acquire_port[0]=2;tick();bank_rd_acquire_valid=0;
    s2mm_bank_enb[0]=1;tick();s2mm_bank_enb[0]=0;repeat(3)tick();
    if(!s2mm_bank_valid[0]||probe_valid||s2mm_bank_doutb[0]!=={HI,LO})$fatal(1,"ownership transfer response demux");
    if(bank_subsystem_error)$fatal(1,"unexpected extension error");
    if(!tag_probe_done)$fatal(1,"tag probe incomplete");
    $display("NATIVE_EXTENSION_XSIM_PASS");$finish;
  end
  initial begin #2000;$fatal(1,"extension timeout");end
endmodule

// Router isolation deliberately changes the externally supplied owner during an
// outstanding transaction; the engine completion contract forbids such an
// early release in normal operation. The bank does not enforce that drain.
module native_router_tag_probe(input logic aclk, output logic done);
  logic aresetn=0;
  logic[0:0]bank_wr_busy=1,bank_rd_busy=1,wr_req_valid=0,rd_req_valid=0;
  logic[0:0][2:0]bank_wr_owner_port=1,bank_rd_owner_port=3,wr_req_owner=1,rd_req_owner=3;
  logic[0:0][31:0]wr_req_addr=0,rd_req_addr=0;
  logic[0:0][127:0]wr_req_data=0,bank_doutb=128'h1234;
  logic[0:0][15:0]wr_req_strb='1;
  wire[0:0]wr_req_ready,rd_req_ready,rd_rsp_valid,bank_ena,bank_enb;
  wire[0:0][2:0]rd_rsp_owner;
  wire[0:0][127:0]rd_rsp_data,bank_dina;
  wire[0:0][15:0]bank_wea;wire[0:0][31:0]bank_addra,bank_addrb;
  wire router_error;wire[2:0]router_error_code;
  bank_native_router #(.BANK_NUM(1),.WR_CAPABILITIES(8'h0a),.RD_CAPABILITIES(8'h0c)) dut(.*);
  task automatic tick;@(posedge aclk);#1;@(negedge aclk);endtask
  initial begin
    done=0;repeat(3)tick();aresetn=1;tick();rd_req_valid=1;tick();rd_req_valid=0;
    bank_rd_owner_port=2;repeat(2)tick();tick();
    if(!rd_rsp_valid||rd_rsp_owner!=3||rd_rsp_data!=128'h1234)$fatal(1,"response tag changed with current owner");
    rd_req_valid=1;#0.1;if(rd_req_ready)$fatal(1,"capable wrong owner read");tick();rd_req_valid=0;
    if(!router_error||router_error_code!=2||bank_enb)$fatal(1,"wrong owner not rejected");
    wr_req_owner=3;wr_req_valid=1;#0.1;if(wr_req_ready||bank_ena)$fatal(1,"capable wrong owner write");tick();wr_req_valid=0;
    // First error remains owner mismatch even after a later capability violation.
    wr_req_owner=7;wr_req_valid=1;tick();wr_req_valid=0;
    if(router_error_code!=2)$fatal(1,"router first error changed");
    done=1;
  end
endmodule
