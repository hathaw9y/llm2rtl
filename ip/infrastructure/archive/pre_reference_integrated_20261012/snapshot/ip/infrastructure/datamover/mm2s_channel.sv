import datamover_engine_pkg::*;

module mm2s_channel #(
    parameter int DMA_DATA_WIDTH = 64,
    parameter int BANK_NUM   = 4,
    parameter logic [BANK_NUM*32-1:0] BANK_WORD_BYTES={BANK_NUM{32'd8}},
    parameter logic [BANK_NUM*32-1:0] BANK_CAPACITY_BYTES={BANK_NUM{32'd4096}},
    parameter int BANK_WIDTH = (BANK_NUM <= 1) ? 1 : $clog2(BANK_NUM)
) (
    input  logic                       aclk,
    input  logic                       aresetn,
    input logic s_ctrl_mm2s_pause,
    input logic s_ctrl_mm2s_abort,
    input logic m_ctrl_mm2s_sts_ready,
    output logic m_ctrl_mm2s_faulted,
    output logic [3:0] m_ctrl_mm2s_sts_tag, m_ctrl_mm2s_sts_received_tag,
    output logic [7:0] m_ctrl_mm2s_sts_raw_status,
    // Scheduler <-> Datamover Engine
    input  logic                       s_ctrl_mm2s_cmd_valid,
    output logic                       s_ctrl_mm2s_cmd_ready,
    input  logic [ AXI_ADDR_WIDTH-1:0] s_ctrl_mm2s_cmd_addr,
    input  logic [      BTT_WIDTH-1:0] s_ctrl_mm2s_cmd_btt,
    input  logic [      BTT_WIDTH-1:0] s_ctrl_mm2s_cmd_offset,
    input  logic [     BANK_WIDTH-1:0] s_ctrl_mm2s_cmd_bank,
    output logic                       m_ctrl_mm2s_sts_valid,
    output logic                       m_ctrl_mm2s_sts_error,
    output logic [                7:0] m_ctrl_mm2s_sts_error_code,
    output logic [     BANK_WIDTH-1:0] m_ctrl_mm2s_sts_bank,
    // Datamover IP <-> Datamover Engine
    output logic [ CMD_DATA_WIDTH-1:0] m_axis_mm2s_cmd_tdata,
    output logic                       m_axis_mm2s_cmd_tvalid,
    input  logic                       m_axis_mm2s_cmd_tready,
    input  logic [DMA_DATA_WIDTH-1:0] s_axis_mm2s_tdata,
    input  logic [DMA_DATA_WIDTH/8-1:0] s_axis_mm2s_tkeep,
    input  logic                       s_axis_mm2s_tvalid,
    output logic                       s_axis_mm2s_tready,
    input  logic                       s_axis_mm2s_tlast,
    input  logic [ STS_DATA_WIDTH-1:0] s_axis_mm2s_sts_tdata,
    input  logic [ STS_KEEP_WIDTH-1:0] s_axis_mm2s_sts_tkeep,
    input  logic                       s_axis_mm2s_sts_tvalid,
    output logic                       s_axis_mm2s_sts_tready,
    input  logic                       s_axis_mm2s_sts_tlast,
    // On-chip Memory Adapter <-> Datamover Engine
    output logic                       m_ctrl_bank_wr_req        [BANK_NUM],
    input  logic                       m_ctrl_bank_wr_grant      [BANK_NUM],
    output logic                       m_ctrl_mm2s_adapter_start [BANK_NUM],
    input  logic                       m_ctrl_mm2s_adapter_done  [BANK_NUM],
    output logic [      BTT_WIDTH-1:0] m_ctrl_mm2s_adapter_offset[BANK_NUM],
    output logic                       m_ctrl_mm2s_adapter_abort [BANK_NUM],
    output logic [DMA_DATA_WIDTH-1:0] m_axis_mm2s_tdata         [BANK_NUM],
    output logic [DMA_DATA_WIDTH/8-1:0] m_axis_mm2s_tkeep         [BANK_NUM],
    output logic                       m_axis_mm2s_tvalid        [BANK_NUM],
    input  logic                       m_axis_mm2s_tready        [BANK_NUM],
    output logic                       m_axis_mm2s_tlast         [BANK_NUM]
);
  logic [BANK_WIDTH-1:0] bank_head_w;
  logic [BTT_WIDTH-1:0] offset_head_w,btt_head_w;
  logic head_active_w, selected_grant_w, adapter_done_w, adapter_wide_done_w;
  logic scheduler_abort_r;
  always_ff @(posedge aclk) begin
    if(!aresetn) scheduler_abort_r <= 1'b0;
    else if(s_ctrl_mm2s_abort) scheduler_abort_r <= 1'b1;
  end
  assign m_ctrl_mm2s_sts_error = (m_ctrl_mm2s_sts_error_code != 0);
  datamover_command_queue #(.BANK_NUM(BANK_NUM),.BANK_WIDTH(BANK_WIDTH),
    .DEPTH(FIFO_DEPTH),.DDR_ALIGN_BYTES(DMA_DATA_WIDTH/8),
    .BANK_WORD_BYTES(BANK_WORD_BYTES),.BANK_CAPACITY_BYTES(BANK_CAPACITY_BYTES)) control (
    .aclk(aclk),.aresetn(aresetn),.pause(s_ctrl_mm2s_pause),.scheduler_abort(s_ctrl_mm2s_abort),
    .cmd_valid(s_ctrl_mm2s_cmd_valid),.cmd_ready(s_ctrl_mm2s_cmd_ready),
    .cmd_addr(s_ctrl_mm2s_cmd_addr),.cmd_btt(s_ctrl_mm2s_cmd_btt),
    .cmd_offset(s_ctrl_mm2s_cmd_offset),.cmd_bank(s_ctrl_mm2s_cmd_bank),
    .dma_cmd_valid(m_axis_mm2s_cmd_tvalid),.dma_cmd_ready(m_axis_mm2s_cmd_tready),
    .dma_cmd_data(m_axis_mm2s_cmd_tdata),
    .status_valid(s_axis_mm2s_sts_tvalid),.status_ready(s_axis_mm2s_sts_tready),
    .status_data(s_axis_mm2s_sts_tdata),.status_keep(s_axis_mm2s_sts_tkeep[0]),
    .status_last(s_axis_mm2s_sts_tlast),
    .head_active(head_active_w),.head_bank(bank_head_w),.head_offset(offset_head_w),.head_btt(btt_head_w),
    .adapter_done(adapter_done_w),.adapter_finished(adapter_wide_done_w),
    .completion_valid(m_ctrl_mm2s_sts_valid),.completion_ready(m_ctrl_mm2s_sts_ready),
    .completion_bank(m_ctrl_mm2s_sts_bank),.completion_tag(m_ctrl_mm2s_sts_tag),
    .completion_received_tag(m_ctrl_mm2s_sts_received_tag),
    .completion_code(m_ctrl_mm2s_sts_error_code),.completion_raw_status(m_ctrl_mm2s_sts_raw_status),
    .faulted(m_ctrl_mm2s_faulted));
  always_comb begin
    selected_grant_w = 1'b0;
    adapter_done_w = 1'b0;
    s_axis_mm2s_tready = '0;

    if (head_active_w) begin
      selected_grant_w   = m_ctrl_bank_wr_grant[bank_head_w];
      adapter_done_w     = m_ctrl_mm2s_adapter_done[bank_head_w];
      s_axis_mm2s_tready = m_axis_mm2s_tready[bank_head_w] && selected_grant_w && !adapter_wide_done_w;
    end

    for (int i = 0; i < BANK_NUM; i++) begin
      m_ctrl_bank_wr_req[i]         = '0;
      m_ctrl_mm2s_adapter_start[i]  = '0;
      m_ctrl_mm2s_adapter_abort[i]  = '0;
      m_ctrl_mm2s_adapter_offset[i] = '0;

      m_axis_mm2s_tdata[i]          = '0;
      m_axis_mm2s_tkeep[i]          = '0;
      m_axis_mm2s_tvalid[i]         = 1'b0;
      m_axis_mm2s_tlast[i]          = 1'b0;
      if (bank_head_w == BANK_WIDTH'(i) && head_active_w) begin
        m_ctrl_bank_wr_req[i]         = !adapter_wide_done_w;
        m_ctrl_mm2s_adapter_start[i]  = !adapter_wide_done_w && selected_grant_w;
        m_ctrl_mm2s_adapter_abort[i]  = !adapter_wide_done_w && (scheduler_abort_r || s_ctrl_mm2s_abort);
        m_ctrl_mm2s_adapter_offset[i] = offset_head_w;

        m_axis_mm2s_tdata[i]          = s_axis_mm2s_tdata;
        m_axis_mm2s_tkeep[i]          = s_axis_mm2s_tkeep;
        m_axis_mm2s_tvalid[i]         = s_axis_mm2s_tvalid && selected_grant_w;
        m_axis_mm2s_tlast[i]          = s_axis_mm2s_tlast;
      end
    end
  end

endmodule
