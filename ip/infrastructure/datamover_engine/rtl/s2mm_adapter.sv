module s2mm_adapter #(
    parameter int S2MM_DATA_WIDTH  = 64,
    parameter int S2MM_KEEP_WIDTH  = S2MM_DATA_WIDTH / 8,
    parameter int BANK_ADDRB_WIDTH = 9,
    parameter int BANK_DOUTB_WIDTH = 64,
    parameter int BANK_WEB_WIDTH   = BANK_DOUTB_WIDTH / 8,
    parameter int BANK_READ_LAT    = 1,
    parameter int BTT_WIDTH        = 23
) (
    input  logic                        aclk,
    input  logic                        aresetn,
    input  logic                        s_ctrl_s2mm_adapter_start,
    output logic                        s_ctrl_s2mm_adapter_done,
    input  logic                        s_ctrl_s2mm_adapter_abort,
    input  logic [       BTT_WIDTH-1:0] s_ctrl_s2mm_adapter_offset,
    input  logic [       BTT_WIDTH-1:0] s_ctrl_s2mm_adapter_btt,
    output logic [ S2MM_DATA_WIDTH-1:0] m_axis_s2mm_tdata,
    output logic [ S2MM_KEEP_WIDTH-1:0] m_axis_s2mm_tkeep,
    output logic                        m_axis_s2mm_tvalid,
    input  logic                        m_axis_s2mm_tready,
    output logic                        m_axis_s2mm_tlast,
    output logic                        bank_enb,
    output logic [BANK_ADDRB_WIDTH-1:0] bank_addrb,
    input  logic [BANK_DOUTB_WIDTH-1:0] bank_doutb
);
  localparam int BYTES_PER_BEAT = BANK_DOUTB_WIDTH / 8;
  localparam int BEAT_BYTE_WIDTH = (BYTES_PER_BEAT == 1) ? 1 : $clog2(BYTES_PER_BEAT);
  localparam int BANK_FIFO_DEPTH = (BANK_READ_LAT <= 1) ? 2 : BANK_READ_LAT + 1;
  localparam int BANK_CNT_WIDTH = $clog2(BANK_FIFO_DEPTH + 1);

  typedef enum logic [1:0] {
    IDLE,
    READ,
    DONE
  } state_t;

  state_t state, next_state;

  logic                        transaction_aresetn_w;
  logic                        abort_pending_r;
  logic                        abort_requested_w;
  logic [S2MM_DATA_WIDTH-1:0] converter_data_w;
  logic [S2MM_KEEP_WIDTH-1:0] converter_keep_w;
  logic                        converter_valid_w;
  logic                        converter_ready_w;
  logic                        converter_last_w;

  logic [BANK_ADDRB_WIDTH-1:0] base_addr_r;
  logic [BANK_ADDRB_WIDTH-1:0] addr_cnt_r;
  logic [BANK_ADDRB_WIDTH-1:0] last_addr_r;
  logic [  BANK_WEB_WIDTH-1:0] last_keep_r;
  logic                        last_addr_issue_w;
  logic                        bank_read_issue_w;
  logic                        enb_done_r;

  logic                        fifo_empty_w;
  logic                        fifo_full_w;
  logic                        fifo_push_w;
  logic                        fifo_pop_w;
  logic [  BANK_CNT_WIDTH-1:0] fifo_cnt_w;
  logic [  BANK_CNT_WIDTH-1:0] outstanding_cnt_r;
  logic                        fifo_last_issue_w;

  logic [BANK_DOUTB_WIDTH-1:0] c_s_axis_tdata_w;
  logic [  BANK_WEB_WIDTH-1:0] c_s_axis_tkeep_w;
  logic                        c_s_axis_tvalid_w;
  logic                        c_s_axis_tready_w;
  logic                        c_s_axis_fire_w;
  logic                        c_s_axis_tlast_w;

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (s_ctrl_s2mm_adapter_start) begin
          if (s_ctrl_s2mm_adapter_btt == '0) next_state = DONE;
          else next_state = READ;
        end
      end
      READ: begin
        // An already offered output beat is irrevocable until accepted.
        if (abort_requested_w) begin
          if (!m_axis_s2mm_tvalid || m_axis_s2mm_tready) next_state = DONE;
        end
        else if (m_axis_s2mm_tvalid && m_axis_s2mm_tready && m_axis_s2mm_tlast) next_state = DONE;
      end
      DONE: begin
        if (!s_ctrl_s2mm_adapter_start) next_state = IDLE;
      end
      default: begin
        next_state = IDLE;
      end
    endcase
  end

  assign transaction_aresetn_w    = aresetn && (state != DONE);
  assign s_ctrl_s2mm_adapter_done = (state == DONE);
  assign abort_requested_w = abort_pending_r || s_ctrl_s2mm_adapter_abort;
  assign converter_ready_w = aresetn && (state == READ) && !abort_requested_w
                           && (!m_axis_s2mm_tvalid || m_axis_s2mm_tready);

  // One-beat output register isolates internal cancellation from AXIS stalls.
  always_ff @(posedge aclk) begin
    if (!aresetn || state == IDLE || state == DONE) begin
      abort_pending_r <= 1'b0;
      m_axis_s2mm_tvalid <= 1'b0;
      m_axis_s2mm_tdata <= '0;
      m_axis_s2mm_tkeep <= '0;
      m_axis_s2mm_tlast <= 1'b0;
    end else begin
      if (s_ctrl_s2mm_adapter_abort) abort_pending_r <= 1'b1;
      if (m_axis_s2mm_tvalid && m_axis_s2mm_tready)
        m_axis_s2mm_tvalid <= 1'b0;
      if (converter_valid_w && converter_ready_w) begin
        m_axis_s2mm_tvalid <= 1'b1;
        m_axis_s2mm_tdata <= converter_data_w;
        m_axis_s2mm_tkeep <= converter_keep_w;
        m_axis_s2mm_tlast <= converter_last_w;
      end
    end
  end

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      base_addr_r <= '0;
      last_addr_r <= '0;
      last_keep_r <= '0;
    end else if (state == IDLE && s_ctrl_s2mm_adapter_start) begin
      base_addr_r <= s_ctrl_s2mm_adapter_offset * 8 / BANK_DOUTB_WIDTH;
      last_addr_r <= (s_ctrl_s2mm_adapter_btt + BYTES_PER_BEAT - 1) / BYTES_PER_BEAT - 1'b1;
      if ((s_ctrl_s2mm_adapter_btt % BYTES_PER_BEAT) == 0) begin
        last_keep_r <= '1;
      end else begin
        last_keep_r <= {BANK_WEB_WIDTH{1'b1}} >> (BYTES_PER_BEAT - (s_ctrl_s2mm_adapter_btt % BYTES_PER_BEAT));
      end
    end
  end

  assign bank_read_issue_w = aresetn && state == READ && !abort_requested_w
                          && !enb_done_r && ((fifo_cnt_w + outstanding_cnt_r) < BANK_FIFO_DEPTH);
  assign bank_enb          = bank_read_issue_w || (outstanding_cnt_r != '0);
  assign bank_addrb        = base_addr_r + addr_cnt_r;
  assign last_addr_issue_w = (addr_cnt_r == last_addr_r);

  always_ff @(posedge aclk) begin
    if (!aresetn || state == IDLE) begin
      addr_cnt_r <= '0;
      enb_done_r <= 1'b0;
    end else if (bank_read_issue_w) begin
      addr_cnt_r <= addr_cnt_r + 1'b1;
      if (last_addr_issue_w) enb_done_r <= 1'b1;
    end
  end

  assign fifo_pop_w        = c_s_axis_fire_w;
  assign c_s_axis_fire_w   = c_s_axis_tvalid_w && c_s_axis_tready_w;
  assign c_s_axis_tvalid_w = !fifo_empty_w;
  assign c_s_axis_tkeep_w  = c_s_axis_tlast_w ? last_keep_r : '1;

  always_ff @(posedge aclk) begin
    if (!transaction_aresetn_w) begin
      outstanding_cnt_r <= '0;
    end else begin
      case ({
        bank_read_issue_w, fifo_push_w
      })
        2'b10:   outstanding_cnt_r <= outstanding_cnt_r + 1;
        2'b01:   outstanding_cnt_r <= outstanding_cnt_r - 1;
        default: outstanding_cnt_r <= outstanding_cnt_r;
      endcase
    end
  end

  pipeline #(
      .PIPE_DEPTH(BANK_READ_LAT),
      .DATA_WIDTH(2)
  ) u_bram_rd_valid_pipe (
      .aclk   (aclk),
      .aresetn(transaction_aresetn_w),
      .din  ({bank_read_issue_w, last_addr_issue_w}),
      .dout ({fifo_push_w, fifo_last_issue_w})
  );

  fifo #(
      .FIFO_DEPTH(BANK_FIFO_DEPTH),
      .DATA_WIDTH(BANK_DOUTB_WIDTH + 1)
  ) u_mem_fifo (
      .aclk   (aclk),
      .aresetn(transaction_aresetn_w),
      .push   (fifo_push_w),
      .pop    (fifo_pop_w),
      .din    ({bank_doutb, fifo_last_issue_w}),
      .dout   ({c_s_axis_tdata_w, c_s_axis_tlast_w}),
      .empty  (fifo_empty_w),
      .full   (fifo_full_w),
      .count  (fifo_cnt_w)
  );

  axis_width_converter #(
      .MASTER_DATA_WIDTH(S2MM_DATA_WIDTH),
      .SLAVE_DATA_WIDTH (BANK_DOUTB_WIDTH)
  ) u_axis_width_converter (
      .aclk         (aclk),
      .aresetn      (transaction_aresetn_w),
      .m_axis_tdata (converter_data_w),
      .m_axis_tkeep (converter_keep_w),
      .m_axis_tvalid(converter_valid_w),
      .m_axis_tready(converter_ready_w),
      .m_axis_tlast (converter_last_w),
      .s_axis_tdata (c_s_axis_tdata_w),
      .s_axis_tkeep (c_s_axis_tkeep_w),
      .s_axis_tvalid(c_s_axis_tvalid_w),
      .s_axis_tready(c_s_axis_tready_w),
      .s_axis_tlast (c_s_axis_tlast_w)
  );

endmodule
