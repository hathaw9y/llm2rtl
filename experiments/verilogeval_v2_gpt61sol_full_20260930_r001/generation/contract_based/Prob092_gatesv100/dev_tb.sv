module dev_tb;
    logic [99:0] in;
    wire [99:0] out_both, out_any, out_different;
    logic [99:0] pattern;
    logic [31:0] prng = 32'h92a10001;
    integer checks = 0;
    TopModule dut (.in(in), .out_both(out_both), .out_any(out_any), .out_different(out_different));

    task automatic check(input logic [99:0] value);
        logic [99:0] both_expected, any_expected, different_expected;
        begin
            in = value;
            for (integer i = 0; i < 100; i = i + 1) begin
                if (i == 99) both_expected[i] = 1'b0;
                else both_expected[i] = value[i] & value[i+1];
                if (i == 0) any_expected[i] = 1'b0;
                else any_expected[i] = value[i] | value[i-1];
                different_expected[i] = value[i] ^ value[(i+1)%100];
            end
            #1;
            if (out_both !== both_expected || out_any !== any_expected || out_different !== different_expected)
                $fatal(1, "FAIL input=%h both=%h any=%h different=%h", value, out_both, out_any, out_different);
            checks = checks + 1;
        end
    endtask

    initial begin
        check('0);
        check('1);
        for (integer i = 0; i < 100; i = i + 1) pattern[i] = (i%2);
        check(pattern);
        check(~pattern);
        for (integer i = 0; i < 100; i = i + 1) begin
            pattern = '0;
            pattern[i] = 1'b1;
            check(pattern);
            check(~pattern);
        end
        for (integer i = 0; i < 100; i = i + 1) begin
            for (integer pair_value = 0; pair_value < 4; pair_value = pair_value + 1) begin
                pattern = '0;
                pattern[i] = pair_value[0];
                pattern[(i+1)%100] = pair_value[1];
                check(pattern);
            end
        end
        for (integer trial = 0; trial < 1000; trial = trial + 1) begin
            for (integer i = 0; i < 100; i = i + 1) begin
                prng = prng ^ (prng << 13);
                prng = prng ^ (prng >> 17);
                prng = prng ^ (prng << 5);
                pattern[i] = prng[0];
            end
            check(pattern);
        end
        $display("PASS: %0d input vectors, all 300 output bits checked per vector", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "FAIL: development simulation timeout");
    end
endmodule
