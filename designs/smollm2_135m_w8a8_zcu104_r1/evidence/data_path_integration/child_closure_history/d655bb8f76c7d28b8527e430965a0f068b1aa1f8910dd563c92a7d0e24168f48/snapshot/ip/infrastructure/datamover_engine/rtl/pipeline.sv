module pipeline #(
    parameter int PIPE_DEPTH = 2,
    parameter int DATA_WIDTH = 32
) (
    input logic aclk,
    input logic aresetn,

    input  logic [DATA_WIDTH-1:0] din,
    output logic [DATA_WIDTH-1:0] dout
);
  initial begin
    if (PIPE_DEPTH < 0) $fatal(1, "PIPE_DEPTH(%0d) must not be negative", PIPE_DEPTH);
    if (DATA_WIDTH < 1) $fatal(1, "DATA_WIDTH(%0d) must be positive", DATA_WIDTH);
  end
  generate
    if (PIPE_DEPTH == 0) begin : g_no_delay
      assign dout = din;
    end else begin : g_delay
      // Packed stages preserve fixed latency and avoid stale array-output
      // propagation observed in Icarus after repeated transaction resets.
      logic [PIPE_DEPTH-1:0][DATA_WIDTH-1:0] pipe_r;

      always_ff @(posedge aclk) begin
        if (!aresetn) begin
          for (int i = 0; i < PIPE_DEPTH; i++) pipe_r[i] <= '0;
        end else begin
          pipe_r[0] <= din;
          for (int i = 1; i < PIPE_DEPTH; i++) pipe_r[i] <= pipe_r[i-1];
        end
      end

      assign dout = pipe_r[PIPE_DEPTH-1];
    end
  endgenerate
endmodule
