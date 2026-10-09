`timescale 1ns/1ps
module dev_tb;
    reg [7:0] in;
    wire [2:0] pos;
    integer vector;
    integer checks = 0;
    TopModule dut (.in(in), .pos(pos));

    task check_vector(input reg [7:0] value);
        integer bit_index;
        reg [2:0] expected;
        begin
            expected = 3'd0;
            // Independent oracle: later updates select the smaller set index.
            for (bit_index = 7; bit_index >= 0; bit_index = bit_index - 1)
                if (value[bit_index]) expected = bit_index;
            in = value;
            #1;
            if (pos !== expected)
                $fatal(1, "in=%b expected=%0d observed=%0d", value, expected, pos);
            checks = checks + 1;
        end
    endtask

    initial begin
        check_vector(8'b10010000);
        check_vector(8'b00000000);
        check_vector(8'b11111111);
        for (vector = 0; vector < 256; vector = vector + 1)
            check_vector(vector[7:0]);
        for (vector = 255; vector >= 0; vector = vector - 1)
            check_vector(vector[7:0]);
        $display("PASS: %0d priority encoder checks", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Development test timeout");
    end
endmodule
