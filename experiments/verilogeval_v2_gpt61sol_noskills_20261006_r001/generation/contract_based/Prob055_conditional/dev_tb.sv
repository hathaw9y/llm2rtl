`timescale 1ns/1ps
module dev_tb;
    reg [7:0] a, b, c, d;
    wire [7:0] min;
    integer checks = 0;
    integer x, y, p, q, n;
    reg [7:0] values [0:3];
    reg [31:0] rng = 32'h73519ace;
    TopModule dut(.a(a), .b(b), .c(c), .d(d), .min(min));

    task automatic check(input [7:0] va, vb, vc, vd);
        integer expected;
        begin
            a = va; b = vb; c = vc; d = vd;
            expected = va;
            if (vb < expected) expected = vb;
            if (vc < expected) expected = vc;
            if (vd < expected) expected = vd;
            #1;
            if (min !== expected[7:0])
                $fatal(1, "minimum mismatch: %0d %0d %0d %0d -> %0d expected %0d",
                       a, b, c, d, min, expected);
            checks = checks + 1;
        end
    endtask

    initial begin
        check(0, 255, 128, 127);
        check(255, 128, 127, 0);
        check(255, 255, 255, 255);
        check(128, 129, 254, 255);
        check(127, 128, 129, 255);
        for (x = 0; x < 256; x = x + 1) begin
            check(x, x, x, x);
            for (p = 0; p < 4; p = p + 1) begin
                values[0] = 255; values[1] = 255;
                values[2] = 255; values[3] = 255;
                values[p] = x;
                check(values[0], values[1], values[2], values[3]);
            end
        end
        // Exhaust every pair of positions and both 8-bit values.
        for (p = 0; p < 4; p = p + 1)
            for (q = p + 1; q < 4; q = q + 1)
                for (x = 0; x < 256; x = x + 1)
                    for (y = 0; y < 256; y = y + 1) begin
                        values[0] = 255; values[1] = 255;
                        values[2] = 255; values[3] = 255;
                        values[p] = x; values[q] = y;
                        check(values[0], values[1], values[2], values[3]);
                    end
        for (n = 0; n < 10000; n = n + 1) begin
            rng = rng ^ (rng << 13);
            rng = rng ^ (rng >> 17);
            rng = rng ^ (rng << 5);
            check(rng[7:0], rng[15:8], rng[23:16], rng[31:24]);
        end
        $display("PASS: %0d unsigned minimum checks", checks);
        $finish;
    end
    initial begin
        #500000;
        $fatal(1, "Timeout");
    end
endmodule
