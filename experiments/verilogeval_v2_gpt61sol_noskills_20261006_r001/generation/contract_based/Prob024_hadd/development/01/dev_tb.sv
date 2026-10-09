`timescale 1ns/1ps
module dev_tb;
    reg a, b;
    wire sum, cout;
    integer i;
    integer expected_total;
    integer checks = 0;
    TopModule dut (.a(a), .b(b), .sum(sum), .cout(cout));

    task check_pair(input integer pair_value);
        begin
            a = (pair_value / 2) % 2;
            b = pair_value % 2;
            expected_total = (pair_value / 2) + (pair_value % 2);
            #1;
            if (sum !== (expected_total % 2) ||
                cout !== (expected_total / 2))
                $fatal(1, "a=%b b=%b expected total=%0d got cout=%b sum=%b",
                       a, b, expected_total, cout, sum);
            checks = checks + 1;
        end
    endtask

    initial begin
        for (i = 0; i < 4; i = i + 1) check_pair(i);
        for (i = 3; i >= 0; i = i - 1) check_pair(i);
        $display("PASS: half adder checked %0d input cases", checks);
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
