`timescale 1ns/1ps
module dev_tb;
    reg a, b, cin;
    wire cout, sum;
    integer i;
    integer expected;
    integer checked = 0;

    TopModule dut (.a(a), .b(b), .cin(cin), .cout(cout), .sum(sum));

    task check_inputs(input integer pattern);
        begin
            a = (pattern >> 2) & 1;
            b = (pattern >> 1) & 1;
            cin = pattern & 1;
            expected = 0;
            if (a) expected = expected + 1;
            if (b) expected = expected + 1;
            if (cin) expected = expected + 1;
            #1;
            if ({cout, sum} !== expected[1:0])
                $fatal(1, "a=%b b=%b cin=%b: got %b%b expected %0d",
                       a, b, cin, cout, sum, expected);
            checked = checked + 1;
        end
    endtask

    initial begin
        for (i = 0; i < 8; i = i + 1) check_inputs(i);
        for (i = 7; i >= 0; i = i - 1) check_inputs(i);
        $display("PASS: full adder passed %0d checks covering all eight input combinations", checked);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
