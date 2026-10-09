`timescale 1ns/1ps
module dev_tb;
    logic [7:0] in;
    wire parity;
    integer value;
    integer bit_index;
    integer ones;
    integer checks;
    logic expected;

    TopModule dut (.in(in), .parity(parity));

    task automatic check_byte(input integer byte_value);
        begin
            in = byte_value[7:0];
            ones = 0;
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
                ones = ones + ((byte_value >> bit_index) & 1);
            expected = (ones % 2) != 0;
            #1;
            if (parity !== expected)
                $fatal(1, "FAIL byte=%0d expected=%b actual=%b", byte_value, expected, parity);
            checks = checks + 1;
        end
    endtask

    initial begin
        checks = 0;
        for (value = 0; value < 256; value = value + 1)
            check_byte(value);
        for (value = 255; value >= 0; value = value - 1)
            check_byte(value);
        $display("PASS: %0d checks, all 256 bytes in forward and reverse order", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "FAIL: watchdog timeout");
    end
endmodule
