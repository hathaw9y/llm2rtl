`timescale 1ns/1ps
module dev_tb;
    reg a, b;
    wire sum, cout;
    integer i;
    TopModule dut (.a(a), .b(b), .sum(sum), .cout(cout));

    task check;
        input test_a, test_b, expected_sum, expected_cout;
        begin
            a = test_a;
            b = test_b;
            #1;
            if (sum !== expected_sum || cout !== expected_cout)
                $fatal(1, "Half adder mismatch: a=%b b=%b sum=%b cout=%b expected=%b%b",
                       a, b, sum, cout, expected_cout, expected_sum);
        end
    endtask

    initial begin
        // Explicit truth table derived from adding two bits without carry-in.
        for (i = 0; i < 3; i = i + 1) begin
            check(0, 0, 0, 0);
            check(0, 1, 1, 0);
            check(1, 1, 0, 1);
            check(1, 0, 1, 0);
        end
        $display("PASS: all half-adder input combinations verified");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
