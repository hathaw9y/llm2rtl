`timescale 1ns/1ps
module dev_tb;
    logic [1:0] A;
    logic [1:0] B;
    wire z;
    integer pair_index;
    integer checks = 0;

    TopModule dut (.A(A), .B(B), .z(z));

    // Explicit truth table: only the four diagonal pairs are equal.
    task automatic check_pair(input logic [3:0] pair_bits);
        logic expected;
        begin
            case (pair_bits)
                4'b0000, 4'b0101, 4'b1010, 4'b1111: expected = 1'b1;
                default: expected = 1'b0;
            endcase
            A = pair_bits[3:2];
            B = pair_bits[1:0];
            #1;
            if (z !== expected)
                $fatal(1, "Mismatch A=%b B=%b expected=%b observed=%b", A, B, expected, z);
            checks = checks + 1;
        end
    endtask

    initial begin
        for (pair_index = 0; pair_index < 16; pair_index = pair_index + 1)
            check_pair(pair_index[3:0]);
        for (pair_index = 15; pair_index >= 0; pair_index = pair_index - 1)
            check_pair(pair_index[3:0]);
        $display("PASS: %0d equality truth-table checks", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
