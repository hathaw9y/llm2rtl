`timescale 1ns/1ps
module dev_tb;
    reg sel;
    reg [7:0] a, b;
    wire [7:0] out;
    reg [7:0] expected;
    integer av, bv, sv, bit_index;
    integer checks = 0;
    TopModule dut (.sel(sel), .a(a), .b(b), .out(out));

    task verify;
        begin
            #1;
            // Independent per-bit truth table, including ambiguous select.
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                case (sel)
                    1'b0: expected[bit_index] = a[bit_index];
                    1'b1: expected[bit_index] = b[bit_index];
                    default: begin
                        if (a[bit_index] === b[bit_index])
                            expected[bit_index] = a[bit_index];
                        else expected[bit_index] = 1'bx;
                    end
                endcase
            end
            if (out !== expected)
                $fatal(1, "Mux mismatch sel=%b a=%b b=%b out=%b expected=%b", sel, a, b, out, expected);
            checks = checks + 1;
        end
    endtask

    initial begin
        for (av = 0; av < 256; av = av + 1)
            for (bv = 0; bv < 256; bv = bv + 1)
                for (sv = 0; sv < 2; sv = sv + 1) begin
                    a = av; b = bv; sel = sv;
                    verify;
                end
        a = 8'hA5; b = 8'hA5; sel = 1'bx; verify;
        a = 8'hA5; b = 8'h5A; sel = 1'bx; verify;
        a = 8'hF0; b = 8'hCC; sel = 1'bz; verify;
        a = 8'bxz010101; b = 8'hFF; sel = 0; verify;
        a = 8'h00; b = 8'b10xz1010; sel = 1; verify;
        $display("PASS: %0d mux checks", checks);
        $finish;
    end
    initial begin
        #200000;
        $fatal(1, "Timeout");
    end
endmodule
