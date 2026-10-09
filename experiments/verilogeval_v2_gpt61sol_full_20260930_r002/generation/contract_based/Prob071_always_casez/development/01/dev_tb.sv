`timescale 1ns/1ps
module dev_tb;
    logic [7:0] in;
    wire [2:0] pos;
    integer checks = 0;
    integer value;
    integer bit_index;

    TopModule dut (.in(in), .pos(pos));

    task automatic check_vector(input logic [7:0] vector);
        integer expected;
        integer index;
        begin
            expected = 0;
            for (index = 7; index >= 0; index = index - 1)
                if (vector[index] == 1'b1)
                    expected = index;
            in = vector;
            #1;
            if (pos !== expected[2:0])
                $fatal(1, "in=%b expected=%0d actual=%b", vector, expected, pos);
            checks = checks + 1;
        end
    endtask

    initial begin
        check_vector(8'b00000000);
        check_vector(8'b10010000);
        check_vector(8'b11111111);
        for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
            check_vector(8'b00000001 << bit_index);
        for (value = 0; value < 256; value = value + 1)
            check_vector(value[7:0]);
        for (value = 255; value >= 0; value = value - 1)
            check_vector(value[7:0]);
        check_vector(8'b00000000);
        $display("PASS priority encoder: %0d checks", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout waiting for priority encoder checks");
    end
endmodule
