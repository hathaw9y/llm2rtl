`timescale 1ns/1ps
module tb_execution_fabric_sync_gap;
  logic aclk=0,aresetn=0;always #2.5 aclk=~aclk;
  logic cmd_dispatcher_start,cmd_dispatcher_busy,cmd_dispatcher_done,cmd_dispatcher_error;
  logic[7:0]cmd_dispatcher_error_code;logic[9:0]current_pc;logic cmd_enb;logic[9:0]cmd_addrb;logic[127:0]cmd_doutb;
  logic mm2s_pause,mm2s_abort,s2mm_pause,s2mm_abort,mm2s_faulted,s2mm_faulted;
  logic[3:0]mm2s_sequence_tag,mm2s_received_tag,s2mm_sequence_tag,s2mm_received_tag;
  logic[7:0]mm2s_raw_status,s2mm_raw_status;
  logic mm2s_completion_valid,mm2s_completion_error,s2mm_completion_valid,s2mm_completion_error;
  logic[7:0]mm2s_completion_error_code,s2mm_completion_error_code;
  logic[3:0]mm2s_completion_bank,s2mm_completion_bank;
  logic[71:0]m_axis_mm2s_cmd_tdata,m_axis_s2mm_cmd_tdata;logic m_axis_mm2s_cmd_tvalid,m_axis_mm2s_cmd_tready;
  logic[63:0]s_axis_mm2s_tdata;logic[7:0]s_axis_mm2s_tkeep;logic s_axis_mm2s_tvalid,s_axis_mm2s_tready,s_axis_mm2s_tlast;
  logic[7:0]s_axis_mm2s_sts_tdata;logic s_axis_mm2s_sts_tkeep,s_axis_mm2s_sts_tvalid,s_axis_mm2s_sts_tready,s_axis_mm2s_sts_tlast;
  logic m_axis_s2mm_cmd_tvalid,m_axis_s2mm_cmd_tready;logic[63:0]m_axis_s2mm_tdata;logic[7:0]m_axis_s2mm_tkeep;
  logic m_axis_s2mm_tvalid,m_axis_s2mm_tready,m_axis_s2mm_tlast;logic[7:0]s_axis_s2mm_sts_tdata;
  logic s_axis_s2mm_sts_tkeep,s_axis_s2mm_sts_tvalid,s_axis_s2mm_sts_tready,s_axis_s2mm_sts_tlast;
  logic m_ctrl_sa_cmd_valid,m_ctrl_sa_cmd_ready;logic[5:0]m_ctrl_sa_m_size;logic[10:0]m_ctrl_sa_n_size;
  logic[11:0]m_ctrl_sa_k_size;logic[3:0]m_ctrl_sa_act_bank,m_ctrl_sa_wgt_bank,m_ctrl_sa_out_bank;
  logic[31:0]m_ctrl_sa_out_base_addr;logic s_ctrl_sa_done_valid,m_ctrl_sa_done_ready,s_ctrl_sa_done_error;
  logic[3:0]s_ctrl_sa_act_bank,s_ctrl_sa_wgt_bank,s_ctrl_sa_out_bank;
  logic sa_act_read_valid,sa_act_read_ready;logic[31:0]sa_act_read_addr;logic sa_act_rsp_valid;logic[255:0]sa_act_rsp_data;
  logic sa_wgt_read_valid,sa_wgt_read_ready;logic[31:0]sa_wgt_read_addr;logic sa_wgt_rsp_valid;logic[127:0]sa_wgt_rsp_data;
  logic sa_out_read_valid,sa_out_read_ready;logic[31:0]sa_out_read_addr;logic sa_out_rsp_valid;logic[1023:0]sa_out_rsp_data;
  logic sa_out_write_valid,sa_out_write_ready;logic[31:0]sa_out_write_addr;logic[127:0]sa_out_write_strb;logic[1023:0]sa_out_write_data;
  logic[0:15]bank_busy;logic[0:15][2:0]bank_owner_port;logic bank_subsystem_error,ownership_error,router_error;
  logic[2:0]bank_subsystem_error_code,ownership_error_code,router_error_code;
  logic[127:0]cmd_mem[0:1023];integer vendor_mm2s_commands,vendor_s2mm_commands;
  localparam logic[63:0]A0=64'h0102030405060708,A1=64'h1112131415161718;
  localparam logic[63:0]A2=64'h2122232425262728,A3=64'h3132333435363738;
  localparam logic[63:0]W0=64'h4142434445464748,W1=64'h5152535455565758;
  logic[1023:0]OUT_WORD;

  execution_fabric dut(.*);
  // Real command-BRAM behavior: registered one-cycle native-port read.
  always_ff @(posedge aclk) if(cmd_enb) cmd_doutb<=cmd_mem[cmd_addrb];

  integer audit_cycle,act_accept_cycle,wgt_accept_cycle,s2_accept_cycle;
  integer bank_write_fires,mm2s_successes,s2mm_successes;
  logic act_pending,wgt_pending,s2_pending;
  always @(posedge aclk) begin
    if(!aresetn) begin
      audit_cycle=0;act_accept_cycle=-1;wgt_accept_cycle=-1;s2_accept_cycle=-1;
      bank_write_fires=0;mm2s_successes=0;s2mm_successes=0;
      act_pending=0;wgt_pending=0;s2_pending=0;
    end else begin
      audit_cycle=audit_cycle+1;
      if(dut.bs_mm_valid&&dut.bs_mm_ready)bank_write_fires=bank_write_fires+1;
      if(sa_act_read_valid&&sa_act_read_ready)begin act_accept_cycle=audit_cycle;act_pending=1;end
      if(sa_wgt_read_valid&&sa_wgt_read_ready)begin wgt_accept_cycle=audit_cycle;wgt_pending=1;end
      if(dut.bs_s2_read_valid&&dut.bs_s2_read_ready)begin s2_accept_cycle=audit_cycle;s2_pending=1;end
      if(sa_act_rsp_valid)begin
        if(!act_pending||audit_cycle-act_accept_cycle!=3)$fatal(1,"ACT response latency expected 3 got %0d",audit_cycle-act_accept_cycle);
        act_pending=0;
      end
      if(sa_wgt_rsp_valid)begin
        if(!wgt_pending||audit_cycle-wgt_accept_cycle!=3)$fatal(1,"WGT response latency expected 3 got %0d",audit_cycle-wgt_accept_cycle);
        wgt_pending=0;
      end
      if(dut.bs_s2_rsp_valid)begin
        if(!s2_pending||audit_cycle-s2_accept_cycle!=3)$fatal(1,"S2MM response latency expected 3 got %0d",audit_cycle-s2_accept_cycle);
        s2_pending=0;
      end
      if(dut.e_mm2s_sts_valid&&dut.e_mm2s_sts_ready&&dut.e_mm2s_sts_code==0)begin
        if(mm2s_successes==0 && (dut.e_mm2s_sts_bank!=1||mm2s_sequence_tag!=0))$fatal(1,"MM2S completion identity 0");
        if(mm2s_successes==1 && (dut.e_mm2s_sts_bank!=2||mm2s_sequence_tag!=1))$fatal(1,"MM2S completion identity 1");
        mm2s_successes=mm2s_successes+1;
      end
      if(dut.e_s2mm_sts_valid&&dut.e_s2mm_sts_ready&&dut.e_s2mm_sts_code==0)begin
        if(dut.e_s2mm_sts_bank!=3||s2mm_sequence_tag==3)$fatal(1,"S2MM completion used sequence tag as bank");
        s2mm_successes=s2mm_successes+1;
      end
      for(integer q=3;q<16;q++)if(dut.wr_req[q]||dut.mm_start[q]||dut.mm_valid[q])$fatal(1,"unsupported MM2S activity bank %0d",q);
      for(integer q=0;q<16;q++)if(q!=3 && (dut.rd_req[q]||dut.s2_start[q]||dut.s2_valid[q]))$fatal(1,"unsupported S2MM activity bank %0d",q);
      if(dut.bs_mm_valid)begin
        if(dut.mm_sel0_w)begin
          if({dut.bs_mm_bank,dut.bs_mm_addr,dut.bs_mm_strb,dut.bs_mm_data}!={dut.a_wr_bank[0],dut.a_wr_addr[0],dut.a_wr_strb[0],dut.a_wr_data[0]})$fatal(1,"MM2S mux source0 payload");
        end else if(dut.mm_sel1_w)begin
          if({dut.bs_mm_bank,dut.bs_mm_addr,dut.bs_mm_strb,dut.bs_mm_data}!={dut.a_wr_bank[1],dut.a_wr_addr[1],dut.a_wr_strb[1],dut.a_wr_data[1]})$fatal(1,"MM2S mux source1 payload");
        end else if(dut.mm_sel2_w)begin
          if({dut.bs_mm_bank,dut.bs_mm_addr,dut.bs_mm_strb,dut.bs_mm_data}!={dut.a_wr_bank[2],dut.a_wr_addr[2],dut.a_wr_strb[2],dut.a_wr_data[2]})$fatal(1,"MM2S mux source2 payload");
        end else $fatal(1,"MM2S valid without selection");
      end
    end
  end

  function automatic logic[127:0]command(input logic[3:0]op,input logic[3:0]b0,b1,b2,
      input logic[31:0]off,input logic[22:0]count,input logic[31:0]addr);
    logic[127:0]v;begin v='0;v[127:124]=op;v[123:120]=b0;v[119:116]=b1;v[115:112]=b2;
      v[111:80]=off;v[79:57]=count;v[56:25]=addr;command=v;end
  endfunction
  task automatic defaults;
    begin cmd_dispatcher_start=0;mm2s_pause=0;mm2s_abort=0;s2mm_pause=0;s2mm_abort=0;
      m_axis_mm2s_cmd_tready=0;s_axis_mm2s_tdata=0;s_axis_mm2s_tkeep=0;s_axis_mm2s_tvalid=0;s_axis_mm2s_tlast=0;
      s_axis_mm2s_sts_tdata=0;s_axis_mm2s_sts_tkeep=1;s_axis_mm2s_sts_tvalid=0;s_axis_mm2s_sts_tlast=1;
      m_axis_s2mm_cmd_tready=0;m_axis_s2mm_tready=0;s_axis_s2mm_sts_tdata=0;s_axis_s2mm_sts_tkeep=1;
      s_axis_s2mm_sts_tvalid=0;s_axis_s2mm_sts_tlast=1;m_ctrl_sa_cmd_ready=0;s_ctrl_sa_done_valid=0;
      s_ctrl_sa_done_error=0;s_ctrl_sa_act_bank=1;s_ctrl_sa_wgt_bank=2;s_ctrl_sa_out_bank=3;
      sa_act_read_valid=0;sa_act_read_addr=0;sa_wgt_read_valid=0;sa_wgt_read_addr=0;
      sa_out_read_valid=0;sa_out_read_addr=0;sa_out_write_valid=0;sa_out_write_addr=0;
      sa_out_write_strb='1;sa_out_write_data=0;vendor_mm2s_commands=0;vendor_s2mm_commands=0;end
  endtask
  task automatic reset_dut;
    begin @(negedge aclk);aresetn=0;defaults();repeat(5)@(negedge aclk);aresetn=1;repeat(3)@(negedge aclk);end
  endtask
  task automatic start_program;
    begin @(negedge aclk);cmd_dispatcher_start=1;@(negedge aclk);cmd_dispatcher_start=0;end
  endtask
  task automatic mm2s_transfer(input logic[31:0]expected_addr,input integer beats,
      input logic[63:0]p0,p1,p2,p3,input logic fault_status);
    logic[71:0]held;logic[3:0]seq;logic[63:0]p[0:3];begin
      p[0]=p0;p[1]=p1;p[2]=p2;p[3]=p3;wait(m_axis_mm2s_cmd_tvalid);held=m_axis_mm2s_cmd_tdata;
      repeat(3)begin @(posedge aclk);#1;if(!m_axis_mm2s_cmd_tvalid||m_axis_mm2s_cmd_tdata!==held)$fatal(1,"MM2S cmd unstable");end
      if(held[63:32]!==expected_addr)$fatal(1,"MM2S address");seq=held[67:64];
      @(negedge aclk);m_axis_mm2s_cmd_tready=1;@(negedge aclk);m_axis_mm2s_cmd_tready=0;vendor_mm2s_commands++;
      for(integer j=0;j<beats;j++)begin
        @(negedge aclk);s_axis_mm2s_tdata=p[j];s_axis_mm2s_tkeep=8'hff;s_axis_mm2s_tvalid=1;s_axis_mm2s_tlast=(j==beats-1);
        do @(posedge aclk);while(!s_axis_mm2s_tready);@(negedge aclk);s_axis_mm2s_tvalid=0;s_axis_mm2s_tlast=0;
      end
      if(expected_addr==32'h1000)begin
        wait(bank_busy[2]);
        if(bank_owner_port[2]!=3'd1)$fatal(1,"second MM2S was not concurrently acquired");
      end
      repeat(3)@(negedge aclk);s_axis_mm2s_sts_tdata=fault_status?{1'b1,3'b100,seq}:{1'b1,3'b000,seq};
      s_axis_mm2s_sts_tvalid=1;do @(posedge aclk);while(!s_axis_mm2s_sts_tready);
      @(negedge aclk);s_axis_mm2s_sts_tvalid=0;
    end endtask
  task automatic pulse_read_act;
    begin @(negedge aclk);sa_act_read_addr=0;sa_act_read_valid=1;do @(posedge aclk);while(!sa_act_read_ready);
      @(negedge aclk);sa_act_read_valid=0;wait(sa_act_rsp_valid);
      if(sa_act_rsp_data!=={A3,A2,A1,A0})$fatal(1,"ACT payload mismatch %h",sa_act_rsp_data);end
  endtask
  task automatic pulse_read_wgt;
    begin @(negedge aclk);sa_wgt_read_addr=0;sa_wgt_read_valid=1;do @(posedge aclk);while(!sa_wgt_read_ready);
      @(negedge aclk);sa_wgt_read_valid=0;wait(sa_wgt_rsp_valid);
      if(sa_wgt_rsp_data!=={W1,W0})$fatal(1,"WGT payload mismatch");end
  endtask
  task automatic gemm_bfm;
    logic[31:0]held;begin wait(m_ctrl_sa_cmd_valid);held={m_ctrl_sa_m_size,m_ctrl_sa_n_size,m_ctrl_sa_k_size,3'd0};
      repeat(2)begin @(posedge aclk);#1;if(!m_ctrl_sa_cmd_valid||{m_ctrl_sa_m_size,m_ctrl_sa_n_size,m_ctrl_sa_k_size,3'd0}!==held)$fatal(1,"GEMM unstable");end
      if(m_ctrl_sa_act_bank!=1||m_ctrl_sa_wgt_bank!=2||m_ctrl_sa_out_bank!=3||m_ctrl_sa_out_base_addr!=0||m_ctrl_sa_m_size!=1||m_ctrl_sa_n_size!=1||m_ctrl_sa_k_size!=1)$fatal(1,"GEMM control");
      @(negedge aclk);m_ctrl_sa_cmd_ready=1;@(negedge aclk);m_ctrl_sa_cmd_ready=0;
      wait(bank_busy[1]&&bank_busy[2]&&bank_busy[3]);
      if(bank_owner_port[1]!=3||bank_owner_port[2]!=4||bank_owner_port[3]!=5)$fatal(1,"GEMM owners");
      pulse_read_act();pulse_read_wgt();
      @(negedge aclk);sa_out_write_addr=0;sa_out_write_data=OUT_WORD;sa_out_write_strb='1;sa_out_write_valid=1;
      do @(posedge aclk);while(!sa_out_write_ready);@(negedge aclk);sa_out_write_valid=0;
      s_ctrl_sa_done_valid=1;do @(posedge aclk);while(!m_ctrl_sa_done_ready);@(negedge aclk);s_ctrl_sa_done_valid=0;
    end endtask
  task automatic s2mm_transfer;
    logic[71:0]held;logic[3:0]seq;begin wait(m_axis_s2mm_cmd_tvalid);held=m_axis_s2mm_cmd_tdata;
      repeat(2)begin @(posedge aclk);#1;if(!m_axis_s2mm_cmd_tvalid||m_axis_s2mm_cmd_tdata!==held)$fatal(1,"S2MM cmd unstable");end
      if(held[63:32]!==32'h3000)$fatal(1,"S2MM address");seq=held[67:64];
      if(seq==4'd3)$fatal(1,"sequence tag incorrectly equals bank identity");
      @(negedge aclk);m_axis_s2mm_cmd_tready=1;@(negedge aclk);m_axis_s2mm_cmd_tready=0;vendor_s2mm_commands++;
      for(integer j=0;j<16;j++)begin
        wait(m_axis_s2mm_tvalid);if(m_axis_s2mm_tdata!==OUT_WORD[j*64+:64]||m_axis_s2mm_tkeep!==8'hff||m_axis_s2mm_tlast!==(j==15))$fatal(1,"S2MM payload beat %0d",j);
        if(j==3)begin repeat(3)begin @(posedge aclk);#1;if(!m_axis_s2mm_tvalid||m_axis_s2mm_tdata!==OUT_WORD[j*64+:64])$fatal(1,"S2MM backpressure");end end
        @(negedge aclk);m_axis_s2mm_tready=1;@(negedge aclk);m_axis_s2mm_tready=0;
      end
      repeat(2)@(negedge aclk);s_axis_s2mm_sts_tdata={1'b1,3'b000,seq};s_axis_s2mm_sts_tvalid=1;
      do @(posedge aclk);while(!s_axis_s2mm_sts_tready);@(negedge aclk);s_axis_s2mm_sts_tvalid=0;
    end endtask

  initial begin
    for(integer i=0;i<16;i++)OUT_WORD[i*64+:64]=64'h9000000000000000+i;
    for(integer i=0;i<1024;i++)cmd_mem[i]='0;
    reset_dut();
    // Collision behavior is audited from the exact priority logic and its
    // synthesis-time $onehot0 assertion; the legal engine cannot create two
    // simultaneous adapter valids, so this probe stays on legal interfaces.
    cmd_mem[0]=command(1,1,0,0,0,32,32'h1000);
    cmd_mem[1]=command(1,2,0,0,0,16,32'h2000);
    cmd_mem[2]=command(3,1,2,3,(32'(1)<<26)|(32'(1)<<15)|(32'(1)<<3),0,0);
    cmd_mem[3]=command(2,3,0,0,0,128,32'h3000);cmd_mem[4]=command(0,0,0,0,0,0,0);
    start_program();mm2s_transfer(32'h1000,4,A0,A1,A2,A3,0);mm2s_transfer(32'h2000,2,W0,W1,0,0,0);
    gemm_bfm();s2mm_transfer();wait(cmd_dispatcher_done);
    if(vendor_mm2s_commands!=2||vendor_s2mm_commands!=1||bank_write_fires!=3||mm2s_successes!=2||s2mm_successes!=1||(|bank_busy)||bank_subsystem_error)$fatal(1,"main drain/errors");

    // Capacity rejection is local: no vendor command and ownership drains.
    reset_dut();cmd_mem[0]=command(1,1,0,0,32'd65520,32,32'h4000);cmd_mem[1]=command(0,0,0,0,0,0,0);
    start_program();wait(cmd_dispatcher_error);if(cmd_dispatcher_error_code!=8'h06||vendor_mm2s_commands!=0||bank_write_fires!=0||(|bank_busy))$fatal(1,"capacity reject");

    // Transport fault retains head and ownership until coordinated reset.
    reset_dut();cmd_mem[0]=command(1,1,0,0,0,16,32'h5000);cmd_mem[1]=command(0,0,0,0,0,0,0);
    start_program();mm2s_transfer(32'h5000,2,A0,A1,0,0,1);repeat(8)@(negedge aclk);
    if(!mm2s_faulted||!bank_busy[1]||bank_owner_port[1]!=1||cmd_dispatcher_done)$fatal(1,"transport retain");
    @(negedge aclk);aresetn=0;repeat(4)@(negedge aclk);aresetn=1;repeat(4)@(negedge aclk);
    if(|bank_busy)$fatal(1,"reset recovery");
    $display("EXECUTION_FABRIC_SYNC_GAP_PASS cases=3 latency=3 selected_source=checked collision_assertion=static payloads=ACT_WGT_OUT tag_identity=separate unsupported_traffic=none");$finish;
  end
  initial begin #2000000;$fatal(1,"timeout");end
endmodule
