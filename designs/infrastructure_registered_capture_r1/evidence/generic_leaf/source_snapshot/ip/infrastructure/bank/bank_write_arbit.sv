module bank_write_arbit #(
    parameter int WR_PORT_NUM      = 4,
    parameter int BANK_ADDRA_WIDTH = 10,
    parameter int BANK_DINA_WIDTH  = 64,
    parameter int BANK_WEA_WIDTH   = BANK_DINA_WIDTH / 8
) (
    input  logic                        aclk,
    input  logic                        aresetn,
    // Write Port Interface
    input  logic                        s_ctrl_bank_wr_req  [WR_PORT_NUM],
    output logic                        s_ctrl_bank_wr_grant[WR_PORT_NUM],
    input  logic                        s_bank_ena          [WR_PORT_NUM],
    input  logic [BANK_ADDRA_WIDTH-1:0] s_bank_addra        [WR_PORT_NUM],
    input  logic [ BANK_DINA_WIDTH-1:0] s_bank_dina         [WR_PORT_NUM],
    input  logic [  BANK_WEA_WIDTH-1:0] s_bank_wea          [WR_PORT_NUM],
    output logic                        m_bank_ena,
    output logic [BANK_ADDRA_WIDTH-1:0] m_bank_addra,
    output logic [ BANK_DINA_WIDTH-1:0] m_bank_dina,
    output logic [  BANK_WEA_WIDTH-1:0] m_bank_wea
);

  localparam int PORT_ID_WIDTH = (WR_PORT_NUM <= 1) ? 1 : $clog2(WR_PORT_NUM);
  typedef enum logic [0:0] {
    IDLE,
    WRITE
  } state_t;

  state_t state, next_state;

  logic [PORT_ID_WIDTH-1:0] wr_port_id_r;
  logic [PORT_ID_WIDTH-1:0] rr_start_r;
  logic [PORT_ID_WIDTH-1:0] wr_select_id_w;
  logic                     wr_select_valid_w;


  always_ff @(posedge aclk) begin
    if (!aresetn) state <= IDLE;
    else state <= next_state;
  end

  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (wr_select_valid_w) next_state = WRITE;
      end

      WRITE: begin
        if (!s_ctrl_bank_wr_req[wr_port_id_r]) next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  always_comb begin
    wr_select_id_w    = rr_start_r;
    wr_select_valid_w = 1'b0;

    for (int offset = 0; offset < WR_PORT_NUM; offset++) begin
      int candidate;

      candidate = int'(rr_start_r) + offset;
      if (candidate >= WR_PORT_NUM) candidate = candidate - WR_PORT_NUM;

      if (!wr_select_valid_w && s_ctrl_bank_wr_req[candidate]) begin
        wr_select_id_w    = PORT_ID_WIDTH'(candidate);
        wr_select_valid_w = 1'b1;
      end
    end
  end

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      wr_port_id_r <= '0;
      rr_start_r   <= '0;
    end else if (state == IDLE && wr_select_valid_w) begin
      wr_port_id_r <= wr_select_id_w;

      if (wr_select_id_w == PORT_ID_WIDTH'(WR_PORT_NUM - 1)) rr_start_r <= '0;
      else rr_start_r <= wr_select_id_w + PORT_ID_WIDTH'(1);
    end
  end


  always_comb begin
    for (int i = 0; i < WR_PORT_NUM; i++) begin
      s_ctrl_bank_wr_grant[i] = 1'b0;
    end
    m_bank_ena   = '0;
    m_bank_addra = '0;
    m_bank_dina  = '0;
    m_bank_wea   = '0;

    if (state == WRITE) begin
      s_ctrl_bank_wr_grant[wr_port_id_r] = s_ctrl_bank_wr_req[wr_port_id_r];
      m_bank_ena                         = s_bank_ena[wr_port_id_r] && s_ctrl_bank_wr_req[wr_port_id_r];
      m_bank_addra                       = s_bank_addra[wr_port_id_r];
      m_bank_dina                        = s_bank_dina[wr_port_id_r];
      m_bank_wea                         = s_bank_wea[wr_port_id_r];
    end
  end
endmodule
