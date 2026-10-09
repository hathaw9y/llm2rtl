`timescale 1ns/1ps
module dev_tb;
    reg [3:0] stimulus;
    wire [3:0] out_both, out_any, out_different;
    integer pattern, digit, bit_index, checks;
    TopModule dut(.in(stimulus), .out_both(out_both),
                  .out_any(out_any), .out_different(out_different));

    task check_relationships;
        integer i;
        reg expected;
        begin
            for (i = 0; i < 3; i = i + 1) begin
                expected = stimulus[i] & stimulus[i+1];
                if (out_both[i] !== expected)
                    $fatal(1, "out_both[%0d]: input=%b got=%b expected=%b",
                           i, stimulus, out_both[i], expected);
            end
            for (i = 1; i < 4; i = i + 1) begin
                expected = stimulus[i] | stimulus[i-1];
                if (out_any[i] !== expected)
                    $fatal(1, "out_any[%0d]: input=%b got=%b expected=%b",
                           i, stimulus, out_any[i], expected);
            end
            for (i = 0; i < 4; i = i + 1) begin
                if (i == 3)
                    expected = stimulus[3] ^ stimulus[0];
                else
                    expected = stimulus[i] ^ stimulus[i+1];
                if (out_different[i] !== expected)
                    $fatal(1, "out_different[%0d]: input=%b got=%b expected=%b",
                           i, stimulus, out_different[i], expected);
            end
            checks = checks + 1;
        end
    endtask

    initial begin
        checks = 0;
        // Includes all-zero, all-one, isolated bits, and alternating boundaries.
        for (pattern = 0; pattern < 16; pattern = pattern + 1) begin
            stimulus = pattern;
            #1;
            check_relationships;
        end
        // Additional checks of conventional four-state bitwise semantics.
        for (pattern = 0; pattern < 256; pattern = pattern + 1) begin
            digit = pattern;
            for (bit_index = 0; bit_index < 4; bit_index = bit_index + 1) begin
                case (digit % 4)
                    0: stimulus[bit_index] = 1'b0;
                    1: stimulus[bit_index] = 1'b1;
                    2: stimulus[bit_index] = 1'bx;
                    3: stimulus[bit_index] = 1'bz;
                endcase
                digit = digit / 4;
            end
            #1;
            check_relationships;
        end
        $display("PASS: %0d input patterns checked", checks);
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "Development test timeout");
    end
endmodule
