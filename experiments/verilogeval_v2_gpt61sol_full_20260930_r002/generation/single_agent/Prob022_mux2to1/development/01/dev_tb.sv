`timescale 1ns/1ps
module dev_tb;
    logic a, b, sel;
    wire out;
    integer checks = 0;
    TopModule dut (.a(a), .b(b), .sel(sel), .out(out));

    task automatic check_inputs(input logic av, bv, sv);
        logic expected;
        begin
            a = av;
            b = bv;
            sel = sv;
            if (sv == 1'b0)
                expected = av;
            else
                expected = bv;
            #1;
            if (out !== expected)
                $fatal(1, "a=%b b=%b sel=%b expected=%b got=%b", a, b, sel, expected, out);
            checks = checks + 1;
        end
    endtask

    initial begin
        for (integer s = 0; s < 2; s = s + 1)
            for (integer x = 0; x < 2; x = x + 1)
                for (integer y = 0; y < 2; y = y + 1)
                    check_inputs(x[0], y[0], s[0]);
        // Repeat select changes with opposing data to check immediate selection.
        check_inputs(1'b1, 1'b0, 1'b0);
        check_inputs(1'b1, 1'b0, 1'b1);
        check_inputs(1'b1, 1'b0, 1'b0);
        check_inputs(1'b0, 1'b1, 1'b1);
        $display("PASS: %0d mux checks", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
