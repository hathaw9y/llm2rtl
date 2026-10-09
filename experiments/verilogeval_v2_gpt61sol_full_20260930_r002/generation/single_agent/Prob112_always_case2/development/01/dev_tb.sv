`timescale 1ns/1ps
module dev_tb;
    logic [3:0] in;
    wire [1:0] pos;
    integer pattern;
    integer bit_index;
    integer expected;
    integer checks = 0;
    logic found;

    TopModule dut (.in(in), .pos(pos));

    task automatic check_pattern(input integer value);
        begin
            expected = 0;
            found = 1'b0;
            for (bit_index = 0; bit_index < 4; bit_index = bit_index + 1) begin
                if (((value >> bit_index) & 1) && !found) begin
                    expected = bit_index;
                    found = 1'b1;
                end
            end
            in = value[3:0];
            #1;
            if (pos !== expected[1:0])
                $fatal(1, "in=%b expected=%0d actual=%b", in, expected, pos);
            checks = checks + 1;
        end
    endtask

    initial begin
        for (pattern = 0; pattern < 16; pattern = pattern + 1)
            check_pattern(pattern);
        for (pattern = 15; pattern >= 0; pattern = pattern - 1)
            check_pattern(pattern);
        $display("PASS all 16 patterns checked in both orders (%0d checks)", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Testbench timeout");
    end
endmodule
