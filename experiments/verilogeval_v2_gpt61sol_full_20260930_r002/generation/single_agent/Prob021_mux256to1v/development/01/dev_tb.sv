`timescale 1ns/1ps
module dev_tb;
    logic [1023:0] in;
    logic [7:0] sel;
    wire [3:0] out;
    logic [3:0] expected;
    integer pattern, choice, bit_index, word_index;
    integer checks = 0;
    TopModule dut (.in(in), .sel(sel), .out(out));

    task automatic check_selection;
        integer b;
        begin
            for (b = 0; b < 4; b = b + 1)
                expected[b] = in[4 * integer'(sel) + b];
            #1;
            if (out !== expected)
                $fatal(1, "sel=%0d expected=%b actual=%b", sel, expected, out);
            checks = checks + 1;
        end
    endtask

    initial begin
        #10000;
        $fatal(1, "Timeout");
    end

    initial begin
        in = '0;
        sel = 0;
        for (pattern = 0; pattern < 20; pattern = pattern + 1) begin
            for (word_index = 0; word_index < 256; word_index = word_index + 1)
                for (bit_index = 0; bit_index < 4; bit_index = bit_index + 1) begin
                    if (pattern < 16)
                        in[4 * word_index + bit_index] = ((word_index + pattern) >> bit_index) & 1;
                    else
                        in[4 * word_index + bit_index] = $urandom_range(0, 1);
                end
            for (choice = 0; choice < 256; choice = choice + 1) begin
                sel = choice;
                check_selection();
            end
        end
        // Check input changes with a fixed selector, including the upper boundary.
        for (choice = 0; choice < 256; choice = choice + 1) begin
            sel = choice;
            in = '0;
            check_selection();
            in = '1;
            check_selection();
            in[4 * choice] = 1'bx;
            in[4 * choice + 3] = 1'bz;
            check_selection();
        end
        $display("PASS %0d multiplexer checks", checks);
        $finish;
    end
endmodule
