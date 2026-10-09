module dev_tb;
    logic [254:0] in;
    wire [7:0] out;
    logic [254:0] pattern;
    logic [31:0] prng;
    integer checks = 0;
    integer i, j, n;
    TopModule dut (.in(in), .out(out));

    task automatic check(input logic [254:0] value);
        logic [254:0] remaining;
        integer expected;
        begin
            remaining = value;
            expected = 0;
            while (remaining != 255'd0) begin
                if (remaining[0]) expected = expected + 1;
                remaining = remaining >> 1;
            end
            in = value;
            #1;
            if (out !== expected[7:0]) begin
                $display("FAIL check=%0d expected=%0d got=%0d input=%h", checks, expected, out, value);
                $fatal(1);
            end
            checks = checks + 1;
        end
    endtask

    initial begin
        check('0);
        check('1);
        for (i = 0; i < 255; i = i + 1) begin
            pattern = '0;
            pattern[i] = 1'b1;
            check(pattern);
            check(~pattern);
        end
        for (i = 0; i < 255; i = i + 1) pattern[i] = (i % 2 == 0);
        check(pattern);
        check(~pattern);
        for (n = 0; n <= 255; n = n + 1) begin
            pattern = '0;
            for (j = 0; j < n; j = j + 1) pattern[j] = 1'b1;
            check(pattern);
        end
        prng = 32'h51a7c039;
        for (n = 0; n < 1000; n = n + 1) begin
            for (j = 0; j < 255; j = j + 1) begin
                prng = prng ^ (prng << 13);
                prng = prng ^ (prng >> 17);
                prng = prng ^ (prng << 5);
                pattern[j] = prng[0];
            end
            check(pattern);
        end
        $display("PASS: %0d population-count checks", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "FAIL: development timeout");
    end
endmodule
