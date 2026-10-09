`timescale 1ns/1ps
module dev_tb;
    logic [7:0] in;
    wire [31:0] out;
    integer value;
    integer signed expected;
    integer checked;

    TopModule dut (.in(in), .out(out));

    task automatic check_value(input integer stimulus);
        begin
            in = stimulus[7:0];
            // Interpret the original eight-bit value arithmetically.
            if (stimulus >= 128)
                expected = stimulus - 256;
            else
                expected = stimulus;
            #1;
            if (out !== expected)
                $fatal(1, "input=%02h expected=%08h actual=%08h", in, expected, out);
            checked = checked + 1;
        end
    endtask

    initial begin
        checked = 0;
        check_value(0);
        check_value(127);
        check_value(128);
        check_value(255);
        for (value = 0; value < 256; value = value + 1)
            check_value(value);
        $display("PASS: sign extension checked for all 256 inputs (%0d checks)", checked);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
