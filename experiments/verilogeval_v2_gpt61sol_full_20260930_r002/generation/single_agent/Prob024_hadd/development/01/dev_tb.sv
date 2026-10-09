`timescale 1ns/1ps
module dev_tb;
    logic a, b;
    wire sum, cout;
    integer i;
    integer expected_total;

    TopModule dut (.a(a), .b(b), .sum(sum), .cout(cout));

    task automatic check_inputs(input logic next_a, input logic next_b);
        begin
            a = next_a;
            b = next_b;
            expected_total = int'(next_a) + int'(next_b);
            #1;
            if ({cout, sum} !== expected_total[1:0])
                $fatal(1, "a=%b b=%b expected=%b actual=%b", a, b,
                       expected_total[1:0], {cout, sum});
        end
    endtask

    initial begin
        for (i = 0; i < 4; i = i + 1)
            check_inputs(i[1], i[0]);
        // Repeat in reverse order to check combinational updates.
        for (i = 3; i >= 0; i = i - 1)
            check_inputs(i[1], i[0]);
        $display("PASS half adder: all input combinations and reverse transitions");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
