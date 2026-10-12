module mm2s_adapter #(
    parameter int MM2S_DATA_WIDTH = 64,
    parameter int MM2S_KEEP_WIDTH = MM2S_DATA_WIDTH / 8,
    parameter int BANK_ADDRA_WIDTH = 9,
    parameter int BANK_DINA_WIDTH = 64,
    parameter int BANK_WEA_WIDTH = BANK_DINA_WIDTH / 8,
    parameter int BTT_WIDTH = 23
) (
    input  logic                        aclk,
    input  logic                        aresetn,
    input  logic                        s_ctrl_mm2s_adapter_start,
    output logic                        s_ctrl_mm2s_adapter_done,
    input  logic                        s_ctrl_mm2s_adapter_abort,
    input  logic [       BTT_WIDTH-1:0] s_ctrl_mm2s_adapter_offset,
    input  logic [ MM2S_DATA_WIDTH-1:0] s_axis_mm2s_tdata,
    input  logic [ MM2S_KEEP_WIDTH-1:0] s_axis_mm2s_tkeep,
    input  logic                        s_axis_mm2s_tvalid,
    output logic                        s_axis_mm2s_tready,
    input  logic                        s_axis_mm2s_tlast,
    output logic                        bank_ena,
    output logic [BANK_ADDRA_WIDTH-1:0] bank_addra,
    output logic [ BANK_DINA_WIDTH-1:0] bank_dina,
    output logic [  BANK_WEA_WIDTH-1:0] bank_wea
);
  typedef enum logic [1:0] {
    IDLE,
    WRITE,
    DONE
  } state_t;

  state_t state, next_state;

  logic                        transaction_aresetn_w;
  logic                        input_last_seen_r;
  logic                        input_enable_w;
  logic                        converter_input_ready_w;

  logic                        c_m_axis_tvalid_w;
  logic                        c_m_axis_tready_w;
  logic [ BANK_DINA_WIDTH-1:0] c_m_axis_tdata_w;
  logic [  BANK_WEA_WIDTH-1:0] c_m_axis_tkeep_w;
  logic                        c_m_axis_tlast_w;

  logic [BANK_ADDRA_WIDTH-1:0] base_addr_r;
  logic [BANK_ADDRA_WIDTH-1:0] addr_cnt_r;


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
        if (s_ctrl_mm2s_adapter_start) next_state = WRITE;
      end
      WRITE: begin
        if (s_ctrl_mm2s_adapter_abort) next_state = DONE;
        else if (c_m_axis_tvalid_w && c_m_axis_tready_w && c_m_axis_tlast_w) next_state = DONE;
      end
      DONE: begin
        if (!s_ctrl_mm2s_adapter_start) next_state = IDLE;
      end
      default: begin
        next_state = IDLE;
      end
    endcase
  end

  assign transaction_aresetn_w    = aresetn && (state != DONE);
  assign s_ctrl_mm2s_adapter_done = (state == DONE);
  assign c_m_axis_tready_w        = aresetn && (state == WRITE) && !s_ctrl_mm2s_adapter_abort;
  // Close the input packet at its handshake, not at the later native write.
  // Buffered width conversion may otherwise consume the next queued command.
  assign input_enable_w = aresetn && (state == WRITE)
                        && !input_last_seen_r && !s_ctrl_mm2s_adapter_abort;
  assign s_axis_mm2s_tready = converter_input_ready_w && input_enable_w;

  always_ff @(posedge aclk) begin
    if (!aresetn || state == IDLE) input_last_seen_r <= 1'b0;
    else if (s_axis_mm2s_tvalid && s_axis_mm2s_tready && s_axis_mm2s_tlast)
      input_last_seen_r <= 1'b1;
  end

  always_comb begin
    bank_ena   = c_m_axis_tvalid_w && c_m_axis_tready_w;
    bank_addra = base_addr_r + addr_cnt_r;
    bank_dina  = c_m_axis_tdata_w;
    bank_wea   = c_m_axis_tkeep_w;
  end

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      base_addr_r <= '0;
    end else if (state == IDLE && s_ctrl_mm2s_adapter_start) begin
      base_addr_r <= s_ctrl_mm2s_adapter_offset * 8 / BANK_DINA_WIDTH;
    end
  end

  always_ff @(posedge aclk) begin
    if (!aresetn || state == IDLE) begin
      addr_cnt_r <= '0;
    end else if (bank_ena) begin
      addr_cnt_r <= addr_cnt_r + 1'b1;
    end
  end

  axis_width_converter #(
      .MASTER_DATA_WIDTH(BANK_DINA_WIDTH),
      .SLAVE_DATA_WIDTH (MM2S_DATA_WIDTH)
  ) u_axis_width_converter (
      .aclk         (aclk),
      .aresetn      (transaction_aresetn_w),
      .m_axis_tdata (c_m_axis_tdata_w),
      .m_axis_tkeep (c_m_axis_tkeep_w),
      .m_axis_tvalid(c_m_axis_tvalid_w),
      .m_axis_tready(c_m_axis_tready_w),
      .m_axis_tlast (c_m_axis_tlast_w),
      .s_axis_tdata (s_axis_mm2s_tdata),
      .s_axis_tkeep (s_axis_mm2s_tkeep),
      .s_axis_tvalid(s_axis_mm2s_tvalid && input_enable_w),
      .s_axis_tready(converter_input_ready_w),
      .s_axis_tlast (s_axis_mm2s_tlast)
  );

endmodule
