`timescale 1ns/1ps
module dev_tb;
    logic [99:0] in;
    wire [99:0] out;
    logic [99:0] pattern;
    logic [31:0] random_state;
    integer cases_checked = 0;
    integer i, j;
    TopModule dut (.in(in), .out(out));

    task automatic check_current;
        logic [99:0] expected;
        integer k;
        begin
            expected = '0;
            // Read the original input from LSB to MSB, building reversed order.
            for (k = 0; k < 100; k = k + 1)
                expected = {expected[98:0], in[k]};
            if (out !== expected)
                $fatal(1, "Mismatch case %0d: in=%h out=%h expected=%h", cases_checked, in, out, expected);
            cases_checked = cases_checked + 1;
        end
    endtask

    task automatic apply_and_check(input logic [99:0] value);
        begin
            in = value;
            #1;
            check_current();
        end
    endtask

    initial begin
        #1;
        check_current(); // Uninitialized input is X, with no specified reset.
        apply_and_check(100'b0);
        apply_and_check({100{1'b1}});
        apply_and_check({50{2'b10}});
        apply_and_check({50{2'b01}});
        for (i = 0; i < 100; i = i + 1) begin
            pattern = '0;
            pattern[i] = 1'b1;
            apply_and_check(pattern);
            apply_and_check(~pattern);
        end
        random_state = 32'h137a5b9d;
        for (i = 0; i < 200; i = i + 1) begin
            for (j = 0; j < 100; j = j + 1) begin
                random_state = random_state ^ (random_state << 13);
                random_state = random_state ^ (random_state >> 17);
                random_state = random_state ^ (random_state << 5);
                pattern[j] = random_state[0];
            end
            apply_and_check(pattern);
        end
        for (i = 0; i < 100; i = i + 1) begin
            pattern = '0;
            pattern[i] = 1'bx;
            apply_and_check(pattern);
            pattern = '1;
            pattern[i] = 1'bz;
            apply_and_check(pattern);
        end
        $display("PASS bit reversal: %0d cases", cases_checked);
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
