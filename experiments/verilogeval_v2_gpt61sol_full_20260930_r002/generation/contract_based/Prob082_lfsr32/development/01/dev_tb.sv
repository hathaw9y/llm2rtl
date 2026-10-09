`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    wire [31:0] q;
    logic [31:0] expected;
    logic [31:0] prior;
    logic [31:0] seen_one = 0;
    logic [31:0] seen_zero = 0;
    bit seen_feedback_zero = 0;
    bit seen_feedback_one = 0;
    integer checks = 0;
    TopModule dut (.clk(clk), .reset(reset), .q(q));

    // Original Galois rule, evaluated individually by one-based position.
    function automatic [31:0] advance(input [31:0] state);
        integer position;
        reg shifted;
        begin
            for (position = 1; position <= 32; position = position + 1) begin
                if (position == 32) shifted = 1'b0;
                else shifted = state[position];
                if (position == 32 || position == 22 || position == 2 || position == 1)
                    advance[position-1] = shifted ^ state[0];
                else
                    advance[position-1] = shifted;
            end
        end
    endfunction

    task automatic check(input [31:0] value);
        begin
            if (q !== value)
                $fatal(1, "Mismatch at %0t: q=%h expected=%h", $time, q, value);
            checks = checks + 1;
        end
    endtask

    task automatic cycle(input bit reset_value);
        begin
            reset = reset_value;
            prior = q;
            #2;
            check(prior); // Reset assertion itself must not change q.
            if (reset_value) expected = 32'h1;
            else begin
                if (expected[0]) seen_feedback_one = 1;
                else seen_feedback_zero = 1;
                expected = advance(expected);
            end
            clk = 1;
            #1;
            check(expected);
            seen_one = seen_one | q;
            seen_zero = seen_zero | ~q;
            #2;
            clk = 0;
            #1;
            check(expected); // Falling edge must not update state.
        end
    endtask

    initial begin
        // No assumption about the unspecified state before reset.
        #1;
        cycle(1);
        cycle(1);
        cycle(0);
        check(32'h80200003); // Directed first feedback step from seed.
        cycle(0);
        check(32'hc0300002);
        repeat (4096) cycle(0);
        // Pulse reset wholly between positive edges: state must hold.
        prior = q;
        reset = 1;
        #1;
        check(prior);
        reset = 0;
        #1;
        check(prior);
        cycle(0);
        cycle(1); // Reset in an active sequence.
        cycle(1);
        repeat (128) cycle(0);
        if (seen_one !== 32'hffffffff || seen_zero !== 32'hffffffff)
            $fatal(1, "Insufficient per-bit state coverage");
        if (!seen_feedback_one || !seen_feedback_zero)
            $fatal(1, "Insufficient feedback coverage");
        $display("PASS: Galois recurrence, synchronous reset and edge stability (%0d checks)", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Timeout");
    end
endmodule
