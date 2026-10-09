`timescale 1ns/1ps
module dev_tb;
    logic [1:0] A, B;
    logic z;
    logic expected;
    integer a_value, b_value;
    integer checks = 0;

    TopModule dut (.A(A), .B(B), .z(z));

    initial begin
        for (a_value = 0; a_value < 4; a_value = a_value + 1) begin
            for (b_value = 0; b_value < 4; b_value = b_value + 1) begin
                A = a_value[1:0];
                B = b_value[1:0];
                // Independent truth table: each A matches exactly one B.
                case (a_value)
                    0: expected = (b_value == 0);
                    1: expected = (b_value == 1);
                    2: expected = (b_value == 2);
                    3: expected = (b_value == 3);
                    default: $fatal(1, "Invalid test stimulus");
                endcase
                #1;
                if (z !== expected)
                    $fatal(1, "A=%b B=%b expected=%b actual=%b", A, B, expected, z);
                checks = checks + 1;
            end
        end
        $display("PASS: all %0d binary input pairs verified", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Test timeout");
    end
endmodule
