`timescale 1ns/1ps
module dev_tb;
    logic a, b, c, d, e;
    wire [24:0] out;
    logic [4:0] inputs;
    logic expected;
    integer pattern, row, column;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .e(e), .out(out));

    initial begin
        for (pattern = 0; pattern < 32; pattern = pattern + 1) begin
            inputs = pattern[4:0];
            {a, b, c, d, e} = inputs;
            #1;
            for (row = 0; row < 5; row = row + 1) begin
                for (column = 0; column < 5; column = column + 1) begin
                    // Rows and columns both follow a, b, c, d, e.
                    expected = (inputs[4-row] == inputs[4-column]);
                    if (out[24-(row*5+column)] !== expected)
                        $fatal(1, "pattern=%05b row=%0d column=%0d actual=%b expected=%b",
                               inputs, row, column, out[24-(row*5+column)], expected);
                end
            end
        end
        $display("PASS all 32 inputs and all 25 pairwise comparisons");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
