`timescale 1ns/1ps
module dev_tb;
    reg [1:0] A;
    reg [1:0] B;
    wire z;
    reg expected;
    integer a_value;
    integer b_value;
    integer checks = 0;

    TopModule dut (.A(A), .B(B), .z(z));

    // Independent truth table from the original binary equality requirement.
    function automatic expected_z(input [1:0] a, input [1:0] b);
        begin
            case ({a, b})
                4'b0000, 4'b0101, 4'b1010, 4'b1111: expected_z = 1'b1;
                default: expected_z = 1'b0;
            endcase
        end
    endfunction

    initial begin
        for (a_value = 0; a_value < 4; a_value = a_value + 1) begin
            for (b_value = 0; b_value < 4; b_value = b_value + 1) begin
                A = a_value;
                B = b_value;
                expected = expected_z(A, B);
                #1;
                if (z !== expected)
                    $fatal(1, "A=%b B=%b expected z=%b got %b", A, B, expected, z);
                checks = checks + 1;
            end
        end
        $display("PASS: all %0d binary input pairs checked", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
