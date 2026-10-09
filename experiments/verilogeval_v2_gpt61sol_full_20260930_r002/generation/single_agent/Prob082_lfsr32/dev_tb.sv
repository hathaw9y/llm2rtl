`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    wire [31:0] q;
    logic [31:0] expected;
    logic [31:0] held;
    integer cycles = 0;
    integer feedback_zero = 0;
    integer feedback_one = 0;
    TopModule dut (.clk(clk), .reset(reset), .q(q));
    always #5 clk = ~clk;

    // Independent positional model: taps are numbered 1 through 32.
    function automatic [31:0] advance(input [31:0] state);
        integer position;
        reg shifted_bit;
        begin
            for (position = 1; position <= 32; position = position + 1) begin
                if (position == 32) shifted_bit = 1'b0;
                else shifted_bit = state[position];
                if (position == 32 || position == 22 ||
                    position == 2 || position == 1)
                    advance[position-1] = shifted_bit ^ state[0];
                else advance[position-1] = shifted_bit;
            end
        end
    endfunction

    task automatic check_edge;
        begin
            @(posedge clk);
            if (reset) expected = 32'h1;
            else begin
                if (expected[0]) feedback_one = feedback_one + 1;
                else feedback_zero = feedback_zero + 1;
                expected = advance(expected);
            end
            #1;
            cycles = cycles + 1;
            if (q !== expected)
                $fatal(1, "cycle %0d expected %08h got %08h", cycles, expected, q);
        end
    endtask

    initial begin
        // No initial state is specified; establish it with synchronous reset.
        #2 reset = 1;
        check_edge();
        check_edge();
        @(negedge clk);
        reset = 0;
        #1;
        if (q !== 32'h1) $fatal(1, "reset release changed state without posedge");
        check_edge();
        if (q !== 32'h80200003) $fatal(1, "first transition has wrong taps");
        repeat (4096) check_edge();

        // Assert reset between edges while the register has a non-seed state.
        @(negedge clk);
        held = q;
        #2 reset = 1;
        #1;
        if (q !== held) $fatal(1, "reset was asynchronous");
        check_edge();
        repeat (3) check_edge();
        @(negedge clk);
        reset = 0;
        repeat (1024) check_edge();
        if (feedback_zero == 0 || feedback_one == 0)
            $fatal(1, "feedback branches not covered");
        $display("PASS LFSR sequence and synchronous reset: %0d cycles", cycles);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "timeout");
    end
endmodule
