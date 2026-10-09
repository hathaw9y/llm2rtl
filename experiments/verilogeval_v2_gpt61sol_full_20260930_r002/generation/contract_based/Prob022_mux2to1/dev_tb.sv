`timescale 1ns/1ps
module dev_tb;
    logic a, b, sel;
    wire out;
    integer checks = 0;
    TopModule dut (.a(a), .b(b), .sel(sel), .out(out));

    task automatic check_mux(input logic av, bv, sv);
        logic expected;
        begin
            a = av;
            b = bv;
            sel = sv;
            case (sv)
                1'b0: expected = av;
                1'b1: expected = bv;
                default: $fatal(1, "Test stimulus must use a known selector");
            endcase
            #1;
            if (out !== expected)
                $fatal(1, "Mux mismatch: a=%b b=%b sel=%b expected=%b got=%b", a, b, sel, expected, out);
            checks = checks + 1;
        end
    endtask

    initial begin
        for (integer repeat_index = 0; repeat_index < 3; repeat_index = repeat_index + 1)
            for (integer vector_index = 0; vector_index < 8; vector_index = vector_index + 1)
                check_mux(vector_index[2], vector_index[1], vector_index[0]);
        // Known selector must pass the selected value, independent of the other input.
        check_mux(1'b0, 1'bx, 1'b0);
        check_mux(1'b1, 1'bz, 1'b0);
        check_mux(1'bx, 1'b0, 1'b1);
        check_mux(1'bz, 1'b1, 1'b1);
        check_mux(1'bx, 1'b1, 1'b0);
        check_mux(1'bz, 1'b0, 1'b0);
        check_mux(1'b0, 1'bx, 1'b1);
        check_mux(1'b1, 1'bz, 1'b1);
        $display("PASS: %0d mux checks", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
