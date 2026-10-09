module dev_tb;
    logic [99:0] in;
    wire [99:0] out;
    logic [99:0] pattern;
    integer checks = 0;
    TopModule dut (.in(in), .out(out));

    task automatic check(input logic [99:0] value);
        logic [99:0] expected;
        integer source;
        begin
            expected = '0;
            for (source = 99; source >= 0; source = source - 1)
                expected = {value[source], expected[99:1]};
            in = value;
            #1;
            if (out !== expected)
                $fatal(1, "FAIL input=%h expected=%h actual=%h", value, expected, out);
            checks = checks + 1;
        end
    endtask

    initial begin
        check('0);
        check('1);
        check({50{2'b10}});
        check({50{2'b01}});
        for (integer bit_index = 0; bit_index < 100; bit_index = bit_index + 1) begin
            pattern = '0;
            pattern[bit_index] = 1'b1;
            check(pattern);
            check(~pattern);
        end
        for (integer trial = 0; trial < 1000; trial = trial + 1) begin
            for (integer bit_index = 0; bit_index < 100; bit_index = bit_index + 1)
                pattern[bit_index] = $urandom_range(0, 1);
            check(pattern);
        end
        pattern = {25{4'b10xz}};
        check(pattern);
        $display("PASS: %0d bit-reversal checks", checks);
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "FAIL: development timeout");
    end
endmodule
