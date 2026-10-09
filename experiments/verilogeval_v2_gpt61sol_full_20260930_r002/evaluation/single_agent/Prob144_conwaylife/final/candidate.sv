module TopModule (
    input  logic         clk,
    input  logic         load,
    input  logic [255:0] data,
    output logic [255:0] q
);
    wire [255:0] next_grid;
    genvar row, col;
    generate
        for (row = 0; row < 16; row = row + 1) begin : rows
            for (col = 0; col < 16; col = col + 1) begin : cols
                localparam integer UP = (row + 15) % 16;
                localparam integer DOWN = (row + 1) % 16;
                localparam integer LEFT = (col + 15) % 16;
                localparam integer RIGHT = (col + 1) % 16;
                wire [3:0] neighbors;
                assign neighbors = {3'b000, q[UP*16+LEFT]}
                                 + {3'b000, q[UP*16+col]}
                                 + {3'b000, q[UP*16+RIGHT]}
                                 + {3'b000, q[row*16+LEFT]}
                                 + {3'b000, q[row*16+RIGHT]}
                                 + {3'b000, q[DOWN*16+LEFT]}
                                 + {3'b000, q[DOWN*16+col]}
                                 + {3'b000, q[DOWN*16+RIGHT]};
                assign next_grid[row*16+col] = (neighbors == 4'd3)
                    | ((neighbors == 4'd2) & q[row*16+col]);
            end
        end
    endgenerate
    always_ff @(posedge clk) begin
        if (load)
            q <= data;
        else
            q <= next_grid;
    end
endmodule
