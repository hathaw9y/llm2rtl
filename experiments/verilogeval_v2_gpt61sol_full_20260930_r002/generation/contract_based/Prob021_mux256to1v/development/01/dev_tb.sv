`timescale 1ns/1ps
module dev_tb;
    logic [1023:0] in;
    logic [7:0] sel;
    wire [3:0] out;
    integer group_index, value_index, bit_index, trial, word_index;
    integer checks = 0;
    logic [3:0] expected;
    TopModule dut (.in(in), .sel(sel), .out(out));

    task automatic check_output;
        integer b;
        integer selected_group;
        begin
            #1;
            selected_group = sel;
            for (b = 0; b < 4; b = b + 1)
                expected[b] = in[4 * selected_group + b];
            if (out !== expected)
                $fatal(1, "Mismatch sel=%0d expected=%b actual=%b", sel, expected, out);
            checks = checks + 1;
        end
    endtask

    initial begin
        // Exhaust all group positions and nibble values against opposite backgrounds.
        for (group_index = 0; group_index < 256; group_index = group_index + 1) begin
            sel = group_index;
            for (value_index = 0; value_index < 16; value_index = value_index + 1) begin
                in = '0;
                for (bit_index = 0; bit_index < 4; bit_index = bit_index + 1)
                    in[4 * group_index + bit_index] = (value_index >> bit_index) & 1;
                check_output();
                in = '1;
                for (bit_index = 0; bit_index < 4; bit_index = bit_index + 1)
                    in[4 * group_index + bit_index] = (value_index >> bit_index) & 1;
                check_output();
            end
        end
        // Each input bit is selected and checked while neighboring groups remain zero.
        for (bit_index = 0; bit_index < 1024; bit_index = bit_index + 1) begin
            in = '0;
            in[bit_index] = 1'b1;
            sel = bit_index / 4;
            check_output();
            sel = ((bit_index / 4) + 1) % 256;
            check_output();
        end
        // Arbitrary full vectors: sweep every selector with input held constant.
        for (trial = 0; trial < 8; trial = trial + 1) begin
            for (word_index = 0; word_index < 32; word_index = word_index + 1)
                in[32 * word_index +: 32] = $urandom;
            for (group_index = 0; group_index < 256; group_index = group_index + 1) begin
                sel = group_index;
                check_output();
            end
        end
        // Four-state payload propagation with a known selector, including both boundaries.
        for (group_index = 0; group_index < 256; group_index = group_index + 1) begin
            in = '0;
            sel = group_index;
            in[4 * group_index] = 1'bx;
            in[4 * group_index + 1] = 1'bz;
            in[4 * group_index + 2] = 1'b1;
            in[4 * group_index + 3] = 1'b0;
            check_output();
        end
        $display("PASS: mux mapping verified in %0d checks", checks);
        $finish;
    end

    initial begin
        #20000;
        $fatal(1, "Timeout");
    end
endmodule
