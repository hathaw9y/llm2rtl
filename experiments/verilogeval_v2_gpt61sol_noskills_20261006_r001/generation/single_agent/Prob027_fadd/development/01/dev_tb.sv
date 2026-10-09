`timescale 1ns/1ps
module dev_tb;
    reg a, b, cin;
    wire cout, sum;
    integer i;
    integer expected;
    TopModule dut (.a(a), .b(b), .cin(cin), .cout(cout), .sum(sum));

    initial begin
        for (i = 0; i < 8; i = i + 1) begin
            {a, b, cin} = i[2:0];
            expected = 0;
            if (a) expected = expected + 1;
            if (b) expected = expected + 1;
            if (cin) expected = expected + 1;
            #1;
            if ({cout, sum} !== expected[1:0])
                $fatal(1, "Inputs %b%b%b: expected %b, got %b", a, b, cin, expected[1:0], {cout, sum});
        end
        $display("PASS: all eight full-adder input combinations");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
