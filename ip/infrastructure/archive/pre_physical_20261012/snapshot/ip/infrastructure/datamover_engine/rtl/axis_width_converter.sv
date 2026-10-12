module axis_width_converter #(
    parameter int MASTER_DATA_WIDTH = 64,
    parameter int SLAVE_DATA_WIDTH  = 32,
    parameter int MASTER_KEEP_WIDTH = MASTER_DATA_WIDTH / 8,
    parameter int SLAVE_KEEP_WIDTH  = SLAVE_DATA_WIDTH / 8
) (
    input  logic                         aclk,
    input  logic                         aresetn,
    output logic [MASTER_DATA_WIDTH-1:0] m_axis_tdata,
    output logic [MASTER_KEEP_WIDTH-1:0] m_axis_tkeep,
    output logic                         m_axis_tvalid,
    input  logic                         m_axis_tready,
    output logic                         m_axis_tlast,
    input  logic [ SLAVE_DATA_WIDTH-1:0] s_axis_tdata,
    input  logic [ SLAVE_KEEP_WIDTH-1:0] s_axis_tkeep,
    input  logic                         s_axis_tvalid,
    output logic                         s_axis_tready,
    input  logic                         s_axis_tlast
);
  localparam bit IS_DOWNSIZE = (MASTER_DATA_WIDTH < SLAVE_DATA_WIDTH);
  localparam bit IS_UPSIZE = (MASTER_DATA_WIDTH > SLAVE_DATA_WIDTH);
  initial begin
    if (IS_DOWNSIZE && (SLAVE_DATA_WIDTH % MASTER_DATA_WIDTH != 0))
      $fatal(1, "SLAVE_DATA_WIDTH(%0d) must be a multiple of MASTER_DATA_WIDTH(%0d)", SLAVE_DATA_WIDTH, MASTER_DATA_WIDTH);
    if (IS_UPSIZE && (MASTER_DATA_WIDTH % SLAVE_DATA_WIDTH != 0))
      $fatal(1, "MASTER_DATA_WIDTH(%0d) must be a multiple of SLAVE_DATA_WIDTH(%0d)", MASTER_DATA_WIDTH, SLAVE_DATA_WIDTH);
  end

  generate
    if (IS_DOWNSIZE) begin : g_downsize
      axis_width_down_converter #(
          .MASTER_DATA_WIDTH(MASTER_DATA_WIDTH),
          .SLAVE_DATA_WIDTH (SLAVE_DATA_WIDTH)
      ) downsize_inst (
          .aclk         (aclk),
          .aresetn      (aresetn),
          .m_axis_tdata (m_axis_tdata),
          .m_axis_tkeep (m_axis_tkeep),
          .m_axis_tvalid(m_axis_tvalid),
          .m_axis_tready(m_axis_tready),
          .m_axis_tlast (m_axis_tlast),
          .s_axis_tdata (s_axis_tdata),
          .s_axis_tkeep (s_axis_tkeep),
          .s_axis_tvalid(s_axis_tvalid),
          .s_axis_tready(s_axis_tready),
          .s_axis_tlast (s_axis_tlast)
      );
    end else if (IS_UPSIZE) begin : g_upsize
      axis_width_up_converter #(
          .MASTER_DATA_WIDTH(MASTER_DATA_WIDTH),
          .SLAVE_DATA_WIDTH (SLAVE_DATA_WIDTH)
      ) upsize_inst (
          .aclk         (aclk),
          .aresetn      (aresetn),
          .m_axis_tdata (m_axis_tdata),
          .m_axis_tkeep (m_axis_tkeep),
          .m_axis_tvalid(m_axis_tvalid),
          .m_axis_tready(m_axis_tready),
          .m_axis_tlast (m_axis_tlast),
          .s_axis_tdata (s_axis_tdata),
          .s_axis_tkeep (s_axis_tkeep),
          .s_axis_tvalid(s_axis_tvalid),
          .s_axis_tready(s_axis_tready),
          .s_axis_tlast (s_axis_tlast)
      );
    end else begin : g_passthrough
      assign m_axis_tdata  = s_axis_tdata;
      assign m_axis_tkeep  = s_axis_tkeep;
      assign m_axis_tvalid = s_axis_tvalid;
      assign m_axis_tlast  = s_axis_tlast;
      assign s_axis_tready = m_axis_tready;
    end
  endgenerate

endmodule
