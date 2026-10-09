`timescale 1ns/1ps
module dev_tb;
    logic a, b, c;
    logic out;
    integer checks = 0;

    TopModule dut (.a(a), .b(b), .c(c), .out(out));

    task automatic check_entry(input logic av, bv, cv, expected);
        begin
            a = av;
            b = bv;
            c = cv;
            #1;
            if (out !== expected)
                $fatal(1, "K-map mismatch: a=%b b=%b c=%b expected=%b actual=%b",
                       a, b, c, expected, out);
            checks = checks + 1;
        end
    endtask

    initial begin
        // Original K-map rows bc=00,01,11,10; columns a=0,1.
        check_entry(1'b0, 1'b0, 1'b0, 1'b0);
        check_entry(1'b1, 1'b0, 1'b0, 1'b1);
        check_entry(1'b0, 1'b0, 1'b1, 1'b1);
        check_entry(1'b1, 1'b0, 1'b1, 1'b1);
        check_entry(1'b0, 1'b1, 1'b1, 1'b1);
        check_entry(1'b1, 1'b1, 1'b1, 1'b1);
        check_entry(1'b0, 1'b1, 1'b0, 1'b1);
        check_entry(1'b1, 1'b1, 1'b0, 1'b1);
        // Return to the sole zero to check combinational deassertion.
        check_entry(1'b0, 1'b0, 1'b0, 1'b0);
        $display("PASS: %0d K-map checks", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
