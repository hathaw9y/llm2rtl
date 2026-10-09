`timescale 1ns/1ps
module dev_tb;
    reg sel;
    reg [7:0] a, b;
    wire out;
    integer av, bv, sv;
    integer checks = 0;
    reg expected;
    TopModule dut(.sel(sel), .a(a), .b(b), .out(out));

    task check_output(input reg want);
        begin
            #1;
            if (out !== want)
                $fatal(1, "sel=%b a=%h b=%h expected=%b got=%b", sel, a, b, want, out);
            checks = checks + 1;
        end
    endtask

    initial begin
        // Undriven regs start unknown; no reset or initialization is specified.
        check_output(1'bx);
        for (sv = 0; sv < 2; sv = sv + 1) begin
            sel = sv;
            for (av = 0; av < 256; av = av + 1) begin
                a = av;
                for (bv = 0; bv < 256; bv = bv + 1) begin
                    b = bv;
                    if (sv == 0) expected = av % 2;
                    else expected = bv % 2;
                    check_output(expected);
                end
            end
        end
        sel = 1'bx; a = 8'hfe; b = 8'h00; check_output(1'b0);
        sel = 1'bz; a = 8'h01; b = 8'hff; check_output(1'b1);
        sel = 1'bx; a = 8'h00; b = 8'h01; check_output(1'bx);
        sel = 0; a = 8'hff; b = 8'hxx; check_output(1'b1);
        sel = 1; a = 8'hxx; b = 8'h00; check_output(1'b0);
        $display("PASS: %0d mux checks", checks);
        $finish;
    end
    initial begin
        #200000;
        $fatal(1, "Timeout");
    end
endmodule
