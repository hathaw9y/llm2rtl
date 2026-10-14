// Example only: caller supplies an already accepted, aligned packet at E0.
// Consumer accepts every valid_o pulse at E1 or reserves downstream storage.
// Packing does not establish bank legality, read credit or cancellation safety.
module registered_capture_example #(
    parameter bit USE_XILINX_FDRE = 1'b1
) (
    input logic aclk, aresetn,
    input logic accepted_i,
    input logic [63:0] payload_i,
    input logic [7:0] mask_i,
    input logic [15:0] index_i,
    input logic [31:0] transaction_i,
    input logic [15:0] generation_i,
    output wire valid_o,
    output wire [63:0] payload_o,
    output wire [7:0] mask_o,
    output wire [15:0] index_o,
    output wire [31:0] transaction_o,
    output wire [15:0] generation_o
);
  wire [135:0] packet_o;
  registered_capture #(.DATA_WIDTH(136), .GROUP_WIDTH(32),
      .USE_XILINX_FDRE(USE_XILINX_FDRE)) u_capture (
      .aclk(aclk), .aresetn(aresetn), .capture_i(accepted_i),
      .data_i({generation_i, transaction_i, index_i, mask_i, payload_i}),
      .data_o(packet_o), .valid_o(valid_o));
  assign {generation_o, transaction_o, index_o, mask_o, payload_o} = packet_o;
endmodule
