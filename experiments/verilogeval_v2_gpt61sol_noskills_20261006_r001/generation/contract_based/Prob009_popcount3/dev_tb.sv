`timescale 1ns/1ps
module dev_tb;
    reg [2:0] in;
    wire [1:0] out;
    integer value;
    integer bit_index;
    integer expected;
    integer checked;
    TopModule dut (.in(in), .out(out));

    task check_value(input integer stimulus);
        begin
            in = stimulus[2:0];
            expected = 0;
            for (bit_index = 0; bit_index < 3; bit_index = bit_index + 1)
                if (in[bit_index] == 1'b1)
                    expected = expected + 1;
            #1;
            if (out !== expected[1:0])
                $fatal(1, "in=%b expected=%0d actual=%b", in, expected, out);
            checked = checked + 1;
        end
    endtask

    initial begin
        checked = 0;
        for (value = 0; value < 8; value = value + 1)
            check_value(value);
        for (value = 7; value >= 0; value = value - 1)
            check_value(value);
        $display("PASS: %0d population-count checks", checked);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
