`timescale 1ns/1ps
// Opaque packed-data storage. Each producer owns one native-address stripe.
// Contract: contracts/striped_weight_bank_contract.json (bank leaf scope).
module smollm2_striped_weight_bank #(
    parameter integer PORT_COUNT = 4,
    parameter integer PORT_DATA_WIDTH = 128,
    parameter longint unsigned DEPTH = 16384,
    parameter integer READ_LATENCY = 3,
    parameter integer ADDR_WIDTH = 32
) (
    input  logic aclk,
    input  logic aresetn,
    input  logic clear_commit_i,
    input  logic [PORT_COUNT-1:0] ena_i,
    input  logic [ADDR_WIDTH-1:0] addra_i [PORT_COUNT],
    input  logic [PORT_DATA_WIDTH-1:0] dina_i [PORT_COUNT],
    input  logic [(PORT_DATA_WIDTH/8)-1:0] wea_i [PORT_COUNT],
    input  logic enb_i,
    input  logic [ADDR_WIDTH-1:0] addrb_i,
    output logic [PORT_COUNT*PORT_DATA_WIDTH-1:0] doutb_o,
    output logic [ADDR_WIDTH:0] commitb_o,
    output logic [PORT_COUNT-1:0] wr_address_error_o,
    output logic rd_address_error_o
);
  localparam integer REQUIRED_ADDR_WIDTH = (DEPTH <= 1) ? 1 : $clog2(DEPTH);
  localparam logic [ADDR_WIDTH:0] DEPTH_LIMIT = (ADDR_WIDTH+1)'(DEPTH);
  localparam logic PARAMETERS_LEGAL =
      (PORT_COUNT >= 1) && (PORT_DATA_WIDTH > 0) &&
      ((PORT_DATA_WIDTH % 8) == 0) && (DEPTH >= 1) &&
      (READ_LATENCY >= 1) && (ADDR_WIDTH >= REQUIRED_ADDR_WIDTH);

  logic [ADDR_WIDTH:0] stripe_prefix_r [PORT_COUNT];
  logic [PORT_COUNT-1:0] write_in_range_w;
  logic [PORT_COUNT-1:0] write_enable_w;
  logic read_in_range_w;
  logic read_enable_w;
  logic [PORT_COUNT*PORT_DATA_WIDTH-1:0] memory_output_w;
  logic read_output_live_r;

  assign read_in_range_w = ({1'b0, addrb_i} < DEPTH_LIMIT);
  assign read_enable_w = aresetn && enb_i && read_in_range_w && PARAMETERS_LEGAL;
  assign rd_address_error_o = aresetn && enb_i && !read_in_range_w;
  // XPM resets its final output register, but can retain earlier pipeline data.
  // Hide that stale data until a post-reset accepted read actually matures.
  // This aligns control to XPM's existing latency without adding a data stage.
  assign doutb_o = read_output_live_r ? memory_output_w : '0;
  if (READ_LATENCY == 1) begin : g_single_stage_visibility
    always_ff @(posedge aclk) begin
      if (!aresetn) read_output_live_r <= 1'b0;
      else if (read_enable_w) read_output_live_r <= 1'b1;
    end
  end else begin : g_pipelined_visibility
    logic [READ_LATENCY-2:0] read_valid_pipe_r;
    always_ff @(posedge aclk) begin
      if (!aresetn) begin
        read_valid_pipe_r <= '0;
        read_output_live_r <= 1'b0;
      end else begin
        read_valid_pipe_r[0] <= read_enable_w;
        for (integer q = 1; q < READ_LATENCY-1; q++)
          read_valid_pipe_r[q] <= read_valid_pipe_r[q-1];
        if (read_valid_pipe_r[READ_LATENCY-2]) read_output_live_r <= 1'b1;
      end
    end
  end

  for (genvar p = 0; p < PORT_COUNT; p++) begin : g_stripe
    assign write_in_range_w[p] = ({1'b0, addra_i[p]} < DEPTH_LIMIT);
    assign write_enable_w[p] = aresetn && !clear_commit_i && ena_i[p] &&
                               write_in_range_w[p] && PARAMETERS_LEGAL;
    assign wr_address_error_o[p] = aresetn && ena_i[p] && !write_in_range_w[p];

    uram_bank #(
        .DATA_WIDTH(PORT_DATA_WIDTH), .DEPTH(DEPTH),
        .READ_LATENCY(READ_LATENCY), .ADDR_WIDTH(ADDR_WIDTH)
    ) u_bank (
        .aclk(aclk), .aresetn(aresetn), .ena(write_enable_w[p]),
        .wea(wea_i[p]), .addra(addra_i[p]), .dina(dina_i[p]),
        .enb(read_enable_w), .addrb(addrb_i),
        .doutb(memory_output_w[p*PORT_DATA_WIDTH +: PORT_DATA_WIDTH])
    );

    // Conservative exclusive prefix: publishing a skipped row requires replay.
    // ADDR_WIDTH+1 prevents the last native row from wrapping back to zero.
    always_ff @(posedge aclk) begin
      if (!aresetn || clear_commit_i) begin
        stripe_prefix_r[p] <= '0;
      end else if (write_enable_w[p] && (&wea_i[p]) &&
                   ({1'b0, addra_i[p]} == stripe_prefix_r[p])) begin
        stripe_prefix_r[p] <= stripe_prefix_r[p] + (ADDR_WIDTH+1)'(1);
      end
    end
  end

  always_comb begin
    commitb_o = stripe_prefix_r[0];
    for (integer p = 1; p < PORT_COUNT; p++) begin
      if (stripe_prefix_r[p] < commitb_o) commitb_o = stripe_prefix_r[p];
    end
  end

`ifndef SYNTHESIS
  initial begin
    if (!PARAMETERS_LEGAL) $fatal(1, "smollm2_striped_weight_bank illegal parameters");
  end
`endif
endmodule
