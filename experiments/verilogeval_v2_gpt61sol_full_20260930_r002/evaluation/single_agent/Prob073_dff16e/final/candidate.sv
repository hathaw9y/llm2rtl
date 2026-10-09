module TopModule (
    input  logic        clk,
    input  logic        resetn,
    input  logic [1:0]  byteena,
    input  logic [15:0] d,
    output logic [15:0] q
);
    always_ff @(posedge clk) begin
        if (!resetn)
            q <= 16'h0000;
        else begin
            if (byteena[0]) q[7:0] <= d[7:0];
            if (byteena[1]) q[15:8] <= d[15:8];
        end
    end
endmodule
