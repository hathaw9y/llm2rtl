`timescale 1ns/1ps
module dev_tb;
    logic [99:0] a, b;
    logic sel;
    wire [99:0] out;
    logic [99:0] pattern_a, pattern_b;
    integer checks = 0;
    TopModule dut (.a(a), .b(b), .sel(sel), .out(out));

    task automatic verify;
        logic [99:0] expected;
        begin
            #1;
            if (sel == 1'b0) expected = a;
            else expected = b;
            if (out !== expected)
                $fatal(1, "Mismatch check %0d sel=%b a=%h b=%h out=%h expected=%h", checks, sel, a, b, out, expected);
            checks = checks + 1;
        end
    endtask

    task automatic exercise(input logic [99:0] av, bv);
        begin
            a = av; b = bv; sel = 1'b0; verify();
            sel = 1'b1; verify();
            sel = 1'b0; verify();
        end
    endtask

    initial begin
        exercise(100'b0, 100'b0);
        exercise({100{1'b1}}, {100{1'b1}});
        exercise(100'b0, {100{1'b1}});
        exercise({100{1'b1}}, 100'b0);
        exercise({50{2'b10}}, {50{2'b01}});
        for (integer i = 0; i < 100; i = i + 1) begin
            pattern_a = '0;
            pattern_a[i] = 1'b1;
            exercise(pattern_a, ~pattern_a);
            exercise(~pattern_a, pattern_a);
        end
        // Change each operand while holding the selector in each legal state.
        a = '0; b = '1; sel = 1'b0; verify();
        b = '0; verify(); a = '1; verify();
        sel = 1'b1; verify(); a = '0; verify(); b = '1; verify();
        for (integer j = 0; j < 200; j = j + 1) begin
            pattern_a = {$urandom, $urandom, $urandom, $urandom};
            pattern_b = {$urandom, $urandom, $urandom, $urandom};
            exercise(pattern_a, pattern_b);
        end
        // Known select must preserve four-state data and ignore unselected data.
        exercise({100{1'bx}}, {100{1'bz}});
        exercise('0, {100{1'bx}});
        exercise({100{1'bz}}, '1);
        $display("PASS: %0d mux checks", checks);
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
