`timescale 1ns/1ps
module dev_tb;
    logic sel;
    logic [7:0] a, b;
    wire [7:0] out;
    integer ai, bi, si;
    integer checks = 0;
    TopModule dut (.sel(sel), .a(a), .b(b), .out(out));
    initial begin
        for (si = 0; si < 2; si = si + 1) begin
            for (ai = 0; ai < 256; ai = ai + 1) begin
                for (bi = 0; bi < 256; bi = bi + 1) begin
                    sel = si[0]; a = ai[7:0]; b = bi[7:0];
                    #1;
                    if (out !== (si == 0 ? a : b))
                        $fatal(1, "FAIL sel=%b a=%h b=%h out=%h", sel, a, b, out);
                    checks = checks + 1;
                end
            end
        end
        $display("PASS: %0d exhaustive binary input checks", checks);
        $finish;
    end
    initial begin
        #200000;
        $fatal(1, "FAIL: simulation timeout");
    end
endmodule
