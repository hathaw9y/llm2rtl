import config_pkg::*;

module s2mm_engine #(
    parameter int AXI_ADDR_WIDTH  = 32,
    parameter int AXIS_CMD_WIDTH  = 72,
    parameter int S2MM_DATA_WIDTH = config_pkg::S2MM_DATA_WIDTH,
    parameter int S2MM_KEEP_WIDTH = S2MM_DATA_WIDTH / 8,
    parameter int STS_DATA_WIDTH  = 8,
    parameter int STS_KEEP_WIDTH  = STS_DATA_WIDTH / 8
) (
    input  logic                       aclk,
    input  logic                       aresetn,
    // ISA Dispatcher interface
    input  logic                       s_ctrl_s2mm_cmd_valid,
    output logic                       s_ctrl_s2mm_cmd_ready,
    input  logic [ BANK_NUM_WIDTH-1:0] s_ctrl_s2mm_cmd_dst_bank,
    input  logic [  PAYLOAD_WIDTH-1:0] s_ctrl_s2mm_cmd_payload,
    output logic                       m_ctrl_s2mm_resp_valid,
    output logic [ BANK_NUM_WIDTH-1:0] m_ctrl_s2mm_resp_bank,
    output logic                       m_ctrl_s2mm_resp_error,
    output logic [                2:0] m_ctrl_s2mm_resp_error_code,
    // Datamover Engine <-> vendor Datamover IP
    output logic [ AXIS_CMD_WIDTH-1:0] m_axis_s2mm_cmd_tdata,
    output logic                       m_axis_s2mm_cmd_tvalid,
    input  logic                       m_axis_s2mm_cmd_tready,
    output logic [S2MM_DATA_WIDTH-1:0] m_axis_s2mm_tdata,
    output logic [S2MM_KEEP_WIDTH-1:0] m_axis_s2mm_tkeep,
    output logic                       m_axis_s2mm_tvalid,
    input  logic                       m_axis_s2mm_tready,
    output logic                       m_axis_s2mm_tlast,
    input  logic [ STS_DATA_WIDTH-1:0] s_axis_s2mm_sts_tdata,
    input  logic [ STS_KEEP_WIDTH-1:0] s_axis_s2mm_sts_tkeep,
    input  logic                       s_axis_s2mm_sts_tvalid,
    output logic                       s_axis_s2mm_sts_tready,
    input  logic                       s_axis_s2mm_sts_tlast,
    // Bank interface
    output logic                       s2mm_bank_enb              [S2MM_BANK_NUM],
    output logic [BANK_ADDR_WIDTH-1:0] s2mm_bank_addrb            [S2MM_BANK_NUM],
    input  logic [S2MM_DATA_WIDTH-1:0] s2mm_bank_doutb            [S2MM_BANK_NUM]
);
  localparam int BTT_WIDTH = 23;
  localparam int CMD_ADDR_OFFSET = PAYLOAD_WIDTH - 1;
  localparam int CMD_OFFSET_OFFSET = CMD_ADDR_OFFSET - AXI_ADDR_WIDTH;
  // One reserved bit between the bank offset and immediate BTT (formerly MODE).
  localparam int CMD_BTT_OFFSET = CMD_OFFSET_OFFSET - BANK_ADDR_WIDTH - 1;
  localparam int BYTES_PER_BEAT = S2MM_DATA_WIDTH / 8;
  localparam int BANK_FIFO_DEPTH = (BANK_RD_LATENCY < 1) ? 3 : (BANK_RD_LATENCY + 2);
  localparam int BANK_CNT_WIDTH = $clog2(BANK_FIFO_DEPTH + 1);

  logic [ BANK_NUM_WIDTH-1:0] ctrl_cmd_bank_w;
  logic [ AXI_ADDR_WIDTH-1:0] ctrl_cmd_addr_w;
  logic [BANK_ADDR_WIDTH-1:0] ctrl_cmd_offset_w;
  logic [      BTT_WIDTH-1:0] ctrl_cmd_btt_w;

  logic                       s2mm_dre_w;
  logic                       s2mm_eof_w;
  logic [                5:0] s2mm_dsa_w;
  logic                       s2mm_type_w;
  logic [                3:0] s2mm_tag_w;

  logic                       axis_s2mm_cmd_fire_w;

  logic [BANK_ADDR_WIDTH-1:0] btt_to_addr_w;
  logic [S2MM_KEEP_WIDTH-1:0] cmd_last_keep_w;

  logic [ BANK_NUM_WIDTH-1:0] bank_head_w;
  logic [BANK_ADDR_WIDTH-1:0] offset_head_w;
  logic [BANK_ADDR_WIDTH-1:0] last_addr_cnt_head_w;
  logic [S2MM_KEEP_WIDTH-1:0] last_keep_head_w;

  logic [BANK_ADDR_WIDTH-1:0] bank_addr_cnt_r;

  logic                       fifo_empty_w;
  logic                       fifo_full_w;
  logic                       fifo_push_w;
  logic                       fifo_pop_w;

  logic                       bank_read_issue_w;
  logic                       bank_read_last_issue_w;

  logic [S2MM_DATA_WIDTH-1:0] selected_bank_doutb_w;
  logic [S2MM_DATA_WIDTH-1:0] selected_bank_doutb_r;
  logic                       bank_return_valid_w;
  logic                       bank_return_last_w;

  logic                       doutb_fifo_empty_w;
  logic                       doutb_fifo_full_w;
  logic                       doutb_fifo_push_w;
  logic                       doutb_fifo_pop_w;
  logic [ BANK_CNT_WIDTH-1:0] doutb_fifo_cnt_w;
  logic                       doutb_fifo_last_issue_w;

  logic [ BANK_CNT_WIDTH-1:0] outstanding_cnt_r;

  logic                       axis_s2mm_done_r;
  logic                       axis_s2mm_sts_fire_w;
  logic                       axis_s2mm_sts_error_w;
  logic                       axis_s2mm_sts_error_fire_w;
  logic                       transaction_done_w;
  logic                       abort_r;

  always_comb begin
    ctrl_cmd_bank_w   = s_ctrl_s2mm_cmd_dst_bank;
    ctrl_cmd_addr_w   = s_ctrl_s2mm_cmd_payload[CMD_ADDR_OFFSET-:AXI_ADDR_WIDTH];
    ctrl_cmd_offset_w = s_ctrl_s2mm_cmd_payload[CMD_OFFSET_OFFSET-:BANK_ADDR_WIDTH];
    ctrl_cmd_btt_w    = s_ctrl_s2mm_cmd_payload[CMD_BTT_OFFSET-:BTT_WIDTH];
  end

  always_comb begin
    s2mm_dre_w = 1'b0;
    s2mm_eof_w = 1'b1;
    s2mm_dsa_w = 6'b0;
    s2mm_type_w = 1'b1;
    s2mm_tag_w = 4'b0;

    m_axis_s2mm_cmd_tvalid = aresetn && s_ctrl_s2mm_cmd_valid && !fifo_full_w;
    m_axis_s2mm_cmd_tdata = {
      4'b0,
      s2mm_tag_w,
      ctrl_cmd_addr_w,
      s2mm_dre_w,
      s2mm_eof_w,
      s2mm_dsa_w,
      s2mm_type_w,
      ctrl_cmd_btt_w
    };
  end

  assign s_ctrl_s2mm_cmd_ready = aresetn && m_axis_s2mm_cmd_tready && !fifo_full_w;
  assign axis_s2mm_cmd_fire_w = m_axis_s2mm_cmd_tvalid && m_axis_s2mm_cmd_tready;

  assign btt_to_addr_w         = BANK_ADDR_WIDTH'((int'(ctrl_cmd_btt_w) + BYTES_PER_BEAT - 1) / BYTES_PER_BEAT - 1);
  always_comb begin
    cmd_last_keep_w = '0;
    for (int i = 0; i < S2MM_KEEP_WIDTH; i++) begin
      if (i < (((int'(ctrl_cmd_btt_w) - 1) % BYTES_PER_BEAT) + 1)) begin
        cmd_last_keep_w[i] = 1'b1;
      end
    end
  end

  fifo #(
      .FIFO_DEPTH(S2MM_FIFO_DEPTH),
      .DATA_WIDTH(BANK_NUM_WIDTH + BANK_ADDR_WIDTH * 2 + S2MM_KEEP_WIDTH)
  ) u_bank_fifo (
      .aclk   (aclk),
      .aresetn(aresetn),
      .push   (fifo_push_w),
      .pop    (fifo_pop_w),
      .din    ({s_ctrl_s2mm_cmd_dst_bank, ctrl_cmd_offset_w, btt_to_addr_w, cmd_last_keep_w}),
      .dout   ({bank_head_w, offset_head_w, last_addr_cnt_head_w, last_keep_head_w}),
      .empty  (fifo_empty_w),
      .full   (fifo_full_w),
      .count  ()
  );

  assign fifo_push_w = axis_s2mm_cmd_fire_w;
  assign fifo_pop_w = transaction_done_w;

  assign bank_read_issue_w = !fifo_empty_w && !axis_s2mm_done_r && !abort_r &&
                             !axis_s2mm_sts_error_fire_w &&
                             ((int'(doutb_fifo_cnt_w) + int'(outstanding_cnt_r)) < BANK_FIFO_DEPTH);

  always_comb begin
    selected_bank_doutb_w = '0;
    for (int i = 0; i < S2MM_BANK_NUM; i++) begin
      s2mm_bank_enb[i]   = 1'b0;
      s2mm_bank_addrb[i] = '0;
      if (S2MM_BANK_IDS[i] >= 0 && S2MM_BANK_IDS[i] < BANK_NUM &&
          bank_head_w == BANK_NUM_WIDTH'(S2MM_BANK_IDS[i]) && !fifo_empty_w) begin
        s2mm_bank_enb[i]      = bank_read_issue_w;
        s2mm_bank_addrb[i]    = offset_head_w + bank_addr_cnt_r;
        selected_bank_doutb_w = s2mm_bank_doutb[i];
      end
    end
  end

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      bank_addr_cnt_r <= '0;
    end else if (transaction_done_w) begin
      bank_addr_cnt_r <= '0;
    end else if (bank_read_issue_w) begin
      bank_addr_cnt_r <= bank_addr_cnt_r + 1'b1;
    end
  end

  assign bank_read_last_issue_w = bank_read_issue_w && (bank_addr_cnt_r == last_addr_cnt_head_w);

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      axis_s2mm_done_r <= 1'b0;
    end else if (transaction_done_w) begin
      axis_s2mm_done_r <= 1'b0;
    end else if (bank_read_last_issue_w) begin
      axis_s2mm_done_r <= 1'b1;
    end
  end

  pipeline #(
      .PIPE_DEPTH(BANK_RD_LATENCY),
      .DATA_WIDTH(2)
  ) u_bank_rd_pipe (
      .aclk   (aclk),
      .aresetn(aresetn),
      .din    ({bank_read_issue_w, bank_read_last_issue_w}),
      .dout   ({bank_return_valid_w, bank_return_last_w})
  );

  // One stage after BANK selection, included in outstanding-read credits.
  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      selected_bank_doutb_r <= '0;
      doutb_fifo_push_w <= 1'b0;
      doutb_fifo_last_issue_w <= 1'b0;
    end else begin
      doutb_fifo_push_w <= bank_return_valid_w;
      doutb_fifo_last_issue_w <= bank_return_valid_w && bank_return_last_w;
      if (bank_return_valid_w) begin
        selected_bank_doutb_r <= selected_bank_doutb_w;
      end
    end
  end

  assign m_axis_s2mm_tvalid = aresetn && !doutb_fifo_empty_w;
  assign m_axis_s2mm_tkeep  = m_axis_s2mm_tlast ? last_keep_head_w : '1;
  assign doutb_fifo_pop_w   = m_axis_s2mm_tvalid && m_axis_s2mm_tready;

  fifo #(
      .FIFO_DEPTH(BANK_FIFO_DEPTH),
      .DATA_WIDTH(S2MM_DATA_WIDTH + 1)
  ) u_doutb_fifo (
      .aclk   (aclk),
      .aresetn(aresetn),
      .push   (doutb_fifo_push_w),
      .pop    (doutb_fifo_pop_w),
      .din    ({selected_bank_doutb_r, doutb_fifo_last_issue_w}),
      .dout   ({m_axis_s2mm_tdata, m_axis_s2mm_tlast}),
      .empty  (doutb_fifo_empty_w),
      .full   (doutb_fifo_full_w),
      .count  (doutb_fifo_cnt_w)
  );

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      outstanding_cnt_r <= '0;
    end else begin
      case ({
        bank_read_issue_w, doutb_fifo_push_w
      })
        2'b10:   outstanding_cnt_r <= outstanding_cnt_r + 1'b1;
        2'b01:   outstanding_cnt_r <= outstanding_cnt_r - 1'b1;
        default: outstanding_cnt_r <= outstanding_cnt_r;
      endcase
    end
  end

  assign s_axis_s2mm_sts_tready = !fifo_empty_w && !abort_r;
  assign axis_s2mm_sts_fire_w       = s_axis_s2mm_sts_tvalid && s_axis_s2mm_sts_tready && s_axis_s2mm_sts_tlast;
  assign axis_s2mm_sts_error_w      = !s_axis_s2mm_sts_tdata[7] || (s_axis_s2mm_sts_tdata[6:4] != 3'b000);
  assign axis_s2mm_sts_error_fire_w = axis_s2mm_sts_fire_w && axis_s2mm_sts_error_w;
  assign transaction_done_w = axis_s2mm_sts_fire_w && !axis_s2mm_sts_error_w;

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      abort_r <= 1'b0;
    end else if (axis_s2mm_sts_error_fire_w) begin
      abort_r <= 1'b1;
    end
  end

  assign m_ctrl_s2mm_resp_valid      = axis_s2mm_sts_fire_w;
  assign m_ctrl_s2mm_resp_error      = axis_s2mm_sts_error_fire_w;
  assign m_ctrl_s2mm_resp_error_code = s_axis_s2mm_sts_tdata[6:4];
  assign m_ctrl_s2mm_resp_bank       = bank_head_w;
endmodule
