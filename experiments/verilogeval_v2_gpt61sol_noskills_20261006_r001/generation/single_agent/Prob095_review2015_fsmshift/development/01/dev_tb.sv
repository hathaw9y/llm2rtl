`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    wire shift_ena;
    integer remaining = 0;
    integer checks = 0;
    reg initialized = 0;
    reg expected;
    TopModule dut (.clk(clk), .reset(reset), .shift_ena(shift_ena));
    always #5 clk = ~clk;

    // Independent oracle: reset starts four enabled clock periods.
    always @(posedge clk) begin
        if (reset) begin
            remaining = 4;
            initialized = 1;
        end else if (initialized && remaining > 0) begin
            remaining = remaining - 1;
        end
        #1;
        if (initialized) begin
            expected = (remaining > 0);
            if (shift_ena !== expected)
                $fatal(1, "Edge check at %0t: remaining=%0d expected=%b actual=%b",
                       $time, remaining, expected, shift_ena);
            checks = checks + 1;
        end
    end

    task check_between_edges;
        begin
            #1;
            if (shift_ena !== (remaining > 0))
                $fatal(1, "Output changed between edges at %0t", $time);
            checks = checks + 1;
        end
    endtask

    initial begin
        // No specified initial value: begin checking only after reset.
        @(negedge clk); reset = 1;
        @(negedge clk); reset = 0;
        repeat (12) @(negedge clk);

        // A pulse wholly between positive edges must not restart the FSM.
        reset = 1;
        check_between_edges;
        reset = 0;
        check_between_edges;
        repeat (3) @(negedge clk);

        // Repeated synchronous reset holds the start of the four-cycle run.
        reset = 1;
        repeat (3) @(negedge clk);
        reset = 0;
        repeat (2) @(negedge clk);

        // Restart while enabled.
        reset = 1;
        @(negedge clk); reset = 0;
        repeat (4) @(negedge clk);

        // Restart at the completion boundary, then verify permanent idle.
        reset = 1;
        @(negedge clk); reset = 0;
        repeat (40) @(negedge clk);
        if (checks < 60) $fatal(1, "Insufficient checks");
        $display("PASS: %0d synchronous reset and four-cycle checks", checks);
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
