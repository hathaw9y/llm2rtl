`timescale 1ns/1ps
module dev_tb;
    logic a, b;
    wire sum, cout;
    integer checks = 0;
    integer first_pair, second_pair;

    TopModule dut (.a(a), .b(b), .sum(sum), .cout(cout));

    task automatic check_pair(input logic next_a, input logic next_b);
        logic [1:0] expected;
        begin
            a = next_a;
            b = next_b;
            expected = {1'b0, next_a} + {1'b0, next_b};
            #1;
            if ({cout, sum} !== expected)
                $fatal(1, "a=%b b=%b expected=%b actual=%b", a, b, expected, {cout, sum});
            checks = checks + 1;
        end
    endtask

    initial begin
        // Exhaustive truth table and all ordered transitions, including holds.
        for (first_pair = 0; first_pair < 4; first_pair = first_pair + 1) begin
            for (second_pair = 0; second_pair < 4; second_pair = second_pair + 1) begin
                check_pair(first_pair[1], first_pair[0]);
                check_pair(second_pair[1], second_pair[0]);
            end
        end
        $display("PASS half-adder: %0d arithmetic comparisons", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout waiting for half-adder checks");
    end
endmodule
