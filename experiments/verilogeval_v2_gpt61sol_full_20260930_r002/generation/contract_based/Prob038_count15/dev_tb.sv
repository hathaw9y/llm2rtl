`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic reset = 1'b0;
    wire [3:0] q;
    integer expected = 0;
    integer checks = 0;
    bit known = 0;

    TopModule dut (.clk(clk), .reset(reset), .q(q));
    always #5 clk = ~clk;

    task automatic compare_output;
        begin
            if (q !== expected[3:0])
                $fatal(1, "Mismatch at %0t: q=%b expected=%0d reset=%b", $time, q, expected, reset);
            checks = checks + 1;
        end
    endtask

    // The original spec samples reset only on rising edges.
    always @(posedge clk) begin
        if (reset) begin
            expected = 0;
            known = 1;
        end else if (known) begin
            expected = (expected + 1) % 16;
        end
        #1;
        if (known) compare_output();
    end

    always @(negedge clk) begin
        #1;
        if (known) compare_output();
    end

    initial begin
        // No assertion about the unspecified power-up state.
        #2 reset = 1;
        #5;
        compare_output(); // Reset was sampled at t=5.
        @(negedge clk);
        #2 reset = 0;
        repeat (40) @(negedge clk);
        // Assert during a nonzero count and prove no asynchronous change.
        #2 reset = 1;
        #1 compare_output();
        repeat (3) @(negedge clk);
        #2 reset = 0;
        repeat (9) @(negedge clk);
        // Pulse lies completely between rising edges: it must not reset q.
        #1 reset = 1;
        #1 compare_output();
        #1 reset = 0;
        #1 compare_output();
        repeat (35) @(negedge clk);
        #2;
        compare_output();
        $display("PASS counter checks=%0d", checks);
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
