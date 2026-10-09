`timescale 1ns/1ps
module dev_tb;
    reg a, b, c, d, e;
    wire [24:0] out;
    reg [4:0] inputs;
    reg expected;
    integer pattern, row, col;
    TopModule dut(.a(a), .b(b), .c(c), .d(d), .e(e), .out(out));

    initial begin
        // Exhaust all binary inputs, including equal and alternating patterns.
        for (pattern = 0; pattern < 32; pattern = pattern + 1) begin
            inputs = pattern;
            {a, b, c, d, e} = inputs;
            #1;
            for (row = 0; row < 5; row = row + 1) begin
                for (col = 0; col < 5; col = col + 1) begin
                    expected = (inputs[4-row] == inputs[4-col]);
                    if (out[24-5*row-col] !== expected)
                        $fatal(1, "Mismatch input=%b row=%0d col=%0d got=%b expected=%b",
                               inputs, row, col, out[24-5*row-col], expected);
                end
            end
        end
        $display("PASS: all 32 inputs and 800 pairwise comparisons");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
