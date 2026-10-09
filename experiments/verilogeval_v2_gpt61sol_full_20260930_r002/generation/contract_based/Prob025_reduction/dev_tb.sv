`timescale 1ns/1ps
module dev_tb;
    logic [7:0] in;
    wire parity;
    integer checks = 0;
    integer value;
    integer bit_index;

    TopModule dut (.in(in), .parity(parity));

    task automatic check_byte(input logic [7:0] data);
        integer ones;
        integer index;
        logic expected;
        begin
            ones = 0;
            for (index = 0; index < 8; index = index + 1)
                if (data[index] == 1'b1) ones = ones + 1;
            expected = (ones % 2) == 1;
            in = data;
            #1;
            if (parity !== expected)
                $fatal(1, "Parity mismatch: in=%h expected=%b actual=%b", data, expected, parity);
            checks = checks + 1;
        end
    endtask

    initial begin
        check_byte(8'h00);
        check_byte(8'hff);
        check_byte(8'haa);
        check_byte(8'h55);
        for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
            check_byte(8'b00000001 << bit_index);
        for (value = 0; value < 256; value = value + 1)
            check_byte(value[7:0]);
        for (value = 255; value >= 0; value = value - 1)
            check_byte(value[7:0]);
        $display("PASS: %0d parity checks, all 256 byte values in both orders", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout before parity checks completed");
    end
endmodule
