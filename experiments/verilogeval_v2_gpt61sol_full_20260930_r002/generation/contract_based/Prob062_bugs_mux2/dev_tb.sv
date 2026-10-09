`timescale 1ns/1ps
module dev_tb;
    reg sel;
    reg [7:0] a, b;
    wire out;
    reg expected;
    integer ai, bi, si;
    integer checks = 0;
    TopModule dut (.sel(sel), .a(a), .b(b), .out(out));

    task check_value(input reg value);
        begin
            #1;
            if (out !== value)
                $fatal(1, "Mismatch sel=%b a=%h b=%h expected=%b actual=%b", sel, a, b, value, out);
            checks = checks + 1;
        end
    endtask

    initial begin
        for (ai = 0; ai < 256; ai = ai + 1) begin
            for (bi = 0; bi < 256; bi = bi + 1) begin
                for (si = 0; si < 2; si = si + 1) begin
                    a = ai;
                    b = bi;
                    sel = si;
                    if (si == 0) expected = ai % 2;
                    else expected = bi % 2;
                    check_value(expected);
                end
            end
        end
        // Unknown bits in an unselected input must not contaminate the selected bit.
        sel = 0; a = 8'h01; b = 8'hxx; check_value(1'b1);
        sel = 1; a = 8'hxx; b = 8'h00; check_value(1'b0);
        sel = 0; a = 8'hxx; b = 8'h00; check_value(1'bx);
        sel = 1; a = 8'h00; b = 8'hzz; check_value(1'bz);
        // Standard conditional merge for unspecified four-state selector cases.
        sel = 1'bx; a = 8'h01; b = 8'hff; check_value(1'b1);
        sel = 1'bz; a = 8'hfe; b = 8'h00; check_value(1'b0);
        sel = 1'bx; a = 8'h00; b = 8'h01; check_value(1'bx);
        $display("PASS: %0d mux checks", checks);
        $finish;
    end
    initial begin
        #200000;
        $fatal(1, "Timeout");
    end
endmodule
