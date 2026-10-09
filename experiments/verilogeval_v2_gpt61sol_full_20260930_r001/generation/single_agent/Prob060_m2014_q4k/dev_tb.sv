`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic resetn = 0;
    logic in = 0;
    wire out;
    logic expected [0:3];
    integer i;
    integer checks = 0;
    TopModule dut (.clk(clk), .resetn(resetn), .in(in), .out(out));
    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (!resetn) begin
            for (integer j = 0; j < 4; j = j + 1)
                expected[j] = 0;
        end else begin
            for (integer j = 3; j > 0; j = j - 1)
                expected[j] = expected[j-1];
            expected[0] = in;
        end
        #1;
        if (out !== expected[3])
            $fatal(1, "Mismatch at check %0d", checks);
        checks = checks + 1;
    end

    initial begin
        @(negedge clk);
        resetn = 1;
        in = 1;
        repeat (5) @(negedge clk);
        // A reset pulse between rising edges must leave the state unchanged.
        #1 resetn = 0;
        #1;
        if (out !== 1'b1) $fatal(1, "Reset acted asynchronously");
        #1 resetn = 1;
        for (i = 0; i < 100; i = i + 1) begin
            @(negedge clk);
            in = ((i % 7) < 3);
            resetn = !((i == 20) || (i == 21) || (i == 60));
        end
        @(negedge clk);
        $display("PASS: %0d rising-edge comparisons and synchronous-reset pulse check", checks);
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "Testbench timeout");
    end
endmodule
