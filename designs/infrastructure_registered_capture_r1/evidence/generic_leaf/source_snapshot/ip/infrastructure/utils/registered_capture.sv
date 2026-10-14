// Fixed one-interval accepted-packet capture. Not an elastic ready/valid stage.
// capture_i/data_i sampled at E0; data_o/valid_o updated at E1.
module registered_capture #(
    parameter int DATA_WIDTH = 32,
    parameter int GROUP_WIDTH = 32,
    parameter bit USE_XILINX_FDRE = 1'b1
) (
    input logic aclk,
    input logic aresetn,
    input logic capture_i,
    input logic [DATA_WIDTH-1:0] data_i,
    output wire [DATA_WIDTH-1:0] data_o,
    output wire valid_o
);
  localparam int GROUP_COUNT = (DATA_WIDTH + GROUP_WIDTH - 1) / GROUP_WIDTH;
  initial begin
    if (DATA_WIDTH < 1) $fatal(1, "DATA_WIDTH must be positive");
    if (GROUP_WIDTH < 1 || GROUP_WIDTH > 32)
      $fatal(1, "GROUP_WIDTH must be in 1..32");
  end
  generate
    if (USE_XILINX_FDRE) begin : g_xilinx
      wire [DATA_WIDTH-1:0] prepared;
      wire [GROUP_COUNT-1:0] local_ce;
      wire pending_valid;
      // Dedicated R pins preserve synchronous reset priority independently of CE.
      // Preserve only primitives that establish the promised physical boundary.
      (* DONT_TOUCH = "TRUE" *) FDRE #(.INIT(1'b0)) u_pending_valid (
          .C(aclk), .R(!aresetn), .CE(1'b1), .D(capture_i), .Q(pending_valid));
      (* DONT_TOUCH = "TRUE" *) FDRE #(.INIT(1'b0)) u_output_valid (
          .C(aclk), .R(!aresetn), .CE(1'b1), .D(pending_valid), .Q(valid_o));
      for (genvar g = 0; g < GROUP_COUNT; g++) begin : g_group
        (* DONT_TOUCH = "TRUE" *) FDRE #(.INIT(1'b0)) u_local_ce (
            .C(aclk), .R(!aresetn), .CE(1'b1), .D(capture_i), .Q(local_ce[g]));
      end
      for (genvar b = 0; b < DATA_WIDTH; b++) begin : g_bit
        FDRE #(.INIT(1'b0)) u_prepare (
            .C(aclk), .R(!aresetn), .CE(1'b1), .D(data_i[b]), .Q(prepared[b]));
        (* DONT_TOUCH = "TRUE" *) FDRE #(.INIT(1'b0)) u_capture (
            .C(aclk), .R(!aresetn), .CE(local_ce[b/GROUP_WIDTH]),
            .D(prepared[b]), .Q(data_o[b]));
      end
    end else begin : g_portable
      logic [DATA_WIDTH-1:0] prepared;
      logic [DATA_WIDTH-1:0] captured;
      logic [GROUP_COUNT-1:0] local_ce;
      logic pending_valid, output_valid;
      always_ff @(posedge aclk) begin
        if (!aresetn) begin
          prepared <= '0;
          captured <= '0;
          local_ce <= '0;
          pending_valid <= 1'b0;
          output_valid <= 1'b0;
        end else begin
          prepared <= data_i;
          local_ce <= {GROUP_COUNT{capture_i}};
          pending_valid <= capture_i;
          output_valid <= pending_valid;
          for (int b = 0; b < DATA_WIDTH; b++)
            if (local_ce[b/GROUP_WIDTH]) captured[b] <= prepared[b];
        end
      end
      assign data_o = captured;
      assign valid_o = output_valid;
    end
  endgenerate
endmodule
