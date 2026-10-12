module bank_arbiter #(
    parameter int WR_PORT_NUM      = 4,
    parameter int RD_PORT_NUM      = 4,
    parameter int BANK_ADDRA_WIDTH = 10,
    parameter int BANK_DINA_WIDTH  = 64,
    parameter int BANK_WEA_WIDTH   = BANK_DINA_WIDTH / 8,
    parameter int BANK_ADDRB_WIDTH = 10,
    parameter int BANK_DOUTB_WIDTH = 64,
    parameter int BANK_READ_LAT    = 1
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
    output logic [  BANK_WEA_WIDTH-1:0] m_bank_wea,
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
  bank_write_arbit #(
      .WR_PORT_NUM     (WR_PORT_NUM),
      .BANK_ADDRA_WIDTH(BANK_ADDRA_WIDTH),
      .BANK_DINA_WIDTH (BANK_DINA_WIDTH),
      .BANK_WEA_WIDTH  (BANK_WEA_WIDTH)
  ) u_bram_write_arbiter (
      .aclk                (aclk),
      .aresetn             (aresetn),
      .s_ctrl_bank_wr_req  (s_ctrl_bank_wr_req),
      .s_ctrl_bank_wr_grant(s_ctrl_bank_wr_grant),
      .s_bank_ena          (s_bank_ena),
      .s_bank_addra        (s_bank_addra),
      .s_bank_dina         (s_bank_dina),
      .s_bank_wea          (s_bank_wea),
      .m_bank_ena          (m_bank_ena),
      .m_bank_addra        (m_bank_addra),
      .m_bank_dina         (m_bank_dina),
      .m_bank_wea          (m_bank_wea)
  );

  bank_read_arbit #(
      .RD_PORT_NUM     (RD_PORT_NUM),
      .BANK_ADDRB_WIDTH(BANK_ADDRB_WIDTH),
      .BANK_DOUTB_WIDTH(BANK_DOUTB_WIDTH),
      .BANK_READ_LAT   (BANK_READ_LAT)
  ) u_bram_read_arbiter (
      .aclk                (aclk),
      .aresetn             (aresetn),
      .s_ctrl_bank_rd_req  (s_ctrl_bank_rd_req),
      .s_ctrl_bank_rd_grant(s_ctrl_bank_rd_grant),
      .s_bank_enb          (s_bank_enb),
      .s_bank_addrb        (s_bank_addrb),
      .s_bank_doutb        (s_bank_doutb),
      .m_bank_enb          (m_bank_enb),
      .m_bank_addrb        (m_bank_addrb),
      .m_bank_doutb        (m_bank_doutb)
  );

endmodule
