import config_pkg::*;

module mm2s_engine #(
    parameter int MM2S_BANK_NUM = config_pkg::MM2S_BANK_NUM,
    parameter int MM2S_BANK_IDS[MM2S_BANK_NUM] = config_pkg::MM2S_BANK_IDS,
    parameter int AXI_ADDR_WIDTH = 32,
    parameter int AXIS_CMD_WIDTH = 72,
    parameter int MM2S_DATA_WIDTH = config_pkg::MM2S_DATA_WIDTH,
    parameter int MM2S_KEEP_WIDTH = MM2S_DATA_WIDTH / 8,
    parameter int STS_DATA_WIDTH = 8,
    parameter int STS_KEEP_WIDTH = STS_DATA_WIDTH / 8
) (
    input  logic                       aclk,
    input  logic                       aresetn,
    // ISA Dispatcher interface
    input  logic                       s_ctrl_mm2s_cmd_valid,
    output logic                       s_ctrl_mm2s_cmd_ready,
    input  logic [ BANK_NUM_WIDTH-1:0] s_ctrl_mm2s_cmd_dst_bank,
    input  logic [  PAYLOAD_WIDTH-1:0] s_ctrl_mm2s_cmd_payload,
    output logic                       m_ctrl_mm2s_resp_valid,
    output logic [ BANK_NUM_WIDTH-1:0] m_ctrl_mm2s_resp_bank,
    output logic                       m_ctrl_mm2s_resp_error,
    output logic [                2:0] m_ctrl_mm2s_resp_error_code,
    // Datamover Engine <-> vendor Datamover IP
    output logic [ AXIS_CMD_WIDTH-1:0] m_axis_mm2s_cmd_tdata,
    output logic                       m_axis_mm2s_cmd_tvalid,
    input  logic                       m_axis_mm2s_cmd_tready,
    input  logic [MM2S_DATA_WIDTH-1:0] s_axis_mm2s_tdata,
    input  logic [MM2S_KEEP_WIDTH-1:0] s_axis_mm2s_tkeep,
    input  logic                       s_axis_mm2s_tvalid,
    output logic                       s_axis_mm2s_tready,
    input  logic                       s_axis_mm2s_tlast,
    input  logic [ STS_DATA_WIDTH-1:0] s_axis_mm2s_sts_tdata,
    input  logic [ STS_KEEP_WIDTH-1:0] s_axis_mm2s_sts_tkeep,
    input  logic                       s_axis_mm2s_sts_tvalid,
    output logic                       s_axis_mm2s_sts_tready,
    input  logic                       s_axis_mm2s_sts_tlast,
    // Bank interface
    output logic                       mm2s_bank_ena              [MM2S_BANK_NUM],
    output logic [BANK_ADDR_WIDTH-1:0] mm2s_bank_addra            [MM2S_BANK_NUM],
    output logic [MM2S_DATA_WIDTH-1:0] mm2s_bank_dina             [MM2S_BANK_NUM],
    output logic [MM2S_KEEP_WIDTH-1:0] mm2s_bank_wea              [MM2S_BANK_NUM]
);
  localparam int BTT_WIDTH = 23;
  localparam int CMD_ADDR_OFFSET = PAYLOAD_WIDTH - 1;
  localparam int CMD_OFFSET_OFFSET = CMD_ADDR_OFFSET - AXI_ADDR_WIDTH;
  // One reserved bit between the bank offset and immediate BTT (formerly MODE).
  localparam int CMD_BTT_OFFSET = CMD_OFFSET_OFFSET - BANK_ADDR_WIDTH - 1;

  logic [ AXI_ADDR_WIDTH-1:0] ctrl_cmd_addr_w;
  logic [BANK_ADDR_WIDTH-1:0] ctrl_cmd_offset_w;
  logic [      BTT_WIDTH-1:0] ctrl_cmd_btt_w;

  logic                       mm2s_dre_w;
  logic                       mm2s_eof_w;
  logic [                5:0] mm2s_dsa_w;
  logic                       mm2s_type_w;
  logic [                3:0] mm2s_tag_w;

  logic                       axis_mm2s_cmd_fire_w;

  logic [ BANK_NUM_WIDTH-1:0] bank_head_w;
  logic [BANK_ADDR_WIDTH-1:0] offset_head_w;

  logic [BANK_ADDR_WIDTH-1:0] bank_addr_cnt_r;

  logic                       fifo_empty_w;
  logic                       fifo_full_w;
  logic                       fifo_push_w;
  logic                       fifo_pop_w;

  logic                       transaction_done_w;
  logic                       axis_mm2s_last_fire_w;
  logic                       axis_mm2s_sts_fire_w;
  logic                       axis_mm2s_sts_error_w;
  logic                       axis_mm2s_sts_error_fire_w;
  logic [                2:0] axis_mm2s_sts_error_code_w;
  logic                       axis_mm2s_done_r;
  logic                       axis_mm2s_sts_error_fire_r;
  logic [                2:0] axis_mm2s_sts_error_code_r;
  logic                       axis_mm2s_sts_done_r;
  logic                       abort_r;

  always_comb begin
    ctrl_cmd_addr_w   = s_ctrl_mm2s_cmd_payload[CMD_ADDR_OFFSET-:AXI_ADDR_WIDTH];
    ctrl_cmd_offset_w = s_ctrl_mm2s_cmd_payload[CMD_OFFSET_OFFSET-:BANK_ADDR_WIDTH];
    ctrl_cmd_btt_w    = s_ctrl_mm2s_cmd_payload[CMD_BTT_OFFSET-:BTT_WIDTH];
  end

  always_comb begin
    mm2s_dre_w = 1'b0;
    mm2s_eof_w = 1'b1;
    mm2s_dsa_w = 6'b0;
    mm2s_type_w = 1'b1;
    mm2s_tag_w = 4'b0;

    m_axis_mm2s_cmd_tvalid = aresetn && s_ctrl_mm2s_cmd_valid && !fifo_full_w;
    m_axis_mm2s_cmd_tdata = {
      4'b0,
      mm2s_tag_w,
      ctrl_cmd_addr_w,
      mm2s_dre_w,
      mm2s_eof_w,
      mm2s_dsa_w,
      mm2s_type_w,
      ctrl_cmd_btt_w
    };
  end

  assign s_ctrl_mm2s_cmd_ready = aresetn && m_axis_mm2s_cmd_tready && !fifo_full_w;
  assign axis_mm2s_cmd_fire_w  = m_axis_mm2s_cmd_tvalid && m_axis_mm2s_cmd_tready;

  fifo #(
      .FIFO_DEPTH(MM2S_FIFO_DEPTH),
      .DATA_WIDTH(BANK_NUM_WIDTH + BANK_ADDR_WIDTH)
  ) u_bank_fifo (
      .aclk   (aclk),
      .aresetn(aresetn),
      .push   (fifo_push_w),
      .pop    (fifo_pop_w),
      .din    ({s_ctrl_mm2s_cmd_dst_bank, ctrl_cmd_offset_w}),
      .dout   ({bank_head_w, offset_head_w}),
      .empty  (fifo_empty_w),
      .full   (fifo_full_w),
      .count  ()
  );

  assign fifo_push_w = axis_mm2s_cmd_fire_w;  // Push bank and offset info into FIFO when a command is issued
  assign fifo_pop_w  = m_ctrl_mm2s_resp_valid;  // Pop bank and offset info from FIFO when transaction is done

  always_comb begin
    for (int i = 0; i < MM2S_BANK_NUM; i++) begin
      mm2s_bank_ena[i]   = 1'b0;
      mm2s_bank_addra[i] = '0;
      mm2s_bank_dina[i]  = '0;
      mm2s_bank_wea[i]   = '0;
      if (bank_head_w == BANK_NUM_WIDTH'(MM2S_BANK_IDS[i]) && !fifo_empty_w) begin
        mm2s_bank_ena[i]   = s_axis_mm2s_tvalid && s_axis_mm2s_tready;
        mm2s_bank_addra[i] = offset_head_w + bank_addr_cnt_r;
        mm2s_bank_dina[i]  = s_axis_mm2s_tdata;
        mm2s_bank_wea[i]   = s_axis_mm2s_tkeep;
      end
    end
  end


  assign s_axis_mm2s_tready    = !fifo_empty_w && !axis_mm2s_done_r && !abort_r &&
                                 !axis_mm2s_sts_error_fire_w;
  assign axis_mm2s_last_fire_w = s_axis_mm2s_tvalid && s_axis_mm2s_tready && s_axis_mm2s_tlast;

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      bank_addr_cnt_r <= '0;
    end else if (m_ctrl_mm2s_resp_valid) begin
      bank_addr_cnt_r <= '0;
    end else if (s_axis_mm2s_tvalid && s_axis_mm2s_tready) begin
      bank_addr_cnt_r <= bank_addr_cnt_r + BANK_ADDR_WIDTH'(1);
    end
  end

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      axis_mm2s_done_r <= 1'b0;
    end else if (transaction_done_w) begin
      axis_mm2s_done_r <= 1'b0;
    end else if (axis_mm2s_last_fire_w) begin
      axis_mm2s_done_r <= 1'b1;
    end
  end

  assign s_axis_mm2s_sts_tready = !fifo_empty_w && !axis_mm2s_sts_done_r && !abort_r;
  assign axis_mm2s_sts_fire_w       = s_axis_mm2s_sts_tvalid && s_axis_mm2s_sts_tready && s_axis_mm2s_sts_tlast;
  assign axis_mm2s_sts_error_w      = !s_axis_mm2s_sts_tdata[7] || (s_axis_mm2s_sts_tdata[6:4] != 3'b000);
  assign axis_mm2s_sts_error_code_w = s_axis_mm2s_sts_tdata[6:4];
  assign axis_mm2s_sts_error_fire_w = axis_mm2s_sts_fire_w && axis_mm2s_sts_error_w;

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      axis_mm2s_sts_done_r       <= 1'b0;
      axis_mm2s_sts_error_fire_r <= 1'b0;
      axis_mm2s_sts_error_code_r <= '0;
      abort_r                    <= 1'b0;
    end else if (m_ctrl_mm2s_resp_valid) begin
      axis_mm2s_sts_done_r       <= 1'b0;
      axis_mm2s_sts_error_fire_r <= 1'b0;
      axis_mm2s_sts_error_code_r <= '0;
      abort_r                    <= 1'b0;
    end else if (axis_mm2s_sts_error_fire_w) begin
      axis_mm2s_sts_done_r       <= 1'b1;
      axis_mm2s_sts_error_fire_r <= 1'b1;
      axis_mm2s_sts_error_code_r <= axis_mm2s_sts_error_code_w;
      abort_r                    <= 1'b1;
    end else if (axis_mm2s_sts_fire_w) begin
      axis_mm2s_sts_done_r <= 1'b1;
    end
  end

  assign transaction_done_w          = axis_mm2s_done_r && axis_mm2s_sts_done_r;
  assign m_ctrl_mm2s_resp_valid      = transaction_done_w || axis_mm2s_sts_error_fire_r;
  assign m_ctrl_mm2s_resp_error      = axis_mm2s_sts_error_fire_r;
  assign m_ctrl_mm2s_resp_error_code = axis_mm2s_sts_error_code_r;
  assign m_ctrl_mm2s_resp_bank       = bank_head_w;
endmodule
