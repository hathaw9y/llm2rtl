`timescale 1ns/1ps
module dev_tb;
    reg a, b;
    wire out_assign, out_alwaysblock;
    integer i, j;
    reg values [0:3];
    reg expected;
    integer checks = 0;
    TopModule dut (.a(a), .b(b), .out_assign(out_assign),
                   .out_alwaysblock(out_alwaysblock));

    // Explicit truth-table oracle, independent of DUT expressions.
    task check_inputs(input reg av, input reg bv);
        begin
            a = av;
            b = bv;
            if (av === 1'b0 || bv === 1'b0)
                expected = 1'b0;
            else if (av === 1'b1 && bv === 1'b1)
                expected = 1'b1;
            else
                expected = 1'bx;
            #1;
            if (out_assign !== expected)
                $fatal(1, "assign mismatch a=%b b=%b expected=%b got=%b", a, b, expected, out_assign);
            if (out_alwaysblock !== expected)
                $fatal(1, "always mismatch a=%b b=%b expected=%b got=%b", a, b, expected, out_alwaysblock);
            checks = checks + 1;
        end
    endtask

    initial begin
        values[0] = 1'b0;
        values[1] = 1'b1;
        values[2] = 1'bx;
        values[3] = 1'bz;
        // Traverse binary cases with each input changing independently.
        check_inputs(0, 0);
        check_inputs(0, 1);
        check_inputs(1, 1);
        check_inputs(1, 0);
        check_inputs(0, 0);
        check_inputs(1, 0);
        check_inputs(1, 1);
        check_inputs(0, 1);
        check_inputs(0, 0);
        for (i = 0; i < 4; i = i + 1)
            for (j = 0; j < 4; j = j + 1)
                check_inputs(values[i], values[j]);
        $display("PASS: %0d AND gate checks", checks);
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
