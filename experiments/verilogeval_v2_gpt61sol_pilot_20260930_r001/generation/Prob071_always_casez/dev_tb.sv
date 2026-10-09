`timescale 1ns/1ps
module dev_tb;
    logic [7:0] in;
    wire [2:0] pos;
    integer value, work_value, expected, checked;
    TopModule dut (.in(in), .pos(pos));
    task automatic check(input integer vector_value);
        begin
            in = vector_value[7:0];
            work_value = vector_value;
            expected = 0;
            if (work_value != 0) begin
                while ((work_value % 2) == 0) begin
                    work_value = work_value / 2;
                    expected = expected + 1;
                end
            end
            #1;
            if (pos !== expected[2:0])
                $fatal(1, "FAIL in=%b expected=%0d actual=%0d", in, expected, pos);
            checked = checked + 1;
        end
    endtask
    initial begin
        checked = 0;
        for (value = 0; value < 256; value = value + 1) check(value);
        for (value = 255; value >= 0; value = value - 1) check(value);
        $display("PASS: %0d checks, all 256 binary inputs forward and reverse", checked);
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "FAIL timeout");
    end
endmodule
