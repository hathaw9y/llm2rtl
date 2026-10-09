module dev_tb;
    logic [7:0] in;
    wire [2:0] pos;
    integer value;
    integer bit_index;
    integer expected;
    integer checks = 0;
    TopModule dut (.in(in), .pos(pos));

    task automatic check_value(input integer stimulus);
        begin
            in = stimulus[7:0];
            expected = 0;
            for (bit_index = 7; bit_index >= 0; bit_index = bit_index - 1)
                if ((stimulus & (1 << bit_index)) != 0)
                    expected = bit_index;
            #1;
            if (pos !== expected[2:0])
                $fatal(1, "FAIL in=%b expected=%0d actual=%0d", in, expected, pos);
            checks = checks + 1;
        end
    endtask

    initial begin
        for (value = 0; value < 256; value = value + 1)
            check_value(value);
        for (value = 255; value >= 0; value = value - 1)
            check_value(value);
        $display("PASS: %0d exhaustive ascending/descending binary checks", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "FAIL: watchdog timeout");
    end
endmodule
