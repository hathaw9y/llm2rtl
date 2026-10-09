module dev_tb;
    logic [7:0] a, b, c, d;
    wire [7:0] min;
    integer checks = 0;
    integer i, j;
    logic [31:0] rng = 32'h9357abcd;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .min(min));

    task automatic check(input integer av, bv, cv, dv);
        integer values [0:3];
        integer expected, k;
        begin
            values[0] = av;
            values[1] = bv;
            values[2] = cv;
            values[3] = dv;
            expected = 255;
            for (k = 0; k < 4; k = k + 1)
                if (values[k] < expected) expected = values[k];
            a = av; b = bv; c = cv; d = dv;
            #1;
            if (min !== expected[7:0])
                $fatal(1, "FAIL a=%0d b=%0d c=%0d d=%0d expected=%0d actual=%0d", av, bv, cv, dv, expected, min);
            checks = checks + 1;
        end
    endtask

    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            check(i, i, i, i);
            if (i < 255) begin
                check(i, 255, 255, 255);
                check(255, i, 255, 255);
                check(255, 255, i, 255);
                check(255, 255, 255, i);
            end
            check(i, i, 255, 255);
            check(255, i, i, 255);
            check(255, 255, i, i);
        end
        check(128, 127, 254, 255);
        check(255, 254, 128, 127);
        check(0, 255, 128, 127);
        for (i = 0; i < 256; i = i + 1)
            for (j = 0; j < 256; j = j + 1)
                check(i, j, 255, 255);
        for (i = 0; i < 10000; i = i + 1) begin
            rng = rng ^ (rng << 13);
            rng = rng ^ (rng >> 17);
            rng = rng ^ (rng << 5);
            check({24'b0, rng[7:0]}, {24'b0, rng[15:8]},
                  {24'b0, rng[23:16]}, {24'b0, rng[31:24]});
        end
        $display("PASS checks=%0d", checks);
        $finish;
    end
    initial begin
        #1000000;
        $fatal(1, "FAIL simulation timeout");
    end
endmodule
