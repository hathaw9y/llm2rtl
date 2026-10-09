`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    wire [31:0] q;
    reg [31:0] expected;
    reg [31:0] held;
    integer cycles = 0;
    integer i;
    TopModule dut (.clk(clk), .reset(reset), .q(q));

    function automatic [31:0] next_state(input [31:0] old_state);
        integer bit_index;
        begin
            for (bit_index = 0; bit_index < 32; bit_index = bit_index + 1) begin
                if (bit_index == 31)
                    next_state[bit_index] = old_state[0];
                else if (bit_index == 21 || bit_index == 1 || bit_index == 0)
                    next_state[bit_index] = old_state[bit_index+1] ^ old_state[0];
                else
                    next_state[bit_index] = old_state[bit_index+1];
            end
        end
    endfunction

    task automatic tick;
        begin
            #4;
            if (reset) expected = 32'h1;
            else expected = next_state(expected);
            clk = 1;
            #1;
            cycles = cycles + 1;
            if (q !== expected)
                $fatal(1, "Cycle %0d: expected %h got %h", cycles, expected, q);
            held = q;
            #4 clk = 0;
            #1;
            if (q !== held) $fatal(1, "Output changed at falling edge");
        end
    endtask

    initial begin
        // No specified power-up number; only check that reset is synchronous.
        #1 held = q;
        reset = 1;
        #1;
        if (q !== held) $fatal(1, "Reset changed output without rising clock");
        tick();
        tick();
        reset = 0;
        #1;
        if (q !== 32'h1) $fatal(1, "Reset release changed output");
        tick();
        if (q !== 32'h80200003) $fatal(1, "Incorrect first seeded transition");
        for (i = 0; i < 4096; i = i + 1) tick();
        // Pulse reset entirely between rising edges: it must not reseed.
        held = q;
        reset = 1;
        #1;
        if (q !== held) $fatal(1, "Asynchronous reset detected");
        reset = 0;
        #1;
        if (q !== held) $fatal(1, "Inter-edge reset pulse affected state");
        tick();
        // Reset during a nontrivial sequence, then repeat seeded sequence.
        reset = 1;
        #1;
        if (q !== expected) $fatal(1, "Midstream reset acted asynchronously");
        tick();
        tick();
        reset = 0;
        for (i = 0; i < 1024; i = i + 1) tick();
        $display("PASS: %0d cycles, seeded recurrence and synchronous reset checks", cycles);
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "Bounded timeout");
    end
endmodule
