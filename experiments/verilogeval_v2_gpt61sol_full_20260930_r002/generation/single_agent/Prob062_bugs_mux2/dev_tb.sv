`timescale 1ns/1ps
module dev_tb;
    logic sel;
    logic [7:0] a, b;
    wire out;
    integer ai, bi, si;
    logic expected;
    TopModule dut (.sel(sel), .a(a), .b(b), .out(out));

    initial begin
        #200000;
        $fatal(1, "Timeout");
    end

    initial begin
        // Exhaust all binary input combinations. The original scalar output
        // retains bit zero of the selected 8-bit input.
        for (si = 0; si < 2; si = si + 1) begin
            for (ai = 0; ai < 256; ai = ai + 1) begin
                for (bi = 0; bi < 256; bi = bi + 1) begin
                    sel = (si == 1);
                    a = ai;
                    b = bi;
                    if (si == 0) expected = ai % 2;
                    else expected = bi % 2;
                    #1;
                    if (out !== expected)
                        $fatal(1, "sel=%b a=%h b=%h expected=%b got=%b", sel, a, b, expected, out);
                end
            end
        end
        $display("PASS exhaustive scalar mux checks");
        $finish;
    end
endmodule
