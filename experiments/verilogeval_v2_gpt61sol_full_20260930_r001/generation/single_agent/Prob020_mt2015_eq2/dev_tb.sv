`timescale 1ns/1ps
module dev_tb;
    logic [1:0] A, B;
    logic z;
    integer a_value, b_value;
    logic expected;
    TopModule dut (.A(A), .B(B), .z(z));
    initial begin
        for (a_value = 0; a_value < 4; a_value = a_value + 1) begin
            for (b_value = 0; b_value < 4; b_value = b_value + 1) begin
                A = a_value[1:0];
                B = b_value[1:0];
                expected = (a_value == b_value);
                #1;
                if (z !== expected)
                    $fatal(1, "FAIL A=%b B=%b z=%b expected=%b", A, B, z, expected);
            end
        end
        $display("PASS: all 16 binary input combinations");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: simulation timeout");
    end
endmodule
