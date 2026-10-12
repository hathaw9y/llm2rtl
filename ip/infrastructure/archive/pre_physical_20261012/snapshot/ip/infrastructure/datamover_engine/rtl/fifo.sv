module fifo #(
    parameter int FIFO_DEPTH  = 16,
    parameter int DATA_WIDTH  = 64,
    parameter int COUNT_WIDTH = $clog2(FIFO_DEPTH + 1)
) (
    input logic aclk,
    input logic aresetn,

    input  logic                   push,
    input  logic                   pop,
    input  logic [ DATA_WIDTH-1:0] din,
    output logic [ DATA_WIDTH-1:0] dout,
    output logic                   empty,
    output logic                   full,
    output logic [COUNT_WIDTH-1:0] count
);
  localparam int FIFO_PTR_WIDTH = (FIFO_DEPTH <= 1) ? 1 : $clog2(FIFO_DEPTH);

  logic [    DATA_WIDTH-1:0] fifo_r   [FIFO_DEPTH];
  logic [FIFO_PTR_WIDTH-1:0] wr_ptr_r;
  logic [FIFO_PTR_WIDTH-1:0] rd_ptr_r;

  logic                      push_w;
  logic                      pop_w;

  always_comb begin
    empty = (count == '0);
    full  = (count == COUNT_WIDTH'(FIFO_DEPTH));
    dout  = fifo_r[rd_ptr_r];
  end

  always_comb begin
    push_w = push && !full;
    pop_w  = pop && !empty;
  end

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      wr_ptr_r <= '0;
      rd_ptr_r <= '0;
      count    <= '0;
    end else begin
      if (push_w) begin
        fifo_r[wr_ptr_r] <= din;
        wr_ptr_r <= (wr_ptr_r == FIFO_PTR_WIDTH'(FIFO_DEPTH - 1)) ? '0 : wr_ptr_r + 1'b1;
      end
      if (pop_w) begin
        rd_ptr_r <= (rd_ptr_r == FIFO_PTR_WIDTH'(FIFO_DEPTH - 1)) ? '0 : rd_ptr_r + 1'b1;
      end

      case ({
        push_w, pop_w
      })
        2'b10:   count <= count + 1;
        2'b01:   count <= count - 1;
        default: count <= count;

      endcase
    end
  end
endmodule
