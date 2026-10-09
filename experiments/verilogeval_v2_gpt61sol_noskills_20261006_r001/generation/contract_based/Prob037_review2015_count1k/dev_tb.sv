`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    wire [9:0] q;
    integer expected;
    integer checks = 0;
    integer i;
    reg valid = 0;
    TopModule dut (.clk(clk), .reset(reset), .q(q));
    always #5 clk = ~clk;

    // The oracle follows the original specification, independently using modulo.
    always @(posedge clk) begin
        if (reset) begin
            expected = 0;
            valid = 1;
        end else if (valid) begin
            expected = (expected + 1) % 1000;
        end
        #1;
        if (valid) begin
            if (q !== expected)
                $fatal(1, "Edge mismatch: expected %0d, got %0d", expected, q);
            checks = checks + 1;
        end
    end

    task step(input reg reset_value);
        begin
            @(negedge clk);
            reset = reset_value;
            #1;
            if (valid && q !== expected)
                $fatal(1, "Output changed without positive edge: expected %0d, got %0d", expected, q);
            @(posedge clk);
            #2;
        end
    endtask

    initial begin
        step(1);
        repeat (3) step(1);
        repeat (3000) step(0);
        if (q !== 10'd0) $fatal(1, "Three complete periods did not end at zero");
        repeat (137) step(0);
        step(1);
        repeat (999) step(0);
        if (q !== 10'd999) $fatal(1, "Did not reach terminal count");
        step(1); // Reset coincides with the edge that otherwise would wrap.
        repeat (23) step(0);

        // Pulse reset entirely between rising edges. A synchronous reset must
        // leave q unchanged and must not reset the next count.
        @(negedge clk);
        #1; reset = 1;
        #1;
        if (q !== 10'd23) $fatal(1, "Reset asserted asynchronously");
        reset = 0;
        #1;
        if (q !== 10'd23) $fatal(1, "Between-edge pulse changed output");
        @(posedge clk);
        #2;
        if (q !== 10'd24) $fatal(1, "Between-edge reset pulse affected count");
        repeat (1000) step(0);
        if (q !== 10'd24) $fatal(1, "Period is not 1000 cycles");
        step(1);
        step(0);
        if (q !== 10'd1) $fatal(1, "Reset release did not count immediately");
        $display("PASS: modulo-1000 counter, synchronous reset, %0d edge checks", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Timeout");
    end
endmodule
