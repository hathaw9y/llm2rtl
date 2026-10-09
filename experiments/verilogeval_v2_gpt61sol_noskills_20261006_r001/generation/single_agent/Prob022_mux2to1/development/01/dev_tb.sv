`timescale 1ns/1ps
module dev_tb;
    reg a, b, sel;
    wire out;
    integer i;
    integer checks = 0;
    TopModule dut (.a(a), .b(b), .sel(sel), .out(out));

    task check_mux;
        input reg av, bv, sv, expected;
        begin
            a = av;
            b = bv;
            sel = sv;
            #1;
            if (out !== expected)
                $fatal(1, "Mux mismatch a=%b b=%b sel=%b out=%b expected=%b", a, b, sel, out, expected);
            checks = checks + 1;
        end
    endtask

    initial begin
        // Explicit truth-table oracle: index bits are {sel, b, a}.
        for (i = 0; i < 8; i = i + 1) begin
            case (i)
                0: check_mux(0, 0, 0, 0);
                1: check_mux(1, 0, 0, 1);
                2: check_mux(0, 1, 0, 0);
                3: check_mux(1, 1, 0, 1);
                4: check_mux(0, 0, 1, 0);
                5: check_mux(1, 0, 1, 0);
                6: check_mux(0, 1, 1, 1);
                7: check_mux(1, 1, 1, 1);
            endcase
        end
        check_mux(0, 1'bx, 0, 0);
        check_mux(1, 1'bz, 0, 1);
        check_mux(1'bx, 0, 1, 0);
        check_mux(1'bz, 1, 1, 1);
        check_mux(1'bx, 0, 0, 1'bx);
        check_mux(1'bz, 0, 0, 1'bz);
        check_mux(0, 1'bx, 1, 1'bx);
        check_mux(0, 1'bz, 1, 1'bz);
        $display("PASS mux: %0d checks", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Testbench timeout");
    end
endmodule
