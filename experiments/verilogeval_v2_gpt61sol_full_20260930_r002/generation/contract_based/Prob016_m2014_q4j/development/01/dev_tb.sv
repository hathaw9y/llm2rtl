`timescale 1ns/1ps
module dev_tb;
    logic [3:0] x;
    logic [3:0] y;
    wire [4:0] sum;
    logic [4:0] expected;
    integer a;
    integer b;
    integer checks = 0;

    TopModule dut (.x(x), .y(y), .sum(sum));

    task automatic check_pair(input logic [3:0] x_value, input logic [3:0] y_value);
        begin
            x = x_value;
            y = y_value;
            expected = {1'b0, x_value} + {1'b0, y_value};
            #1;
            if (sum !== expected)
                $fatal(1, "x=%0d y=%0d expected=%0d observed=%b", x, y, expected, sum);
            checks = checks + 1;
        end
    endtask

    initial begin
        check_pair(4'd0, 4'd0);
        check_pair(4'd15, 4'd1);
        check_pair(4'd15, 4'd15);
        check_pair(4'd7, 4'd1);
        check_pair(4'd3, 4'd1);
        check_pair(4'd1, 4'd1);
        for (a = 0; a < 16; a = a + 1)
            for (b = 0; b < 16; b = b + 1)
                check_pair(a[3:0], b[3:0]);
        for (a = 15; a >= 0; a = a - 1)
            for (b = 15; b >= 0; b = b - 1)
                check_pair(a[3:0], b[3:0]);
        $display("PASS exhaustive 4-bit addition: %0d comparisons", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout before all addition checks completed");
    end
endmodule
