`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    wire [4:0] q;
    integer expected;
    integer old_expected;
    integer seen;
    integer i;
    integer checks = 0;
    TopModule dut (.clk(clk), .reset(reset), .q(q));
    always #5 clk = ~clk;

    task automatic compare(input integer value);
        begin
            if (q !== value[4:0])
                $fatal(1, "Mismatch at %0t: q=%b expected=%b", $time, q, value[4:0]);
            checks = checks + 1;
        end
    endtask

    task automatic step(input logic reset_value);
        begin
            @(negedge clk);
            old_expected = expected;
            reset = reset_value;
            #1;
            compare(old_expected);
            @(posedge clk);
            if (reset_value)
                expected = 1;
            else begin
                expected = old_expected / 2;
                if (old_expected % 2 == 1)
                    expected = expected ^ 20;
            end
            #1;
            compare(expected);
        end
    endtask

    initial begin
        // The original problem leaves power-up unspecified; first establish seed.
        #2 reset = 1;
        @(posedge clk);
        expected = 1;
        #1 compare(expected);
        step(1);
        step(1);

        // Exactly 31 unique nonzero states, returning to the reset seed.
        seen = 0;
        for (i = 0; i < 31; i = i + 1) begin
            if (expected == 0 || ((seen >> expected) & 1) != 0)
                $fatal(1, "Zero or early repeat in maximal-length cycle: %0d", expected);
            seen = seen | (1 << expected);
            step(0);
        end
        if (expected != 1 || seen !== 32'hfffffffe)
            $fatal(1, "Incorrect period/state coverage: expected=%0d seen=%h", expected, seen);
        for (i = 0; i < 62; i = i + 1) step(0);

        // A reset pulse between positive edges must not alter the state.
        step(0);
        @(negedge clk);
        #1 reset = 1;
        #1 compare(expected);
        reset = 0;
        #1 compare(expected);
        @(posedge clk);
        old_expected = expected;
        expected = old_expected / 2;
        if (old_expected % 2 == 1) expected = expected ^ 20;
        #1 compare(expected);

        // Reset during activity, hold it, then confirm restart.
        step(1);
        step(1);
        for (i = 0; i < 31; i = i + 1) step(0);
        $display("PASS: LFSR sequence, period, synchronous reset and edge stability (%0d checks)", checks);
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
