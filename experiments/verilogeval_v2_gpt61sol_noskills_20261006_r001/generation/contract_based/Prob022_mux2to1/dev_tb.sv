`timescale 1ns/1ps
module dev_tb;
    reg a, b, sel;
    wire out;
    integer i;
    integer checks = 0;
    TopModule dut (.a(a), .b(b), .sel(sel), .out(out));

    task automatic check_mux(input reg av, input reg bv, input reg sv);
        reg expected;
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
                $fatal(1, "Mux mismatch: a=%b b=%b sel=%b out=%b expected=%b", a, b, sel, out, expected);
            checks = checks + 1;
        end
    endtask

    initial begin
        for (i = 0; i < 8; i = i + 1)
            check_mux(i[2], i[1], i[0]);
        for (i = 7; i >= 0; i = i - 1)
            check_mux(i[2], i[1], i[0]);
        // Known selectors must propagate selected data and ignore unselected data.
        check_mux(1'bx, 1'b0, 1'b0);
        check_mux(1'bz, 1'b1, 1'b0);
        check_mux(1'b0, 1'bx, 1'b1);
        check_mux(1'b1, 1'bz, 1'b1);
        check_mux(1'b0, 1'bx, 1'b0);
        check_mux(1'b1, 1'bz, 1'b0);
        check_mux(1'bx, 1'b0, 1'b1);
        check_mux(1'bz, 1'b1, 1'b1);
        $display("PASS mux: %0d checks", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
