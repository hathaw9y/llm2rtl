`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    wire [4:0] q;
    integer expected;
    integer seen;
    integer i;
    logic [4:0] held;
    TopModule dut (.clk(clk), .reset(reset), .q(q));

    // Independent integer model: shift, then XOR the tap mask if LSB was one.
    task automatic tick;
        begin
            #4;
            if (reset) expected = 1;
            else if ((expected & 1) != 0)
                expected = (expected >> 1) ^ 20;
            else expected = expected >> 1;
            clk = 1;
            #1;
            if (q !== expected[4:0])
                $fatal(1, "state mismatch: expected %0d got %b", expected, q);
            #4;
            clk = 0;
            #1;
            if (q !== expected[4:0])
                $fatal(1, "state changed on falling edge");
        end
    endtask

    initial begin
        expected = 1;
        reset = 1;
        tick();
        tick();
        reset = 0;
        seen = 0;
        for (i = 0; i < 31; i = i + 1) begin
            if (q == 0) $fatal(1, "zero state reached");
            if ((seen & (1 << q)) != 0)
                $fatal(1, "state repeated before 31 states");
            seen = seen | (1 << q);
            tick();
        end
        if (q !== 5'd1 || seen !== 32'hfffffffe)
            $fatal(1, "maximal-length period check failed");
        // Exercise two more full periods.
        repeat (62) tick();
        repeat (7) tick();
        held = q;
        #1 reset = 1;
        #1;
        if (q !== held) $fatal(1, "reset acted asynchronously");
        tick();
        tick();
        // Reset transitions while clock is high must also leave state alone.
        clk = 1;
        #1;
        if (q !== 5'd1) $fatal(1, "reset seed mismatch");
        reset = 0;
        #1;
        if (q !== 5'd1) $fatal(1, "deassertion changed state");
        reset = 1;
        #1;
        if (q !== 5'd1) $fatal(1, "assertion changed state");
        clk = 0;
        reset = 0;
        repeat (31) tick();
        $display("PASS: LFSR sequence, period, edge stability and synchronous reset");
        $finish;
    end

    initial begin
        #5000;
        $fatal(1, "timeout");
    end
endmodule
