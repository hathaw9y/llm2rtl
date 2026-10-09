`timescale 1ns/1ps
module dev_tb;
    reg in1, in2, in3;
    wire out;
    reg expected;
    integer a, b, c;
    integer checked = 0;

    TopModule dut (.in1(in1), .in2(in2), .in3(in3), .out(out));

    function automatic reg level(input integer index);
        case (index)
            0: level = 1'b0;
            1: level = 1'b1;
            2: level = 1'bx;
            3: level = 1'bz;
        endcase
    endfunction

    // Explicit truth table for the original cascade of XNOR and XOR.
    function automatic reg oracle(input reg p, input reg q, input reg r);
        case ({p, q, r})
            3'b000: oracle = 1'b1;
            3'b001: oracle = 1'b0;
            3'b010: oracle = 1'b0;
            3'b011: oracle = 1'b1;
            3'b100: oracle = 1'b0;
            3'b101: oracle = 1'b1;
            3'b110: oracle = 1'b1;
            3'b111: oracle = 1'b0;
            default: oracle = 1'bx;
        endcase
    endfunction

    initial begin
        for (a = 0; a < 4; a = a + 1)
            for (b = 0; b < 4; b = b + 1)
                for (c = 0; c < 4; c = c + 1) begin
                    in1 = level(a);
                    in2 = level(b);
                    in3 = level(c);
                    expected = oracle(in1, in2, in3);
                    #1;
                    if (out !== expected)
                        $fatal(1, "Inputs %b%b%b: expected %b, got %b",
                               in1, in2, in3, expected, out);
                    checked = checked + 1;
                end
        $display("PASS: %0d combinational input cases", checked);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
