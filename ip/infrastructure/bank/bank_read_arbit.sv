module bank_read_arbit #(
    parameter int RD_PORT_NUM      = 4,
    parameter int BANK_ADDRB_WIDTH = 10,
    parameter int BANK_DOUTB_WIDTH = 64,
    parameter int BANK_READ_LAT    = 1
) (
    input  logic                        aclk,
    input  logic                        aresetn,
    // Read Port Interface
    input  logic                        s_ctrl_bank_rd_req  [RD_PORT_NUM],
    output logic                        s_ctrl_bank_rd_grant[RD_PORT_NUM],
    input  logic                        s_bank_enb          [RD_PORT_NUM],
    input  logic [BANK_ADDRB_WIDTH-1:0] s_bank_addrb        [RD_PORT_NUM],
    output logic [BANK_DOUTB_WIDTH-1:0] s_bank_doutb        [RD_PORT_NUM],
    output logic                        m_bank_enb,
    output logic [BANK_ADDRB_WIDTH-1:0] m_bank_addrb,
    input  logic [BANK_DOUTB_WIDTH-1:0] m_bank_doutb
);
  localparam int PORT_ID_WIDTH = (RD_PORT_NUM <= 1) ? 1 : $clog2(RD_PORT_NUM);
  localparam int LAT_CNT_WIDTH = $clog2(BANK_READ_LAT + 1);

  typedef enum logic [1:0] {
    IDLE,
    READ,
    WAIT_LATENCY
  } state_t;

  state_t state, next_state;

  logic [PORT_ID_WIDTH-1:0] rd_port_id_r;
  logic [PORT_ID_WIDTH-1:0] rr_start_r;
  logic [PORT_ID_WIDTH-1:0] rd_select_id_w;
  logic                     rd_select_valid_w;
  logic [LAT_CNT_WIDTH-1:0] lat_cnt;

  always_ff @(posedge aclk) begin
    if (!aresetn) state <= IDLE;
    else state <= next_state;
  end

  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (rd_select_valid_w) next_state = READ;
      end

      READ: begin
        if (!s_ctrl_bank_rd_req[rd_port_id_r]) next_state = WAIT_LATENCY;
      end

      WAIT_LATENCY: begin
        if (lat_cnt == LAT_CNT_WIDTH'(BANK_READ_LAT - 1)) next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  always_comb begin
    rd_select_id_w    = rr_start_r;
    rd_select_valid_w = 1'b0;

    for (int offset = 0; offset < RD_PORT_NUM; offset++) begin
      int candidate;

      candidate = int'(rr_start_r) + offset;
      if (candidate >= RD_PORT_NUM) candidate = candidate - RD_PORT_NUM;

      if (!rd_select_valid_w && s_ctrl_bank_rd_req[candidate]) begin
        rd_select_id_w    = PORT_ID_WIDTH'(candidate);
        rd_select_valid_w = 1'b1;
      end
    end
  end

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      rd_port_id_r <= '0;
      rr_start_r   <= '0;
    end else if (state == IDLE && rd_select_valid_w) begin
      rd_port_id_r <= rd_select_id_w;

      if (rd_select_id_w == PORT_ID_WIDTH'(RD_PORT_NUM - 1)) rr_start_r <= '0;
      else rr_start_r <= rd_select_id_w + PORT_ID_WIDTH'(1);
    end
  end

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      lat_cnt <= 0;
    end else if (state == WAIT_LATENCY) begin
      lat_cnt <= lat_cnt + 1;
    end else begin
      lat_cnt <= 0;
    end
  end

  always_comb begin
    for (int i = 0; i < RD_PORT_NUM; i++) begin
      s_ctrl_bank_rd_grant[i] = 1'b0;
      s_bank_doutb[i]         = '0;
    end
    m_bank_enb   = '0;
    m_bank_addrb = '0;

    if (state == READ) begin
      m_bank_enb   = s_bank_enb[rd_port_id_r] && s_ctrl_bank_rd_req[rd_port_id_r];
      m_bank_addrb = s_bank_addrb[rd_port_id_r];
    end

    if (state == READ || state == WAIT_LATENCY) begin
      s_ctrl_bank_rd_grant[rd_port_id_r] = 1'b1;
      s_bank_doutb[rd_port_id_r]         = m_bank_doutb;
    end
  end

endmodule
