module TopModule (
    input wire clk,
    input wire load,
    input wire [255:0] data,
    output reg [255:0] q
);
    wire [255:0] next_q;
    genvar r, c;
    generate
        for (r = 0; r < 16; r = r + 1) begin : rows
            for (c = 0; c < 16; c = c + 1) begin : cols
                localparam integer UP = (r + 15) % 16;
                localparam integer DOWN = (r + 1) % 16;
                localparam integer LEFT = (c + 15) % 16;
                localparam integer RIGHT = (c + 1) % 16;
                wire [3:0] count;
                assign count = {3'b0, q[UP*16+LEFT]}
                             + {3'b0, q[UP*16+c]}
                             + {3'b0, q[UP*16+RIGHT]}
                             + {3'b0, q[r*16+LEFT]}
                             + {3'b0, q[r*16+RIGHT]}
                             + {3'b0, q[DOWN*16+LEFT]}
                             + {3'b0, q[DOWN*16+c]}
                             + {3'b0, q[DOWN*16+RIGHT]};
                assign next_q[r*16+c] = (count == 4'd3) |
                                         ((count == 4'd2) & q[r*16+c]);
            end
        end
    endgenerate
    always @(posedge clk) begin
        if (load)
            q <= data;
        else
            q <= next_q;
    end
endmodule
