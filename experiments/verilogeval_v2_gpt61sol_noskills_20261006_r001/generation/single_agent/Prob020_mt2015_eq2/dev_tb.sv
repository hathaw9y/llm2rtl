`timescale 1ns/1ps
module dev_tb;
    reg [1:0] A;
    reg [1:0] B;
    wire z;
    integer a_value;
    integer b_value;
    reg expected;

    TopModule dut (.A(A), .B(B), .z(z));

    initial begin
        // Enumerate the original equality truth table independently of RTL.
        for (a_value = 0; a_value < 4; a_value = a_value + 1) begin
            for (b_value = 0; b_value < 4; b_value = b_value + 1) begin
                A = a_value;
                B = b_value;
                case (a_value)
                    0: expected = (b_value == 0);
                    1: expected = (b_value == 1);
                    2: expected = (b_value == 2);
                    3: expected = (b_value == 3);
                endcase
                #1;
                if (z !== expected)
                    $fatal(1, "A=%0d B=%0d expected=%b actual=%b", A, B, expected, z);
            end
        end
        $display("PASS: all 16 two-bit equality input combinations");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Development test timeout");
    end
endmodule
