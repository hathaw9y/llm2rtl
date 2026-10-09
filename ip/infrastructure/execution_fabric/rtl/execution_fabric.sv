`timescale 1ns/1ps

module execution_fabric (
  input logic aclk,input logic aresetn,
  input logic cmd_dispatcher_start,output logic cmd_dispatcher_busy,
  output logic cmd_dispatcher_done,output logic cmd_dispatcher_error,
  output logic[7:0]cmd_dispatcher_error_code,output logic[9:0]current_pc,
  output logic cmd_enb,output logic[9:0]cmd_addrb,input logic[127:0]cmd_doutb,

  input logic mm2s_pause,input logic mm2s_abort,input logic s2mm_pause,input logic s2mm_abort,
  output logic mm2s_faulted,output logic[3:0]mm2s_sequence_tag,
  output logic[3:0]mm2s_received_tag,output logic[7:0]mm2s_raw_status,
  output logic mm2s_completion_valid,output logic mm2s_completion_error,
  output logic[7:0]mm2s_completion_error_code,output logic[3:0]mm2s_completion_bank,
  output logic s2mm_faulted,output logic[3:0]s2mm_sequence_tag,
  output logic[3:0]s2mm_received_tag,output logic[7:0]s2mm_raw_status,
  output logic s2mm_completion_valid,output logic s2mm_completion_error,
  output logic[7:0]s2mm_completion_error_code,output logic[3:0]s2mm_completion_bank,

  output logic[71:0]m_axis_mm2s_cmd_tdata,output logic m_axis_mm2s_cmd_tvalid,
  input logic m_axis_mm2s_cmd_tready,input logic[63:0]s_axis_mm2s_tdata,
  input logic[7:0]s_axis_mm2s_tkeep,input logic s_axis_mm2s_tvalid,
  output logic s_axis_mm2s_tready,input logic s_axis_mm2s_tlast,
  input logic[7:0]s_axis_mm2s_sts_tdata,input logic s_axis_mm2s_sts_tkeep,
  input logic s_axis_mm2s_sts_tvalid,output logic s_axis_mm2s_sts_tready,
  input logic s_axis_mm2s_sts_tlast,
  output logic[71:0]m_axis_s2mm_cmd_tdata,output logic m_axis_s2mm_cmd_tvalid,
  input logic m_axis_s2mm_cmd_tready,output logic[63:0]m_axis_s2mm_tdata,
  output logic[7:0]m_axis_s2mm_tkeep,output logic m_axis_s2mm_tvalid,
  input logic m_axis_s2mm_tready,output logic m_axis_s2mm_tlast,
  input logic[7:0]s_axis_s2mm_sts_tdata,input logic s_axis_s2mm_sts_tkeep,
  input logic s_axis_s2mm_sts_tvalid,output logic s_axis_s2mm_sts_tready,
  input logic s_axis_s2mm_sts_tlast,

  output logic m_ctrl_sa_cmd_valid,input logic m_ctrl_sa_cmd_ready,
  output logic[5:0]m_ctrl_sa_m_size,output logic[10:0]m_ctrl_sa_n_size,
  output logic[11:0]m_ctrl_sa_k_size,output logic[3:0]m_ctrl_sa_act_bank,
  output logic[3:0]m_ctrl_sa_wgt_bank,output logic[3:0]m_ctrl_sa_out_bank,
  output logic[31:0]m_ctrl_sa_out_base_addr,input logic s_ctrl_sa_done_valid,
  output logic m_ctrl_sa_done_ready,input logic s_ctrl_sa_done_error,
  input logic[3:0]s_ctrl_sa_act_bank,input logic[3:0]s_ctrl_sa_wgt_bank,
  input logic[3:0]s_ctrl_sa_out_bank,

  input logic sa_act_read_valid,output logic sa_act_read_ready,input logic[31:0]sa_act_read_addr,
  output logic sa_act_rsp_valid,output logic[255:0]sa_act_rsp_data,
  input logic sa_wgt_read_valid,output logic sa_wgt_read_ready,input logic[31:0]sa_wgt_read_addr,
  output logic sa_wgt_rsp_valid,output logic[127:0]sa_wgt_rsp_data,
  input logic sa_out_read_valid,output logic sa_out_read_ready,input logic[31:0]sa_out_read_addr,
  output logic sa_out_rsp_valid,output logic[1023:0]sa_out_rsp_data,
  input logic sa_out_write_valid,output logic sa_out_write_ready,input logic[31:0]sa_out_write_addr,
  input logic[127:0]sa_out_write_strb,input logic[1023:0]sa_out_write_data,

  output logic[0:15]bank_busy,output logic[0:15][2:0]bank_owner_port,
  output logic bank_subsystem_error,output logic[2:0]bank_subsystem_error_code,
  output logic ownership_error,output logic[2:0]ownership_error_code,
  output logic router_error,output logic[2:0]router_error_code
);
  localparam logic[16*32-1:0]BANK_WORD_BYTES={{12{32'd1}},32'd128,32'd16,32'd16,32'd16};
  localparam logic[16*32-1:0]BANK_CAPACITY_BYTES={{12{32'd1}},32'd131072,32'd1048576,32'd65536,32'd32768};
  logic d_mm2s_valid,d_mm2s_ready,d_s2mm_valid,d_s2mm_ready;
  logic[31:0]d_mm2s_addr,d_s2mm_addr,d_mm2s_offset,d_s2mm_offset;
  logic[22:0]d_mm2s_btt,d_s2mm_btt;logic[3:0]d_mm2s_bank,d_s2mm_bank;
  logic[3:0]unused_mm2s_bank_tag,unused_s2mm_bank_tag;
  logic e_mm2s_sts_valid,e_mm2s_sts_ready,e_mm2s_sts_error;
  logic e_s2mm_sts_valid,e_s2mm_sts_ready,e_s2mm_sts_error;
  logic[7:0]e_mm2s_sts_code,e_s2mm_sts_code;logic[3:0]e_mm2s_sts_bank,e_s2mm_sts_bank;
  logic[0:15]acquire_valid,release_valid;logic[0:15][2:0]acquire_port,release_port;

  logic wr_req[16],wr_grant[16],mm_start[16],mm_done[16],mm_abort_bank[16];
  logic[22:0]mm_offset[16];logic[63:0]mm_data[16];logic[7:0]mm_keep[16];
  logic mm_valid[16],mm_ready[16],mm_last[16];
  logic rd_req[16],rd_grant[16],s2_start[16],s2_done[16],s2_abort_bank[16];
  logic[22:0]s2_btt[16],s2_offset[16];logic[63:0]s2_data[16];logic[7:0]s2_keep[16];
  logic s2_valid[16],s2_ready[16],s2_last[16];

  logic a_wr_valid[0:2],a_wr_ready[0:2];logic[3:0]a_wr_bank[0:2];
  logic[31:0]a_wr_addr[0:2];logic[15:0]a_wr_strb[0:2];logic[127:0]a_wr_data[0:2];
  logic bs_mm_valid,bs_mm_ready;logic[3:0]bs_mm_bank;logic[31:0]bs_mm_addr;
  logic[15:0]bs_mm_strb;logic[127:0]bs_mm_data;
  logic bs_s2_read_valid,bs_s2_read_ready,bs_s2_rsp_valid;logic[31:0]bs_s2_read_addr;
  logic[1023:0]bs_s2_rsp_data;
  logic mm_sel0_w,mm_sel1_w,mm_sel2_w;
  assign mm_sel0_w=a_wr_valid[0];
  assign mm_sel1_w=!a_wr_valid[0]&&a_wr_valid[1];
  assign mm_sel2_w=!a_wr_valid[0]&&!a_wr_valid[1]&&a_wr_valid[2];
  assign a_wr_ready[0]=mm_sel0_w&&bs_mm_ready;
  assign a_wr_ready[1]=mm_sel1_w&&bs_mm_ready;
  assign a_wr_ready[2]=mm_sel2_w&&bs_mm_ready;
  assign mm2s_completion_valid=e_mm2s_sts_valid;
  assign mm2s_completion_error=e_mm2s_sts_error;
  assign mm2s_completion_error_code=e_mm2s_sts_code;
  assign mm2s_completion_bank=e_mm2s_sts_bank;
  assign s2mm_completion_valid=e_s2mm_sts_valid;
  assign s2mm_completion_error=e_s2mm_sts_error;
  assign s2mm_completion_error_code=e_s2mm_sts_code;
  assign s2mm_completion_bank=e_s2mm_sts_bank;

  sparse_isa_dispatcher u_dispatcher(
    .aclk(aclk),.aresetn(aresetn),.cmd_dispatcher_start(cmd_dispatcher_start),
    .cmd_dispatcher_busy(cmd_dispatcher_busy),.cmd_dispatcher_done(cmd_dispatcher_done),
    .cmd_dispatcher_error(cmd_dispatcher_error),.cmd_dispatcher_error_code(cmd_dispatcher_error_code),
    .current_pc(current_pc),.cmd_enb(cmd_enb),.cmd_addrb(cmd_addrb),.cmd_doutb(cmd_doutb),
    .m_ctrl_mm2s_cmd_valid(d_mm2s_valid),.m_ctrl_mm2s_cmd_ready(d_mm2s_ready),
    .m_ctrl_mm2s_cmd_addr(d_mm2s_addr),.m_ctrl_mm2s_cmd_btt(d_mm2s_btt),
    .m_ctrl_mm2s_cmd_offset(d_mm2s_offset),.m_ctrl_mm2s_cmd_bank(d_mm2s_bank),
    .m_ctrl_mm2s_cmd_tag(unused_mm2s_bank_tag),.s_ctrl_mm2s_sts_valid(e_mm2s_sts_valid),
    .m_ctrl_mm2s_sts_ready(e_mm2s_sts_ready),.s_ctrl_mm2s_sts_tag(e_mm2s_sts_bank),
    .s_ctrl_mm2s_sts_error(e_mm2s_sts_error),.s_ctrl_mm2s_sts_error_code(e_mm2s_sts_code),
    .m_ctrl_s2mm_cmd_valid(d_s2mm_valid),.m_ctrl_s2mm_cmd_ready(d_s2mm_ready),
    .m_ctrl_s2mm_cmd_addr(d_s2mm_addr),.m_ctrl_s2mm_cmd_btt(d_s2mm_btt),
    .m_ctrl_s2mm_cmd_offset(d_s2mm_offset),.m_ctrl_s2mm_cmd_bank(d_s2mm_bank),
    .m_ctrl_s2mm_cmd_tag(unused_s2mm_bank_tag),.s_ctrl_s2mm_sts_valid(e_s2mm_sts_valid),
    .m_ctrl_s2mm_sts_ready(e_s2mm_sts_ready),.s_ctrl_s2mm_sts_tag(e_s2mm_sts_bank),
    .s_ctrl_s2mm_sts_error(e_s2mm_sts_error),.s_ctrl_s2mm_sts_error_code(e_s2mm_sts_code),
    .m_ctrl_sa_cmd_valid(m_ctrl_sa_cmd_valid),.m_ctrl_sa_cmd_ready(m_ctrl_sa_cmd_ready),
    .m_ctrl_sa_m_size(m_ctrl_sa_m_size),.m_ctrl_sa_n_size(m_ctrl_sa_n_size),
    .m_ctrl_sa_k_size(m_ctrl_sa_k_size),.m_ctrl_sa_act_bank(m_ctrl_sa_act_bank),
    .m_ctrl_sa_wgt_bank(m_ctrl_sa_wgt_bank),.m_ctrl_sa_out_bank(m_ctrl_sa_out_bank),
    .m_ctrl_sa_out_base_addr(m_ctrl_sa_out_base_addr),.s_ctrl_sa_done_valid(s_ctrl_sa_done_valid),
    .m_ctrl_sa_done_ready(m_ctrl_sa_done_ready),.s_ctrl_sa_done_error(s_ctrl_sa_done_error),
    .s_ctrl_sa_act_bank(s_ctrl_sa_act_bank),.s_ctrl_sa_wgt_bank(s_ctrl_sa_wgt_bank),
    .s_ctrl_sa_out_bank(s_ctrl_sa_out_bank),.bank_acquire_valid(acquire_valid),
    .bank_acquire_port(acquire_port),.bank_release_valid(release_valid),
    .bank_release_port(release_port),.bank_busy(bank_busy),.bank_owner_port(bank_owner_port));

  datamover_engine #(.BANK_NUM(16),.BANK_WIDTH(4),.BANK_WORD_BYTES(BANK_WORD_BYTES),
    .BANK_CAPACITY_BYTES(BANK_CAPACITY_BYTES)) u_engine(
    .aclk(aclk),.aresetn(aresetn),.s_ctrl_mm2s_pause(mm2s_pause),.s_ctrl_mm2s_abort(mm2s_abort),
    .m_ctrl_mm2s_sts_ready(e_mm2s_sts_ready),.m_ctrl_mm2s_faulted(mm2s_faulted),
    .m_ctrl_mm2s_sts_tag(mm2s_sequence_tag),.m_ctrl_mm2s_sts_received_tag(mm2s_received_tag),
    .m_ctrl_mm2s_sts_raw_status(mm2s_raw_status),.s_ctrl_mm2s_cmd_valid(d_mm2s_valid),
    .s_ctrl_mm2s_cmd_ready(d_mm2s_ready),.s_ctrl_mm2s_cmd_addr(d_mm2s_addr),
    .s_ctrl_mm2s_cmd_btt(d_mm2s_btt),.s_ctrl_mm2s_cmd_offset(d_mm2s_offset[22:0]),
    .s_ctrl_mm2s_cmd_bank(d_mm2s_bank),.m_ctrl_mm2s_sts_valid(e_mm2s_sts_valid),
    .m_ctrl_mm2s_sts_error(e_mm2s_sts_error),.m_ctrl_mm2s_sts_error_code(e_mm2s_sts_code),
    .m_ctrl_mm2s_sts_bank(e_mm2s_sts_bank),.s_ctrl_s2mm_pause(s2mm_pause),
    .s_ctrl_s2mm_abort(s2mm_abort),.m_ctrl_s2mm_sts_ready(e_s2mm_sts_ready),
    .m_ctrl_s2mm_faulted(s2mm_faulted),.m_ctrl_s2mm_sts_tag(s2mm_sequence_tag),
    .m_ctrl_s2mm_sts_received_tag(s2mm_received_tag),.m_ctrl_s2mm_sts_raw_status(s2mm_raw_status),
    .s_ctrl_s2mm_cmd_valid(d_s2mm_valid),.s_ctrl_s2mm_cmd_ready(d_s2mm_ready),
    .s_ctrl_s2mm_cmd_addr(d_s2mm_addr),.s_ctrl_s2mm_cmd_btt(d_s2mm_btt),
    .s_ctrl_s2mm_cmd_offset(d_s2mm_offset[22:0]),.s_ctrl_s2mm_cmd_bank(d_s2mm_bank),
    .m_ctrl_s2mm_sts_valid(e_s2mm_sts_valid),.m_ctrl_s2mm_sts_error(e_s2mm_sts_error),
    .m_ctrl_s2mm_sts_error_code(e_s2mm_sts_code),.m_ctrl_s2mm_sts_bank(e_s2mm_sts_bank),
    .m_axis_mm2s_cmd_tdata(m_axis_mm2s_cmd_tdata),.m_axis_mm2s_cmd_tvalid(m_axis_mm2s_cmd_tvalid),
    .m_axis_mm2s_cmd_tready(m_axis_mm2s_cmd_tready),.s_axis_mm2s_tdata(s_axis_mm2s_tdata),
    .s_axis_mm2s_tkeep(s_axis_mm2s_tkeep),.s_axis_mm2s_tvalid(s_axis_mm2s_tvalid),
    .s_axis_mm2s_tready(s_axis_mm2s_tready),.s_axis_mm2s_tlast(s_axis_mm2s_tlast),
    .s_axis_mm2s_sts_tdata(s_axis_mm2s_sts_tdata),.s_axis_mm2s_sts_tkeep(s_axis_mm2s_sts_tkeep),
    .s_axis_mm2s_sts_tvalid(s_axis_mm2s_sts_tvalid),.s_axis_mm2s_sts_tready(s_axis_mm2s_sts_tready),
    .s_axis_mm2s_sts_tlast(s_axis_mm2s_sts_tlast),.m_axis_s2mm_cmd_tdata(m_axis_s2mm_cmd_tdata),
    .m_axis_s2mm_cmd_tvalid(m_axis_s2mm_cmd_tvalid),.m_axis_s2mm_cmd_tready(m_axis_s2mm_cmd_tready),
    .m_axis_s2mm_tdata(m_axis_s2mm_tdata),.m_axis_s2mm_tkeep(m_axis_s2mm_tkeep),
    .m_axis_s2mm_tvalid(m_axis_s2mm_tvalid),.m_axis_s2mm_tready(m_axis_s2mm_tready),
    .m_axis_s2mm_tlast(m_axis_s2mm_tlast),.s_axis_s2mm_sts_tdata(s_axis_s2mm_sts_tdata),
    .s_axis_s2mm_sts_tkeep(s_axis_s2mm_sts_tkeep),.s_axis_s2mm_sts_tvalid(s_axis_s2mm_sts_tvalid),
    .s_axis_s2mm_sts_tready(s_axis_s2mm_sts_tready),.s_axis_s2mm_sts_tlast(s_axis_s2mm_sts_tlast),
    .m_ctrl_bank_wr_req(wr_req),.m_ctrl_bank_wr_grant(wr_grant),
    .m_ctrl_mm2s_adapter_start(mm_start),.m_ctrl_mm2s_adapter_done(mm_done),
    .m_ctrl_mm2s_adapter_abort(mm_abort_bank),.m_ctrl_mm2s_adapter_offset(mm_offset),
    .m_axis_mm2s_tdata(mm_data),.m_axis_mm2s_tkeep(mm_keep),.m_axis_mm2s_tvalid(mm_valid),
    .m_axis_mm2s_tready(mm_ready),.m_axis_mm2s_tlast(mm_last),
    .m_ctrl_bank_rd_req(rd_req),.m_ctrl_bank_rd_grant(rd_grant),
    .m_ctrl_s2mm_adapter_start(s2_start),.m_ctrl_s2mm_adapter_done(s2_done),
    .m_ctrl_s2mm_adapter_abort(s2_abort_bank),.m_ctrl_s2mm_adapter_btt(s2_btt),
    .m_ctrl_s2mm_adapter_offset(s2_offset),.s_axis_s2mm_tdata(s2_data),
    .s_axis_s2mm_tkeep(s2_keep),.s_axis_s2mm_tvalid(s2_valid),
    .s_axis_s2mm_tready(s2_ready),.s_axis_s2mm_tlast(s2_last));

  generate for(genvar g=0;g<3;g++)begin:g_mm2s
    mm2s_stream_bank_adapter u_adapter(.aclk(aclk),.aresetn(aresetn),
      .s_ctrl_start(mm_start[g]),.s_ctrl_done(mm_done[g]),.s_ctrl_abort(mm_abort_bank[g]),
      .s_ctrl_byte_offset(mm_offset[g]),.s_ctrl_bank(4'(g)),.s_axis_tdata(mm_data[g]),
      .s_axis_tkeep(mm_keep[g]),.s_axis_tvalid(mm_valid[g]),.s_axis_tready(mm_ready[g]),
      .s_axis_tlast(mm_last[g]),.bank_write_valid(a_wr_valid[g]),
      .bank_write_ready(a_wr_ready[g]),.bank_write_bank(a_wr_bank[g]),
      .bank_write_addr(a_wr_addr[g]),.bank_write_strb(a_wr_strb[g]),.bank_write_data(a_wr_data[g]));
  end endgenerate
  generate for(genvar g=3;g<16;g++)begin:g_mm2s_unused
    assign mm_done[g]=1'b0;assign mm_ready[g]=1'b0;
  end endgenerate

  s2mm_stream_bank_adapter u_s2mm_adapter(.aclk(aclk),.aresetn(aresetn),
    .s_ctrl_start(s2_start[3]),.s_ctrl_done(s2_done[3]),.s_ctrl_abort(s2_abort_bank[3]),
    .s_ctrl_byte_offset(s2_offset[3]),.s_ctrl_byte_count(s2_btt[3]),
    .s2mm_read_valid(bs_s2_read_valid),.s2mm_read_ready(bs_s2_read_ready),
    .s2mm_read_addr(bs_s2_read_addr),.s2mm_rsp_valid(bs_s2_rsp_valid),
    .s2mm_rsp_data(bs_s2_rsp_data),.m_axis_tdata(s2_data[3]),.m_axis_tkeep(s2_keep[3]),
    .m_axis_tvalid(s2_valid[3]),.m_axis_tready(s2_ready[3]),.m_axis_tlast(s2_last[3]));

  generate for(genvar g=0;g<3;g++)begin:g_s2mm_unused_low
    assign s2_done[g]=1'b0;assign s2_data[g]='0;assign s2_keep[g]='0;
    assign s2_valid[g]=1'b0;assign s2_last[g]=1'b0;
  end endgenerate
  generate for(genvar g=4;g<16;g++)begin:g_s2mm_unused_high
    assign s2_done[g]=1'b0;assign s2_data[g]='0;assign s2_keep[g]='0;
    assign s2_valid[g]=1'b0;assign s2_last[g]=1'b0;
  end endgenerate

  always_comb begin
    bs_mm_valid=1'b0;bs_mm_bank='0;bs_mm_addr='0;bs_mm_strb='0;bs_mm_data='0;
    if(mm_sel0_w)begin bs_mm_valid=1'b1;bs_mm_bank=a_wr_bank[0];bs_mm_addr=a_wr_addr[0];
      bs_mm_strb=a_wr_strb[0];bs_mm_data=a_wr_data[0];end
    else if(mm_sel1_w)begin bs_mm_valid=1'b1;bs_mm_bank=a_wr_bank[1];bs_mm_addr=a_wr_addr[1];
      bs_mm_strb=a_wr_strb[1];bs_mm_data=a_wr_data[1];end
    else if(mm_sel2_w)begin bs_mm_valid=1'b1;bs_mm_bank=a_wr_bank[2];bs_mm_addr=a_wr_addr[2];
      bs_mm_strb=a_wr_strb[2];bs_mm_data=a_wr_data[2];end
    for(int i=0;i<16;i++)begin
      wr_grant[i]=1'b0;rd_grant[i]=1'b0;
      if((i<3)&&wr_req[i]&&bank_busy[i]&&(bank_owner_port[i]==3'd1))wr_grant[i]=1'b1;
      if((i==3)&&rd_req[i]&&bank_busy[i]&&(bank_owner_port[i]==3'd2))rd_grant[i]=1'b1;
    end
  end

  bank_subsystem u_banks(.aclk(aclk),.aresetn(aresetn),
    .bank_acquire_valid(acquire_valid),.bank_acquire_port(acquire_port),
    .bank_release_valid(release_valid),.bank_release_port(release_port),
    .bank_busy(bank_busy),.bank_owner_port(bank_owner_port),
    .mm2s_write_valid(bs_mm_valid),.mm2s_write_ready(bs_mm_ready),.mm2s_write_bank(bs_mm_bank),
    .mm2s_write_addr(bs_mm_addr),.mm2s_write_strb(bs_mm_strb),.mm2s_write_data(bs_mm_data),
    .s2mm_read_valid(bs_s2_read_valid),.s2mm_read_ready(bs_s2_read_ready),
    .s2mm_read_addr(bs_s2_read_addr),.s2mm_rsp_valid(bs_s2_rsp_valid),.s2mm_rsp_data(bs_s2_rsp_data),
    .sa_act_read_valid(sa_act_read_valid),.sa_act_read_ready(sa_act_read_ready),
    .sa_act_read_addr(sa_act_read_addr),.sa_act_rsp_valid(sa_act_rsp_valid),.sa_act_rsp_data(sa_act_rsp_data),
    .sa_wgt_read_valid(sa_wgt_read_valid),.sa_wgt_read_ready(sa_wgt_read_ready),
    .sa_wgt_read_addr(sa_wgt_read_addr),.sa_wgt_rsp_valid(sa_wgt_rsp_valid),.sa_wgt_rsp_data(sa_wgt_rsp_data),
    .sa_out_read_valid(sa_out_read_valid),.sa_out_read_ready(sa_out_read_ready),
    .sa_out_read_addr(sa_out_read_addr),.sa_out_rsp_valid(sa_out_rsp_valid),.sa_out_rsp_data(sa_out_rsp_data),
    .sa_out_write_valid(sa_out_write_valid),.sa_out_write_ready(sa_out_write_ready),
    .sa_out_write_addr(sa_out_write_addr),.sa_out_write_strb(sa_out_write_strb),
    .sa_out_write_data(sa_out_write_data),.bank_subsystem_error(bank_subsystem_error),
    .bank_subsystem_error_code(bank_subsystem_error_code),.ownership_error(ownership_error),
    .ownership_error_code(ownership_error_code),.router_error(router_error),.router_error_code(router_error_code));

`ifndef SYNTHESIS
  always_ff @(posedge aclk)if(aresetn)begin
    assert($onehot0({a_wr_valid[2],a_wr_valid[1],a_wr_valid[0]}));
    for(int i=3;i<16;i++)assert(!wr_req[i]&&!mm_start[i]&&!mm_valid[i]);
    for(int i=0;i<16;i++)if(i!=3)assert(!rd_req[i]&&!s2_start[i]&&!s2_valid[i]);
  end
`endif
endmodule
