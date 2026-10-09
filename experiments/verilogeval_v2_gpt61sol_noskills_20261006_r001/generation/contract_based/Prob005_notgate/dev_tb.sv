`timescale 1ns/1ps
module dev_tb;
    reg in;
    wire out;
    TopModule dut (.in(in), .out(out));

    task check;
        input stimulus;
        input expected;
        begin
            in = stimulus;
            #1;
            if (out !== expected)
                $fatal(1, "NOT mismatch: in=%b expected=%b actual=%b", in, expected, out);
        end
    endtask

    initial begin
        // Explicit truth-table oracle, independent of DUT expression.
        check(1'b0, 1'b1);
        check(1'b1, 1'b0);
        check(1'b0, 1'b1);
        check(1'b0, 1'b1);
        check(1'b1, 1'b0);
        check(1'b1, 1'b0);
        // Supplemental standard four-state NOT semantics.
        check(1'bx, 1'bx);
        check(1'bz, 1'bx);
        check(1'b0, 1'b1);
        check(1'b1, 1'b0);
        $display("PASS: NOT truth table, transitions, and four-state checks");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
