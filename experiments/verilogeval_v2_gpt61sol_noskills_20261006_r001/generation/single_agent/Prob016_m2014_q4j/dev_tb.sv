`timescale 1ns/1ps
module dev_tb;
    reg [3:0] x, y;
    wire [4:0] sum;
    integer a, b;
    integer expected;
    integer checks = 0;

    TopModule dut (.x(x), .y(y), .sum(sum));

    task check_pair(input integer lhs, input integer rhs);
        begin
            x = lhs;
            y = rhs;
            expected = lhs + rhs;
            #1;
            if (sum !== expected[4:0])
                $fatal(1, "x=%0d y=%0d expected=%0d observed=%0d", lhs, rhs, expected, sum);
            checks = checks + 1;
        end
    endtask

    initial begin
        check_pair(0, 0);
        check_pair(15, 1);
        check_pair(1, 15);
        check_pair(15, 15);
        check_pair(8, 8);
        check_pair(7, 1);
        check_pair(15, 0);
        check_pair(0, 15);
        for (a = 0; a < 16; a = a + 1)
            for (b = 0; b < 16; b = b + 1)
                check_pair(a, b);
        $display("PASS: %0d checks including all 256 input pairs", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
