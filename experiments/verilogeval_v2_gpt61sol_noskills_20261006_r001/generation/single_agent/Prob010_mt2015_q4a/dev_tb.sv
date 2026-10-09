`timescale 1ns/1ps
module dev_tb;
    reg x, y;
    wire z;
    TopModule dut (.x(x), .y(y), .z(z));

    task check;
        input a, b, expected;
        begin
            x = a;
            y = b;
            #1;
            if (z !== expected)
                $fatal(1, "x=%b y=%b expected=%b got=%b", x, y, expected, z);
        end
    endtask

    initial begin
        // Exhaustive Boolean truth table from the specified function.
        check(0, 0, 0);
        check(0, 1, 0);
        check(1, 0, 1);
        check(1, 1, 0);
        // Reverse transitions ensure outputs follow inputs combinationally.
        check(1, 0, 1);
        check(0, 1, 0);
        check(0, 0, 0);
        $display("PASS: exhaustive Boolean truth table and transitions");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
