`timescale 1ns/1ps
module dev_tb;
    reg [7:0] in;
    wire [2:0] pos;
    integer value;
    integer bit_index;
    integer expected;
    reg found;
    TopModule dut (.in(in), .pos(pos));

    task check_input(input reg [7:0] vector);
        begin
            expected = 0;
            found = 0;
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                if (!found && vector[bit_index] == 1'b1) begin
                    expected = bit_index;
                    found = 1;
                end
            end
            in = vector;
            #1;
            if (pos !== expected[2:0])
                $fatal(1, "Input %b: expected %0d, got %0d", vector, expected, pos);
        end
    endtask

    initial begin
        check_input(8'b00000000);
        check_input(8'b10010000);
        check_input(8'b10000000);
        check_input(8'b11111111);
        for (value = 0; value < 256; value = value + 1)
            check_input(value[7:0]);
        for (value = 255; value >= 0; value = value - 1)
            check_input(value[7:0]);
        $display("PASS: directed cases and all 256 inputs in both orders");
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
