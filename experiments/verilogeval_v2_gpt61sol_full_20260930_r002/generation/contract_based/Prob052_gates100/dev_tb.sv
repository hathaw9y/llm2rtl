`timescale 1ns/1ps
module dev_tb;
    logic [99:0] in;
    wire out_and, out_or, out_xor;
    logic [99:0] vector;
    integer checks = 0;
    integer i, j, n;
    TopModule dut (.in(in), .out_and(out_and), .out_or(out_or), .out_xor(out_xor));

    task automatic check_binary(input logic [99:0] value);
        integer bit_index, ones;
        logic expected_and, expected_or, expected_xor;
        begin
            ones = 0;
            for (bit_index = 0; bit_index < 100; bit_index = bit_index + 1) begin
                if (value[bit_index] === 1'b1) ones = ones + 1;
                else if (value[bit_index] !== 1'b0) $fatal(1, "Nonbinary input to binary oracle");
            end
            expected_and = (ones == 100);
            expected_or = (ones != 0);
            expected_xor = ((ones % 2) == 1);
            in = value;
            #1;
            if ({out_and, out_or, out_xor} !== {expected_and, expected_or, expected_xor})
                $fatal(1, "Mismatch input=%h ones=%0d actual=%b%b%b expected=%b%b%b",
                       value, ones, out_and, out_or, out_xor, expected_and, expected_or, expected_xor);
            checks = checks + 1;
        end
    endtask

    task automatic check_four_state(input logic [99:0] value,
                                   input logic expected_and, expected_or, expected_xor);
        begin
            in = value;
            #1;
            if ({out_and, out_or, out_xor} !== {expected_and, expected_or, expected_xor})
                $fatal(1, "Four-state mismatch input=%h actual=%b%b%b expected=%b%b%b",
                       value, out_and, out_or, out_xor, expected_and, expected_or, expected_xor);
            checks = checks + 1;
        end
    endtask

    initial begin
        check_binary('0);
        check_binary('1);
        for (i = 0; i < 100; i = i + 1) begin
            vector = '0;
            vector[i] = 1'b1;
            check_binary(vector);
            vector = '1;
            vector[i] = 1'b0;
            check_binary(vector);
        end
        for (n = 0; n <= 100; n = n + 1) begin
            vector = '0;
            for (j = 0; j < n; j = j + 1) vector[j] = 1'b1;
            check_binary(vector);
        end
        for (i = 0; i < 100; i = i + 1) vector[i] = ((i % 2) == 1);
        check_binary(vector);
        check_binary(~vector);
        for (n = 0; n < 1000; n = n + 1) begin
            for (j = 0; j < 100; j = j + 1) vector[j] = $urandom_range(0, 1);
            check_binary(vector);
        end
        check_four_state('x, 1'bx, 1'bx, 1'bx);
        check_four_state('z, 1'bx, 1'bx, 1'bx);
        vector = '0; vector[99] = 1'bx;
        check_four_state(vector, 1'b0, 1'bx, 1'bx);
        vector = '1; vector[0] = 1'bz;
        check_four_state(vector, 1'bx, 1'b1, 1'bx);
        vector = '0; vector[0] = 1'b1; vector[50] = 1'bx;
        check_four_state(vector, 1'b0, 1'b1, 1'bx);
        $display("PASS: %0d combinational gate checks", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
