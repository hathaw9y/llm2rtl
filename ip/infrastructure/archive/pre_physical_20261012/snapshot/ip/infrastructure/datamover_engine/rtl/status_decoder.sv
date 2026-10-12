import datamover_engine_pkg::*;

module status_decoder (
    input  logic                      aclk,
    input  logic                      aresetn,
    input  logic [STS_DATA_WIDTH-1:0] s_axis_sts_tdata,
    input  logic [STS_KEEP_WIDTH-1:0] s_axis_sts_tkeep,
    input  logic                      s_axis_sts_tvalid,
    output logic                      s_axis_sts_tready,
    input  logic                      s_axis_sts_tlast,
    output logic                      status_done_w,
    output logic                      status_error_w,
    output logic [               2:0] status_error_code_w,
    input  logic                      transaction_done_w
);
  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      s_axis_sts_tready <= 1'b1;
    end else if (status_done_w) begin
      s_axis_sts_tready <= 1'b0;
    end else if (transaction_done_w) begin
      s_axis_sts_tready <= 1'b1;
    end
  end

  assign status_done_w       = s_axis_sts_tvalid && s_axis_sts_tready && s_axis_sts_tlast;
  assign status_error_code_w = s_axis_sts_tdata[6:4];
  assign status_error_w      = status_done_w && (!s_axis_sts_tdata[7] || |status_error_code_w);
endmodule
