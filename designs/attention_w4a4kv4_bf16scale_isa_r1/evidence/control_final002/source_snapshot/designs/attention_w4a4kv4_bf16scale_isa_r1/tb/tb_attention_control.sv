`timescale 1ns/1ps
module tb_attention_control;
  parameter int CMD_READ_LATENCY=1;
  localparam int CMD_ADDR_WIDTH=3;
  logic  aclk;
  logic  aresetn;
  logic  cmd_dispatcher_start;
  logic  cmd_dispatcher_busy;
  logic  cmd_dispatcher_done;
  logic  cmd_dispatcher_error;
  logic [7:0] cmd_dispatcher_error_code;
  logic [CMD_ADDR_WIDTH-1:0] cmd_dispatcher_current_pc;
  logic  cmd_enb;
  logic [CMD_ADDR_WIDTH-1:0] cmd_addrb;
  logic [127:0] cmd_doutb;
  logic  m_ctrl_mm2s_cmd_valid;
  logic  m_ctrl_mm2s_cmd_ready;
  logic [31:0] m_ctrl_mm2s_cmd_addr;
  logic [22:0] m_ctrl_mm2s_cmd_btt;
  logic [22:0] m_ctrl_mm2s_cmd_offset;
  logic [4:0] m_ctrl_mm2s_cmd_bank;
  logic  m_ctrl_s2mm_cmd_valid;
  logic  m_ctrl_s2mm_cmd_ready;
  logic [31:0] m_ctrl_s2mm_cmd_addr;
  logic [22:0] m_ctrl_s2mm_cmd_btt;
  logic [22:0] m_ctrl_s2mm_cmd_offset;
  logic [4:0] m_ctrl_s2mm_cmd_bank;
  logic  s_ctrl_mm2s_sts_valid;
  logic  m_ctrl_mm2s_sts_ready;
  logic [4:0] s_ctrl_mm2s_sts_bank;
  logic  s_ctrl_mm2s_sts_error;
  logic  s_ctrl_mm2s_faulted;
  logic  s_ctrl_s2mm_sts_valid;
  logic  m_ctrl_s2mm_sts_ready;
  logic [4:0] s_ctrl_s2mm_sts_bank;
  logic  s_ctrl_s2mm_sts_error;
  logic  s_ctrl_s2mm_faulted;
  logic  compute_cmd_valid;
  logic  compute_cmd_ready;
  logic [15:0] compute_cmd_id;
  logic [7:0] compute_cmd_opcode;
  logic [4:0] compute_cmd_src0;
  logic [4:0] compute_cmd_src1;
  logic [4:0] compute_cmd_dst;
  logic [255:0] compute_cmd_src0_desc;
  logic [255:0] compute_cmd_src1_desc;
  logic [255:0] compute_cmd_dst_desc;
  logic  compute_resp_valid;
  logic  compute_resp_ready;
  logic [15:0] compute_resp_id;
  logic  compute_resp_error;
  logic [7:0] compute_resp_error_code;
  logic  desc_lookup_valid;
  logic [4:0] desc_dst_bank;
  logic [4:0] desc_src0_bank;
  logic [4:0] desc_src1_bank;
  logic  desc_resp_valid;
  logic [255:0] desc_dst;
  logic [255:0] desc_src0;
  logic [255:0] desc_src1;
  logic [18:0] bank_acquire_valid;
  logic [18:0] bank_release_valid;
  logic [18:0][2:0] bank_acquire_port;
  logic [18:0][2:0] bank_release_port;
  logic [18:0] bank_busy;
  logic [18:0][2:0] bank_owner_port;
  logic [18:0] bank_acquire_accepted;
  logic [18:0] bank_release_accepted;
  logic  bank_error;
  logic [18:0] bank_valid;
  logic  mm2s_write_valid;
  logic  mm2s_write_ready;
  logic [4:0] mm2s_write_bank;
  logic [31:0] mm2s_write_addr;
  logic [127:0] mm2s_write_data;
  logic [15:0] mm2s_write_strb;
  logic  s2mm_read_valid;
  logic  s2mm_read_ready;
  logic [4:0] s2mm_read_bank;
  logic [31:0] s2mm_read_addr;
  logic  s2mm_rsp_valid;
  logic [4:0] s2mm_rsp_bank;
  logic [127:0] s2mm_rsp_data;
  logic  src0_read_valid;
  logic  src0_read_ready;
  logic [4:0] src0_read_bank;
  logic [31:0] src0_read_addr;
  logic  src0_rsp_valid;
  logic [4:0] src0_rsp_bank;
  logic [127:0] src0_rsp_data;
  logic  src1_read_valid;
  logic  src1_read_ready;
  logic [4:0] src1_read_bank;
  logic [31:0] src1_read_addr;
  logic  src1_rsp_valid;
  logic [4:0] src1_rsp_bank;
  logic [127:0] src1_rsp_data;
  logic  dst_write_valid;
  logic  dst_write_ready;
  logic [4:0] dst_write_bank;
  logic [31:0] dst_write_addr;
  logic [127:0] dst_write_data;
  logic [15:0] dst_write_strb;
  logic [5:0] ctx_tokens;
  logic [5:0] ctx_query_count;
  logic [2:0] ctx_heads;
  logic [6:0] ctx_head_dim;
  logic  ctx_causal;
  logic [31:0] ctx_qk_factor;
  logic [4:0] query_index;
  logic [4:0] query_value;
  attention_tensor_controller #(.CMD_ADDR_WIDTH(3),.MAX_COMMANDS(8),.CMD_READ_LATENCY(CMD_READ_LATENCY)) u_controller (
    .aclk(aclk),
    .aresetn(aresetn),
    .cmd_dispatcher_start(cmd_dispatcher_start),
    .cmd_dispatcher_busy(cmd_dispatcher_busy),
    .cmd_dispatcher_done(cmd_dispatcher_done),
    .cmd_dispatcher_error(cmd_dispatcher_error),
    .cmd_dispatcher_error_code(cmd_dispatcher_error_code),
    .cmd_dispatcher_current_pc(cmd_dispatcher_current_pc),
    .cmd_enb(cmd_enb),
    .cmd_addrb(cmd_addrb),
    .cmd_doutb(cmd_doutb),
    .m_ctrl_mm2s_cmd_valid(m_ctrl_mm2s_cmd_valid),
    .m_ctrl_mm2s_cmd_ready(m_ctrl_mm2s_cmd_ready),
    .m_ctrl_mm2s_cmd_addr(m_ctrl_mm2s_cmd_addr),
    .m_ctrl_mm2s_cmd_btt(m_ctrl_mm2s_cmd_btt),
    .m_ctrl_mm2s_cmd_offset(m_ctrl_mm2s_cmd_offset),
    .m_ctrl_mm2s_cmd_bank(m_ctrl_mm2s_cmd_bank),
    .m_ctrl_s2mm_cmd_valid(m_ctrl_s2mm_cmd_valid),
    .m_ctrl_s2mm_cmd_ready(m_ctrl_s2mm_cmd_ready),
    .m_ctrl_s2mm_cmd_addr(m_ctrl_s2mm_cmd_addr),
    .m_ctrl_s2mm_cmd_btt(m_ctrl_s2mm_cmd_btt),
    .m_ctrl_s2mm_cmd_offset(m_ctrl_s2mm_cmd_offset),
    .m_ctrl_s2mm_cmd_bank(m_ctrl_s2mm_cmd_bank),
    .s_ctrl_mm2s_sts_valid(s_ctrl_mm2s_sts_valid),
    .m_ctrl_mm2s_sts_ready(m_ctrl_mm2s_sts_ready),
    .s_ctrl_mm2s_sts_bank(s_ctrl_mm2s_sts_bank),
    .s_ctrl_mm2s_sts_error(s_ctrl_mm2s_sts_error),
    .s_ctrl_mm2s_faulted(s_ctrl_mm2s_faulted),
    .s_ctrl_s2mm_sts_valid(s_ctrl_s2mm_sts_valid),
    .m_ctrl_s2mm_sts_ready(m_ctrl_s2mm_sts_ready),
    .s_ctrl_s2mm_sts_bank(s_ctrl_s2mm_sts_bank),
    .s_ctrl_s2mm_sts_error(s_ctrl_s2mm_sts_error),
    .s_ctrl_s2mm_faulted(s_ctrl_s2mm_faulted),
    .compute_cmd_valid(compute_cmd_valid),
    .compute_cmd_ready(compute_cmd_ready),
    .compute_cmd_id(compute_cmd_id),
    .compute_cmd_opcode(compute_cmd_opcode),
    .compute_cmd_src0(compute_cmd_src0),
    .compute_cmd_src1(compute_cmd_src1),
    .compute_cmd_dst(compute_cmd_dst),
    .compute_cmd_src0_desc(compute_cmd_src0_desc),
    .compute_cmd_src1_desc(compute_cmd_src1_desc),
    .compute_cmd_dst_desc(compute_cmd_dst_desc),
    .compute_resp_valid(compute_resp_valid),
    .compute_resp_ready(compute_resp_ready),
    .compute_resp_id(compute_resp_id),
    .compute_resp_error(compute_resp_error),
    .compute_resp_error_code(compute_resp_error_code),
    .desc_lookup_valid(desc_lookup_valid),
    .desc_dst_bank(desc_dst_bank),
    .desc_src0_bank(desc_src0_bank),
    .desc_src1_bank(desc_src1_bank),
    .desc_resp_valid(desc_resp_valid),
    .desc_dst(desc_dst),
    .desc_src0(desc_src0),
    .desc_src1(desc_src1),
    .bank_acquire_valid(bank_acquire_valid),
    .bank_release_valid(bank_release_valid),
    .bank_acquire_port(bank_acquire_port),
    .bank_release_port(bank_release_port),
    .bank_busy(bank_busy),
    .bank_owner_port(bank_owner_port),
    .bank_acquire_accepted(bank_acquire_accepted),
    .bank_release_accepted(bank_release_accepted),
    .bank_error(bank_error),
    .bank_valid(bank_valid)
  );
  attention_descriptor_rom u_descriptors (
    .aclk(aclk),
    .aresetn(aresetn),
    .desc_lookup_valid(desc_lookup_valid),
    .desc_dst_bank(desc_dst_bank),
    .desc_src0_bank(desc_src0_bank),
    .desc_src1_bank(desc_src1_bank),
    .desc_resp_valid(desc_resp_valid),
    .desc_dst(desc_dst),
    .desc_src0(desc_src0),
    .desc_src1(desc_src1),
    .ctx_tokens(ctx_tokens),
    .ctx_query_count(ctx_query_count),
    .ctx_heads(ctx_heads),
    .ctx_head_dim(ctx_head_dim),
    .ctx_causal(ctx_causal),
    .ctx_qk_factor(ctx_qk_factor),
    .query_index(query_index),
    .query_value(query_value)
  );
  attention_tensor_bank_subsystem u_banks (
    .aclk(aclk),
    .aresetn(aresetn),
    .bank_acquire_valid(bank_acquire_valid),
    .bank_release_valid(bank_release_valid),
    .bank_acquire_port(bank_acquire_port),
    .bank_release_port(bank_release_port),
    .bank_busy(bank_busy),
    .bank_owner_port(bank_owner_port),
    .bank_acquire_accepted(bank_acquire_accepted),
    .bank_release_accepted(bank_release_accepted),
    .bank_error(bank_error),
    .mm2s_write_valid(mm2s_write_valid),
    .mm2s_write_ready(mm2s_write_ready),
    .mm2s_write_bank(mm2s_write_bank),
    .mm2s_write_addr(mm2s_write_addr),
    .mm2s_write_data(mm2s_write_data),
    .mm2s_write_strb(mm2s_write_strb),
    .s2mm_read_valid(s2mm_read_valid),
    .s2mm_read_ready(s2mm_read_ready),
    .s2mm_read_bank(s2mm_read_bank),
    .s2mm_read_addr(s2mm_read_addr),
    .s2mm_rsp_valid(s2mm_rsp_valid),
    .s2mm_rsp_bank(s2mm_rsp_bank),
    .s2mm_rsp_data(s2mm_rsp_data),
    .src0_read_valid(src0_read_valid),
    .src0_read_ready(src0_read_ready),
    .src0_read_bank(src0_read_bank),
    .src0_read_addr(src0_read_addr),
    .src0_rsp_valid(src0_rsp_valid),
    .src0_rsp_bank(src0_rsp_bank),
    .src0_rsp_data(src0_rsp_data),
    .src1_read_valid(src1_read_valid),
    .src1_read_ready(src1_read_ready),
    .src1_read_bank(src1_read_bank),
    .src1_read_addr(src1_read_addr),
    .src1_rsp_valid(src1_rsp_valid),
    .src1_rsp_bank(src1_rsp_bank),
    .src1_rsp_data(src1_rsp_data),
    .dst_write_valid(dst_write_valid),
    .dst_write_ready(dst_write_ready),
    .dst_write_bank(dst_write_bank),
    .dst_write_addr(dst_write_addr),
    .dst_write_data(dst_write_data),
    .dst_write_strb(dst_write_strb)
  );
  logic [127:0] program_mem[0:7];
  logic [127:0] cmd_pipe[0:CMD_READ_LATENCY-1];
  int cases=0,acquires=0,releases=0;
  initial aclk=0;
  always #2.5 aclk=~aclk;
  assign cmd_doutb=cmd_pipe[CMD_READ_LATENCY-1];
  always @(posedge aclk) begin
    if(cmd_enb) cmd_pipe[0]<=program_mem[cmd_addrb];
    for(int i=1;i<CMD_READ_LATENCY;i++) cmd_pipe[i]<=cmd_pipe[i-1];
    if(aresetn && |bank_acquire_valid) begin
      if(bank_acquire_accepted!=bank_acquire_valid) $fatal(1,"partial acquisition");
      if(!(m_ctrl_mm2s_cmd_valid&&m_ctrl_mm2s_cmd_ready || m_ctrl_s2mm_cmd_valid&&m_ctrl_s2mm_cmd_ready || compute_cmd_valid&&compute_cmd_ready)) $fatal(1,"acquisition without command handshake");
      acquires++;
    end
    if(aresetn && |bank_release_valid) begin
      if(bank_release_accepted!=bank_release_valid) $fatal(1,"partial release");
      releases++;
    end
  end
  function automatic logic[127:0] instruction(input logic[7:0] op,d,a,b,input logic[31:0] descriptor,input logic[63:0] imm);
    return {op,d,a,b,descriptor,imm};
  endfunction
  task automatic tick; @(posedge aclk); #1; endtask
  task automatic reset;
    @(negedge aclk); aresetn=0;cmd_dispatcher_start=0;
    m_ctrl_mm2s_cmd_ready=0;m_ctrl_s2mm_cmd_ready=0;compute_cmd_ready=0;
    s_ctrl_mm2s_sts_valid=0;s_ctrl_s2mm_sts_valid=0;compute_resp_valid=0;
    s_ctrl_mm2s_sts_bank=0;s_ctrl_s2mm_sts_bank=0;compute_resp_id=0;
    s_ctrl_mm2s_sts_error=0;s_ctrl_s2mm_sts_error=0;compute_resp_error=0;compute_resp_error_code=0;
    s_ctrl_mm2s_faulted=0;s_ctrl_s2mm_faulted=0;
    mm2s_write_valid=0;mm2s_write_bank=0;mm2s_write_addr=0;mm2s_write_data=0;mm2s_write_strb='1;
    s2mm_read_valid=0;s2mm_read_bank=0;s2mm_read_addr=0;
    src0_read_valid=0;src0_read_bank=0;src0_read_addr=0;
    src1_read_valid=0;src1_read_bank=0;src1_read_addr=0;
    dst_write_valid=0;dst_write_bank=0;dst_write_addr=0;dst_write_data=0;dst_write_strb='1;query_index=0;
    for(int i=0;i<8;i++) begin program_mem[i]=0; end
    repeat(3) tick(); @(negedge aclk); aresetn=1;
    tick(); if(bank_busy!=0 || bank_valid!=0 || bank_error || cmd_dispatcher_error) $fatal(1,"reset did not clear state");
  endtask
  task automatic start;
    @(negedge aclk);cmd_dispatcher_start=1;tick();@(negedge aclk);cmd_dispatcher_start=0;
  endtask
  task automatic wait_mm2s;
    for(int i=0;i<200;i++) begin @(negedge aclk);if(m_ctrl_mm2s_cmd_valid) return;end
    $fatal(1,"no MM2S command");
  endtask
  task automatic wait_compute;
    for(int i=0;i<200;i++) begin @(negedge aclk);if(compute_cmd_valid) return;end
    $fatal(1,"no compute command");
  endtask
  task automatic wait_error(input logic[7:0] code);
    for(int i=0;i<200;i++) begin tick(); if(cmd_dispatcher_error && !cmd_dispatcher_busy) begin
      if(cmd_dispatcher_error_code!=code) $fatal(1,"wrong error got%0d expected%0d",cmd_dispatcher_error_code,code);
      cases++;return;
    end end
    $fatal(1,"no error completion code%0d state%0d",code,u_controller.state_r);
  endtask
  task automatic wait_done;
    for(int i=0;i<200;i++) begin tick();if(cmd_dispatcher_done) begin
      if(cmd_dispatcher_error || bank_busy!=0 || bank_error) $fatal(1,"bad normal done");cases++;return;
    end end
    $fatal(1,"no END done");
  endtask
  task automatic load_bank(input logic[4:0] bank,input logic[127:0] payload,input bit error_completion);
    wait_mm2s();
    if(m_ctrl_mm2s_cmd_bank!=bank || m_ctrl_mm2s_cmd_offset!=0 || m_ctrl_mm2s_cmd_btt!=attention_tensor_config_pkg::capacity_words(bank)*16) $fatal(1,"DMA descriptor payload");
    repeat(4) begin tick();if(!m_ctrl_mm2s_cmd_valid || m_ctrl_mm2s_cmd_bank!=bank || bank_busy!=0) $fatal(1,"stalled command changed or acquired early");end
    @(negedge aclk);m_ctrl_mm2s_cmd_ready=1;tick();@(negedge aclk);m_ctrl_mm2s_cmd_ready=0;
    if(!bank_busy[bank] || bank_owner_port[bank]!=1 || bank_valid[bank]) $fatal(1,"DMA acquire state");
    if(!error_completion) begin
      for(int w=0;w<int'(attention_tensor_config_pkg::capacity_words(bank));w++) begin
        mm2s_write_valid=1;mm2s_write_bank=bank;mm2s_write_addr=32'(w);mm2s_write_data=payload;
        if(!mm2s_write_ready) begin #0.1; if(!mm2s_write_ready) $fatal(1,"native DMA write notready");end
        tick();@(negedge aclk);
      end
      mm2s_write_valid=0;
    end
    s_ctrl_mm2s_sts_valid=1;s_ctrl_mm2s_sts_bank=bank;s_ctrl_mm2s_sts_error=error_completion;
    tick();@(negedge aclk);s_ctrl_mm2s_sts_valid=0;s_ctrl_mm2s_sts_error=0;
    tick();if(bank_busy[bank]) $fatal(1,"normal DMA did not release");
    if(bank_valid[bank]==error_completion) $fatal(1,"DMA commit status");
  endtask
  task automatic perform_compute(input bit clean_error,input bit wrong_id,input bit duplicate);
    logic[15:0] id; logic[4:0] source,dest;
    wait_compute();id=compute_cmd_id;source=compute_cmd_src0;dest=compute_cmd_dst;
    repeat(4) begin tick();if(!compute_cmd_valid || compute_cmd_id!=id || bank_busy!=0) $fatal(1,"compute stall stability");end
    @(negedge aclk);compute_cmd_ready=1;tick();@(negedge aclk);compute_cmd_ready=0;
    if(!bank_busy[source] || !bank_busy[dest] || bank_owner_port[source]!=3 || bank_owner_port[dest]!=5 || bank_valid[dest]) $fatal(1,"compute acquisition");
    src0_read_valid=1;src0_read_bank=source;src0_read_addr=0;
    #0.1;if(!src0_read_ready) $fatal(1,"source native read notready");
    tick();@(negedge aclk);src0_read_valid=0;
    repeat(1) begin tick();if(src0_rsp_valid) $fatal(1,"early native response");end
    tick();if(!src0_rsp_valid || src0_rsp_bank!=source || src0_rsp_data!=128'hfedcba98765432100123456789abcdef) $fatal(1,"native source response payload/latency");
    @(negedge aclk);
    begin
      // Clean completion error may follow partial destination writes; never commit.
      dst_write_valid=1;dst_write_bank=dest;dst_write_addr=0;dst_write_data=128'h0123456789abcdef0011223344556677;
      #0.1;if(!dst_write_ready) $fatal(1,"destination native write notready");tick();@(negedge aclk);dst_write_valid=0;
    end
    compute_resp_valid=1;compute_resp_id=wrong_id ? id+16'd1 : id;compute_resp_error=clean_error;compute_resp_error_code=clean_error ? 8'd70 : 0;
    tick();@(negedge aclk);if(!duplicate) compute_resp_valid=0;
    tick();@(negedge aclk);compute_resp_valid=0;
  endtask
  task automatic negative(input logic[127:0] cmd,input logic[7:0] code);
    reset();program_mem[0]=cmd;start();wait_error(code);if(bank_busy!=0 || bank_valid!=0) $fatal(1,"invalid command touched banks");
  endtask
  initial begin
    aresetn=0;
    reset();program_mem[0]=instruction(1,0,0,0,0,64'h10000000);program_mem[1]=instruction(1,18,0,0,18,64'h10001000);
    program_mem[2]=instruction(3,6,0,0,6,0);program_mem[3]=instruction(2,0,6,0,6,64'h10002000);start();
    load_bank(0,128'hfedcba98765432100123456789abcdef,0);
    load_bank(18,128'h777788889999aaaa2222333344445555,0);
    perform_compute(0,0,0);
    for(int i=0;i<200;i++) begin @(negedge aclk);if(m_ctrl_s2mm_cmd_valid) break;if(i==199) $fatal(1,"no S2MM");end
    if(m_ctrl_s2mm_cmd_bank!=6 || m_ctrl_s2mm_cmd_btt!=80) $fatal(1,"S2MM descriptor");
    m_ctrl_s2mm_cmd_ready=1;tick();@(negedge aclk);m_ctrl_s2mm_cmd_ready=0;
    s2mm_read_valid=1;s2mm_read_bank=6;s2mm_read_addr=0;#0.1;if(!s2mm_read_ready) $fatal(1,"S2MM notready");tick();@(negedge aclk);s2mm_read_valid=0;
    repeat(1) tick();tick();if(!s2mm_rsp_valid || s2mm_rsp_bank!=6 || s2mm_rsp_data!=128'h0123456789abcdef0011223344556677) $fatal(1,"S2MM payload");
    @(negedge aclk);s_ctrl_s2mm_sts_valid=1;s_ctrl_s2mm_sts_bank=6;tick();@(negedge aclk);s_ctrl_s2mm_sts_valid=0;wait_done();
    if(!bank_valid[18] || !bank_valid[6]) $fatal(1,"highbank validity");
    negative(instruction(8,0,0,0,0,0),1);
    negative(instruction(1,32,0,0,32,64'h10000000),2);
    negative(instruction(1,0,0,0,19,64'h10000000),2);
    negative(instruction(1,0,0,0,0,64'h110000000),2);
    negative(instruction(1,0,0,0,0,64'h10000001),2);
    negative(instruction(1,0,0,0,0,64'hfffffff0),3);
    negative(instruction(3,6,0,1,6,0),2);
    negative(instruction(3,0,0,0,0,0),2);
    negative(instruction(3,6,0,0,6,1),2);
    negative(instruction(3,6,0,0,6,0),4);
    negative(instruction(3,5,0,0,5,0),3);
    negative(instruction(2,0,18,0,18,64'h10000000),4);
    negative(instruction(0,1,0,0,0,0),2);
    // Quiescent errors release ownership but do not commit destination.
    reset();program_mem[0]=instruction(1,0,0,0,0,64'h10000000);start();load_bank(0,0,1);wait_error(6);if(bank_busy!=0 || bank_valid!=0) $fatal(1,"error DMA cleanup");
    reset();program_mem[0]=instruction(1,0,0,0,0,64'h10000000);program_mem[1]=instruction(3,6,0,0,6,0);start();load_bank(0,128'hfedcba98765432100123456789abcdef,0);perform_compute(1,0,0);wait_error(70);if(bank_busy!=0 || bank_valid[6]) $fatal(1,"clean error compute cleanup");
    // Wrong identity and duplicate buffered completion retain saved ownership.
    reset();program_mem[0]=instruction(1,0,0,0,0,64'h10000000);program_mem[1]=instruction(3,6,0,0,6,0);start();load_bank(0,128'hfedcba98765432100123456789abcdef,0);perform_compute(0,1,0);wait_error(5);if(bank_busy!=19'h41 || bank_valid[6]) $fatal(1,"wrongid ownership retention");
    reset();program_mem[0]=instruction(1,0,0,0,0,64'h10000000);program_mem[1]=instruction(3,6,0,0,6,0);start();load_bank(0,128'hfedcba98765432100123456789abcdef,0);perform_compute(0,0,1);wait_error(5);if(bank_busy!=19'h41 || bank_valid[6]) $fatal(1,"duplicate ownership retention");
    reset();program_mem[0]=instruction(1,0,0,0,0,64'h10000000);start();wait_mm2s();m_ctrl_mm2s_cmd_ready=1;tick();@(negedge aclk);m_ctrl_mm2s_cmd_ready=0;s_ctrl_mm2s_sts_valid=1;s_ctrl_mm2s_sts_bank=16;tick();@(negedge aclk);s_ctrl_mm2s_sts_valid=0;wait_error(5);if(bank_busy!=1 || bank_valid!=0) $fatal(1,"fivebit DMA identity");
    // Fault during valid stall cannot retract command; accepting it retains owner.
    reset();program_mem[0]=instruction(1,18,0,0,18,64'h10000000);start();wait_mm2s();s_ctrl_mm2s_faulted=1;repeat(3) begin tick();if(!m_ctrl_mm2s_cmd_valid || m_ctrl_mm2s_cmd_bank!=18) $fatal(1,"fault retracted stalled command");end
    @(negedge aclk);m_ctrl_mm2s_cmd_ready=1;tick();@(negedge aclk);m_ctrl_mm2s_cmd_ready=0;wait_error(5);if(!bank_busy[18]) $fatal(1,"unclean fault released ownership");
    // Exactly-once zero-cycle completion is accepted prospectively, released later.
    reset();program_mem[0]=instruction(1,18,0,0,18,64'h10000000);start();wait_mm2s();m_ctrl_mm2s_cmd_ready=1;s_ctrl_mm2s_sts_valid=1;s_ctrl_mm2s_sts_bank=18;s_ctrl_mm2s_sts_error=1;tick();@(negedge aclk);m_ctrl_mm2s_cmd_ready=0;s_ctrl_mm2s_sts_valid=0;wait_error(6);if(bank_busy!=0 || bank_valid!=0) $fatal(1,"zero-cycle cleanerror cleanup");
    // Missing END reaches the configured bound without PC wrap.
    reset();for(int i=0;i<8;i++) program_mem[i]=instruction(1,0,0,0,0,64'h10000000);start();for(int i=0;i<8;i++) load_bank(0,128'hfedcba98765432100123456789abcdef,0);wait_error(9);if(cmd_dispatcher_current_pc!=7) $fatal(1,"PC wrap");
    // Source1 native route, payload and exclusive role use a PROJECT mock.
    reset();program_mem[0]=instruction(1,6,0,0,6,64'h10000000);program_mem[1]=instruction(1,1,0,0,1,64'h10001000);program_mem[2]=instruction(4,7,6,1,7,0);start();
    load_bank(6,128'h11112222333344445555666677778888,0);load_bank(1,128'h88887777666655554444333322221111,0);wait_compute();compute_cmd_ready=1;tick();@(negedge aclk);compute_cmd_ready=0;
    if(bank_owner_port[1]!=4 || bank_owner_port[6]!=3 || bank_owner_port[7]!=5) $fatal(1,"threebank roles");
    src1_read_valid=1;src1_read_bank=1;src1_read_addr=0;tick();@(negedge aclk);src1_read_valid=0;repeat(1) tick();tick();if(!src1_rsp_valid || src1_rsp_bank!=1 || src1_rsp_data!=128'h88887777666655554444333322221111) $fatal(1,"source1 native response");
    @(negedge aclk);compute_resp_valid=1;compute_resp_id=compute_cmd_id;tick();@(negedge aclk);compute_resp_valid=0;wait_done();
    // Illegal descriptor-range access is blocked physically, faults, and retains ownership.
    reset();program_mem[0]=instruction(1,18,0,0,18,64'h10000000);start();wait_mm2s();m_ctrl_mm2s_cmd_ready=1;tick();@(negedge aclk);m_ctrl_mm2s_cmd_ready=0;
    mm2s_write_valid=1;mm2s_write_bank=18;mm2s_write_addr=attention_tensor_config_pkg::capacity_words(18);mm2s_write_data='1;
    #0.1;if(mm2s_write_ready || u_banks.mem_ena[18]) $fatal(1,"logical range access was accepted");tick();@(negedge aclk);mm2s_write_valid=0;wait_error(7);if(!bank_busy[18] || bank_valid[18]) $fatal(1,"rangefault retention");
    // Unauthorized role/bank traffic cannot touch an unrelated bank.
    reset();program_mem[0]=instruction(1,18,0,0,18,64'h10000000);start();wait_mm2s();m_ctrl_mm2s_cmd_ready=1;tick();@(negedge aclk);m_ctrl_mm2s_cmd_ready=0;
    mm2s_write_valid=1;mm2s_write_bank=17;mm2s_write_addr=0;mm2s_write_data='1;
    #0.1;if(mm2s_write_ready || u_banks.mem_ena[17]) $fatal(1,"unauthorized bank access accepted");tick();@(negedge aclk);mm2s_write_valid=0;wait_error(7);if(bank_busy!=19'h40000 || bank_valid!=0) $fatal(1,"ownerfault retention");
    // S2MM extent is validated after source initialization and before acquisition.
    reset();program_mem[0]=instruction(1,0,0,0,0,64'h10000000);program_mem[1]=instruction(2,0,0,0,0,64'hfffffff0);start();load_bank(0,128'hfedcba98765432100123456789abcdef,0);wait_error(3);if(bank_busy!=0) $fatal(1,"S2MM wrap acquired bank");
    // An exact exclusive end at2^32 is legal (bank0 capacity400=0x190).
    reset();program_mem[0]=instruction(1,0,0,0,0,64'hfffffe70);start();load_bank(0,128'hfedcba98765432100123456789abcdef,0);wait_done();
    // Asserting reset gates request acceptance before the resetting clock edge.
    reset();program_mem[0]=instruction(1,18,0,0,18,64'h10000000);start();wait_mm2s();m_ctrl_mm2s_cmd_ready=1;tick();@(negedge aclk);m_ctrl_mm2s_cmd_ready=0;
    mm2s_write_valid=1;mm2s_write_bank=18;mm2s_write_addr=0;mm2s_write_data='1;#0.1;if(!mm2s_write_ready) $fatal(1,"pre-reset ready");
    aresetn=0;#0.1;if(mm2s_write_ready || u_banks.mem_ena[18]) $fatal(1,"reset allowed physical write");tick();@(negedge aclk);mm2s_write_valid=0;aresetn=1;tick();if(bank_busy!=0 || bank_valid!=0 || bank_error) $fatal(1,"mid-flight reset state");cases++;
    reset();cases++;
    $display("CONTROL_CASES=%0d acquires=%0d releases=%0d",cases,acquires,releases);
    $display("ATTENTION_CONTROL_XSIM_PASS");
    $finish;
  end
  initial begin #1000000;$fatal(1,"control timeout state%0d pc%0d",u_controller.state_r,cmd_dispatcher_current_pc);end
endmodule
