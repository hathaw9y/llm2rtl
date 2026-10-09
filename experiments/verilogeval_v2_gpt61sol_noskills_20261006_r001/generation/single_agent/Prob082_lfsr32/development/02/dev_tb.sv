`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    wire [31:0] q;
    reg [31:0] expected;
    reg [31:0] held;
    integer cycle;
    TopModule dut (.clk(clk), .reset(reset), .q(q));
    always #5 clk = ~clk;

    // Independently describe each destination bit using one-based taps.
    function automatic [31:0] advance(input [31:0] previous);
        integer position;
        reg incoming;
        begin
            for (position = 1; position <= 32; position = position + 1) begin
                if (position == 32) incoming = 1'b0;
                else incoming = previous[position];
                if (position == 32 || position == 22 || position == 2 || position == 1)
                    advance[position-1] = incoming ^ previous[0];
                else
                    advance[position-1] = incoming;
            end
        end
    endfunction

    task automatic check_state;
        begin
            if (q !== expected)
                $fatal(1, "State mismatch cycle=%0d expected=%h actual=%h", cycle, expected, q);
        end
    endtask

    initial begin
        // Assert reset between clock edges and establish the seed at a rising edge.
        #2 reset = 1;
        @(posedge clk); #1;
        expected = 32'h1;
        cycle = 0;
        check_state();
        @(negedge clk); #1;
        check_state();
        // Holding reset must keep the seed at every active clock edge.
        repeat (3) begin
            @(posedge clk); #1; check_state();
        end
        @(negedge clk); #1 reset = 0;
        @(posedge clk); #1;
        expected = 32'h80200003;
        cycle = 1;
        check_state();
        for (cycle = 2; cycle <= 2048; cycle = cycle + 1) begin
            @(negedge clk); #1; check_state();
            // Reset pulses between rising edges must not change state.
            if (cycle % 113 == 0) begin
                held = q;
                reset = 1;
                #1;
                if (q !== held) $fatal(1, "Reset acted asynchronously");
                reset = 0;
            end
            // Exercise synchronous resets in the middle of the sequence.
            if (cycle % 257 == 0) reset = 1;
            if (reset) expected = 32'h1;
            else expected = advance(expected);
            @(posedge clk); #1; check_state();
            if (reset) begin
                #1;
                reset = 0;
                check_state();
            end
        end
        $display("PASS: LFSR sequence, tap mapping, synchronous reset, and edge stability");
        $finish;
    end
    initial begin
        #50000;
        $fatal(1, "Timeout");
    end
endmodule
