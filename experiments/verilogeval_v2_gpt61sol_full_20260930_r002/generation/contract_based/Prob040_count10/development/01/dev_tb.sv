`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic reset = 1'b0;
    wire [3:0] q;
    integer expected = 0;
    integer checks = 0;
    bit established = 0;
    integer target;
    TopModule dut (.clk(clk), .reset(reset), .q(q));
    always #5 clk = ~clk;

    task automatic check_q;
        if (established) begin
            if (q !== expected[3:0])
                $fatal(1, "Mismatch at %0t: q=%b expected=%0d reset=%b", $time, q, expected, reset);
            checks = checks + 1;
        end
    endtask

    // Integer modulo oracle uses only original sequence and sampled reset.
    always @(posedge clk) begin
        if (reset) begin
            expected = 0;
            established = 1;
        end else if (established) begin
            expected = (expected + 1) % 10;
        end
        #1;
        check_q();
    end
    always @(negedge clk) begin
        #1;
        check_q();
    end

    task automatic drive_reset(input bit value);
        reset = value;
        #1;
        check_q(); // reset itself must not modify the count
    endtask

    initial begin
        // No expectation about q before the first sampled reset.
        #2;
        drive_reset(1);
        repeat (3) @(negedge clk);
        #2;
        drive_reset(0);
        repeat (35) @(negedge clk);

        // Reset from every legal count, including the rollover boundary.
        for (target = 0; target < 10; target = target + 1) begin
            while (expected != target) @(negedge clk);
            @(negedge clk);
            // Wait again if that extra cycle moved away from target.
            while (expected != target) @(negedge clk);
            #2;
            drive_reset(1);
            @(negedge clk);
            #2;
            drive_reset(0);
        end

        // A pulse completely between positive edges is never sampled.
        @(negedge clk);
        #1;
        drive_reset(1);
        drive_reset(0);
        repeat (25) @(negedge clk);
        #2;
        check_q();
        $display("PASS decade counter: %0d comparisons", checks);
        $finish;
    end
    initial begin
        #5000;
        $fatal(1, "Timeout");
    end
endmodule
