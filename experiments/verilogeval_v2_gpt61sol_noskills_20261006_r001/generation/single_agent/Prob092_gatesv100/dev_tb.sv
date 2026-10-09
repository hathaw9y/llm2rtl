`timescale 1ns/1ps
module dev_tb;
    reg [99:0] in;
    wire [99:0] out_both, out_any, out_different;
    reg [99:0] pattern;
    integer i, j, checks;
    TopModule dut (.in(in), .out_both(out_both), .out_any(out_any),
                   .out_different(out_different));

    task check_pattern(input reg [99:0] value);
        reg [99:0] both_expected, any_expected, different_expected;
        integer k;
        begin
            in = value;
            for (k = 0; k < 100; k = k + 1) begin
                if (k == 99) both_expected[k] = 1'b0;
                else both_expected[k] = value[k] & value[k+1];
                if (k == 0) any_expected[k] = 1'b0;
                else any_expected[k] = value[k] | value[k-1];
                if (k == 99) different_expected[k] = value[k] ^ value[0];
                else different_expected[k] = value[k] ^ value[k+1];
            end
            #1;
            if (out_both !== both_expected || out_any !== any_expected ||
                out_different !== different_expected)
                $fatal(1, "Mismatch input=%h both=%h/%h any=%h/%h different=%h/%h",
                       value, out_both, both_expected, out_any, any_expected,
                       out_different, different_expected);
            checks = checks + 1;
        end
    endtask

    initial begin
        checks = 0;
        check_pattern(100'b0);
        check_pattern({100{1'b1}});
        check_pattern({50{2'b01}});
        check_pattern({50{2'b10}});
        for (i = 0; i < 100; i = i + 1) begin
            pattern = 0;
            pattern[i] = 1;
            check_pattern(pattern);
            check_pattern(~pattern);
        end
        for (i = 0; i < 99; i = i + 1) begin
            pattern = 0;
            pattern[i] = 1;
            pattern[i+1] = 1;
            check_pattern(pattern);
        end
        pattern = 0;
        pattern[99] = 1;
        pattern[0] = 1;
        check_pattern(pattern);
        for (i = 0; i < 500; i = i + 1) begin
            for (j = 0; j < 100; j = j + 1)
                pattern[j] = $random;
            check_pattern(pattern);
        end
        check_pattern({100{1'bx}});
        check_pattern({100{1'bz}});
        $display("PASS: %0d combinational patterns checked", checks);
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "Development test timeout");
    end
endmodule
