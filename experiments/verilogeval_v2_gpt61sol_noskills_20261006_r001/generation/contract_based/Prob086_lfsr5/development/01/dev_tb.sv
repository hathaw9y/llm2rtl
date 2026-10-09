`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    wire [4:0] q;
    reg [4:0] expected;
    reg [4:0] held;
    reg [31:0] seen;
    integer i;
    TopModule dut (.clk(clk), .reset(reset), .q(q));

    // Independent arithmetic oracle from the original Galois description.
    function automatic [4:0] advance(input [4:0] old_state);
        begin
            advance = old_state >> 1;
            if (old_state[0]) advance = advance ^ 5'b10100;
        end
    endfunction

    task automatic step(input reg reset_value);
        begin
            held = q;
            reset = reset_value;
            #2;
            if (q !== held) $fatal(1, "State changed without rising edge");
            if (reset_value) expected = 5'd1;
            else expected = advance(expected);
            clk = 1;
            #1;
            if (q !== expected)
                $fatal(1, "Expected %0d, got %0d", expected, q);
            clk = 0;
            #1;
            if (q !== expected) $fatal(1, "State changed on falling edge");
        end
    endtask

    initial begin
        // No assumption about power-up value; reset must take effect only at posedge.
        #1;
        step(1);
        step(1);
        step(1);
        seen = 32'b0;
        seen[1] = 1;
        for (i = 1; i <= 31; i = i + 1) begin
            step(0);
            if (q === 5'd0) $fatal(1, "Reached zero state");
            if (i == 1 && q !== 5'd20) $fatal(1, "Incorrect first tap transition");
            if (i < 31) begin
                if (seen[q]) $fatal(1, "State repeated before 31 transitions");
                seen[q] = 1;
            end else if (q !== 5'd1) $fatal(1, "Period is not 31");
        end
        if (seen !== 32'hfffffffe) $fatal(1, "Did not visit all nonzero states");
        for (i = 0; i < 62; i = i + 1) step(0);
        for (i = 0; i < 7; i = i + 1) step(0);
        step(1);
        step(0);
        if (q !== 5'd20) $fatal(1, "Reset did not restart sequence");
        step(1);
        step(1);
        for (i = 0; i < 31; i = i + 1) step(0);
        $display("PASS: synchronous reset, tap transitions, holds, and maximal 31-state cycles");
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
