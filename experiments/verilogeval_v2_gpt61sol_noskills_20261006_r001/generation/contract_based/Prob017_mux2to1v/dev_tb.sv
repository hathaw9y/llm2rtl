`timescale 1ns/1ps
module dev_tb;
    reg [99:0] a, b;
    reg sel;
    wire [99:0] out;
    reg [99:0] pattern, random_a, random_b;
    integer i, j;
    integer checks = 0;
    TopModule dut (.a(a), .b(b), .sel(sel), .out(out));

    task check_selection(input [99:0] av, input [99:0] bv, input sv);
        reg [99:0] expected;
        begin
            a = av;
            b = bv;
            sel = sv;
            if (sv == 1'b0) expected = av;
            else expected = bv;
            #1;
            if (out !== expected)
                $fatal(1, "Mismatch check=%0d sel=%b a=%h b=%h expected=%h actual=%h", checks, sel, a, b, expected, out);
            checks = checks + 1;
        end
    endtask

    initial begin
        check_selection(100'b0, {100{1'b1}}, 0);
        check_selection(100'b0, {100{1'b1}}, 1);
        check_selection({100{1'b1}}, 100'b0, 0);
        check_selection({100{1'b1}}, 100'b0, 1);
        check_selection(100'b0, 100'b0, 0);
        check_selection(100'b0, 100'b0, 1);
        check_selection({100{1'b1}}, {100{1'b1}}, 0);
        check_selection({100{1'b1}}, {100{1'b1}}, 1);
        check_selection({50{2'b10}}, {50{2'b01}}, 0);
        check_selection({50{2'b10}}, {50{2'b01}}, 1);
        for (i = 0; i < 100; i = i + 1) begin
            pattern = 100'b0;
            pattern[i] = 1'b1;
            check_selection(pattern, ~pattern, 0);
            check_selection(pattern, ~pattern, 1);
            check_selection(~pattern, pattern, 0);
            check_selection(~pattern, pattern, 1);
        end
        for (i = 0; i < 200; i = i + 1) begin
            for (j = 0; j < 100; j = j + 1) begin
                random_a[j] = $random;
                random_b[j] = $random;
            end
            check_selection(random_a, random_b, 0);
            check_selection(random_a, random_b, 1);
        end
        check_selection({100{1'bx}}, 100'b0, 0);
        check_selection(100'b0, {100{1'bx}}, 1);
        check_selection({100{1'bz}}, 100'b0, 0);
        check_selection(100'b0, {100{1'bz}}, 1);
        check_selection({100{1'bx}}, {100{1'b1}}, 1);
        check_selection({100{1'b1}}, {100{1'bz}}, 0);
        $display("PASS: %0d mux selection checks", checks);
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
