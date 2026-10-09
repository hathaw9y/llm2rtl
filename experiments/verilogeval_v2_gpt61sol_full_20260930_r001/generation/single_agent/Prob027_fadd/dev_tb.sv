`timescale 1ns/1ps
module dev_tb;
    logic a, b, cin;
    wire cout, sum;
    integer i;
    integer expected;
    TopModule dut (.a(a), .b(b), .cin(cin), .cout(cout), .sum(sum));
    initial begin
        for (i = 0; i < 8; i = i + 1) begin
            {a, b, cin} = i[2:0];
            expected = int'(a) + int'(b) + int'(cin);
            #1;
            if ({cout, sum} !== expected[1:0])
                $fatal(1, "FAIL input=%b%b%b expected=%b actual=%b", a, b, cin, expected[1:0], {cout, sum});
        end
        $display("PASS: all 8 full-adder input combinations");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
