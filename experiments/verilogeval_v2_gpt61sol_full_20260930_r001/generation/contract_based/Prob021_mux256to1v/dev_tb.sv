`timescale 1ns/1ps
module dev_tb;
    logic [1023:0] in;
    logic [7:0] sel;
    wire [3:0] out;
    integer checks = 0;
    integer s, p, r, j, k;
    TopModule dut (.in(in), .sel(sel), .out(out));

    task automatic check;
        logic [3:0] expected;
        integer b;
        begin
            #1;
            for (b = 0; b < 4; b = b + 1)
                expected[b] = in[4 * integer'(sel) + b];
            if (out !== expected)
                $fatal(1, "FAIL sel=%0d actual=%h expected=%h", sel, out, expected);
            checks = checks + 1;
        end
    endtask

    initial begin
        in = '0;
        for (s = 0; s < 256; s = s + 1) begin
            sel = s;
            check();
        end
        in = '1;
        for (s = 0; s < 256; s = s + 1) begin
            sel = s;
            check();
        end
        for (r = 0; r < 16; r = r + 1) begin
            for (j = 0; j < 32; j = j + 1)
                in[j*32 +: 32] = $urandom;
            for (s = 0; s < 256; s = s + 1) begin
                sel = s;
                check();
            end
        end
        for (s = 0; s < 256; s = s + 1) begin
            sel = s;
            in = {256{4'ha}};
            for (p = 0; p < 16; p = p + 1) begin
                for (k = 0; k < 4; k = k + 1)
                    in[4*s+k] = (p >> k) & 1;
                check();
            end
        end
        for (j = 0; j < 1024; j = j + 1) begin
            in = '0;
            in[j] = 1'b1;
            sel = j / 4;
            check();
            sel = ((j / 4) + 1) % 256;
            check();
        end
        $display("PASS: %0d independent mux comparisons", checks);
        $finish;
    end
    initial begin
        #20000;
        $fatal(1, "FAIL: development test timeout");
    end
endmodule
