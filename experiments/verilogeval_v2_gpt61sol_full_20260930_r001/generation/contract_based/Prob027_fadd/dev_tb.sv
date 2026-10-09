`timescale 1ns/1ps
module dev_tb;
    logic a, b, cin;
    wire cout, sum;
    integer pattern;
    integer total;
    integer checks = 0;
    TopModule dut (.a(a), .b(b), .cin(cin), .cout(cout), .sum(sum));

    task automatic check_pattern(input integer value);
        begin
            {a, b, cin} = value[2:0];
            total = integer'(a) + integer'(b) + integer'(cin);
            #1;
            if ({cout, sum} !== total[1:0])
                $fatal(1, "FAIL inputs=%b%b%b expected=%b actual=%b%b",
                       a, b, cin, total[1:0], cout, sum);
            checks = checks + 1;
        end
    endtask

    initial begin
        for (pattern = 0; pattern < 8; pattern = pattern + 1)
            check_pattern(pattern);
        for (pattern = 7; pattern >= 0; pattern = pattern - 1)
            check_pattern(pattern);
        $display("PASS: %0d full-adder checks", checks);
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: development simulation timeout");
    end
endmodule
