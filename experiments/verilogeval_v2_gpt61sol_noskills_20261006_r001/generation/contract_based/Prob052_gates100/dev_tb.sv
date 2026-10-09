`timescale 1ns/1ps
module dev_tb;
    reg [99:0] in;
    wire out_and, out_or, out_xor;
    integer i, j, n;
    integer checks = 0;
    reg [99:0] vector;
    reg [31:0] rng = 32'h13579bdf;
    TopModule dut (.in(in), .out_and(out_and), .out_or(out_or), .out_xor(out_xor));

    task check_binary(input reg [99:0] value);
        integer bit_index, ones;
        reg expected_and, expected_or, expected_xor;
        begin
            ones = 0;
            for (bit_index = 0; bit_index < 100; bit_index = bit_index + 1)
                if (value[bit_index] == 1'b1) ones = ones + 1;
            expected_and = (ones == 100);
            expected_or = (ones > 0);
            expected_xor = (ones % 2 == 1);
            in = value;
            #1;
            if ({out_and, out_or, out_xor} !== {expected_and, expected_or, expected_xor})
                $fatal(1, "Binary mismatch input=%h ones=%0d actual=%b%b%b", value, ones, out_and, out_or, out_xor);
            checks = checks + 1;
        end
    endtask

    task check_four_state(input reg [99:0] value, input reg [2:0] expected);
        begin
            in = value;
            #1;
            if ({out_and, out_or, out_xor} !== expected)
                $fatal(1, "Four-state mismatch input=%h actual=%b%b%b expected=%b", value, out_and, out_or, out_xor, expected);
            checks = checks + 1;
        end
    endtask

    initial begin
        check_binary(100'b0);
        check_binary({100{1'b1}});
        for (i = 0; i < 100; i = i + 1) begin
            vector = 0;
            vector[i] = 1;
            check_binary(vector);
            vector = {100{1'b1}};
            vector[i] = 0;
            check_binary(vector);
        end
        for (n = 0; n <= 100; n = n + 1) begin
            vector = 0;
            for (j = 0; j < n; j = j + 1) vector[j] = 1;
            check_binary(vector);
        end
        for (i = 0; i < 1000; i = i + 1) begin
            for (j = 0; j < 100; j = j + 1) begin
                rng = rng ^ (rng << 13);
                rng = rng ^ (rng >> 17);
                rng = rng ^ (rng << 5);
                vector[j] = rng[0];
            end
            check_binary(vector);
        end
        check_four_state({100{1'bx}}, 3'bxxx);
        check_four_state({100{1'bz}}, 3'bxxx);
        vector = 0; vector[99] = 1'bx;
        check_four_state(vector, 3'b0xx);
        vector = {100{1'b1}}; vector[0] = 1'bz;
        check_four_state(vector, 3'bx1x);
        vector = 0; vector[50] = 1; vector[25] = 1'bx;
        check_four_state(vector, 3'b01x);
        $display("PASS %0d combinational gate checks", checks);
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Bounded timeout");
    end
endmodule
