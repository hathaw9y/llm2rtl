`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    wire [2:0] ena;
    wire [15:0] q;
    integer expected = 0;
    integer checked_edges = 0;
    bit established = 0;
    TopModule dut (.clk(clk), .reset(reset), .ena(ena), .q(q));
    always #5 clk = ~clk;

    task automatic check_outputs;
        logic [15:0] expected_bcd;
        logic [2:0] expected_ena;
        begin
            expected_bcd[3:0] = expected % 10;
            expected_bcd[7:4] = (expected / 10) % 10;
            expected_bcd[11:8] = (expected / 100) % 10;
            expected_bcd[15:12] = (expected / 1000) % 10;
            expected_ena[0] = (expected % 10 == 9);
            expected_ena[1] = (expected % 100 == 99);
            expected_ena[2] = (expected % 1000 == 999);
            if (q !== expected_bcd)
                $fatal(1, "q mismatch time=%0t expected=%h actual=%h", $time, expected_bcd, q);
            if (ena !== expected_ena)
                $fatal(1, "ena mismatch time=%0t count=%0d expected=%b actual=%b", $time, expected, expected_ena, ena);
        end
    endtask

    always @(posedge clk) begin
        if (reset) begin
            expected = 0;
            established = 1;
        end else if (established) begin
            expected = (expected + 1) % 10000;
        end
        #1;
        if (established) begin
            check_outputs();
            checked_edges = checked_edges + 1;
        end
    end
    always @(negedge clk) begin
        #1;
        if (established) check_outputs();
    end

    initial begin
        // No assumption about power-up value; first reset is between edges.
        #2 reset = 1;
        repeat (3) @(negedge clk);
        #2 reset = 0;
        // Complete decimal period plus extra edges includes every carry and wrap.
        repeat (10025) @(negedge clk);
        // Assert reset away from an active edge; current count must hold.
        #2 reset = 1;
        #1 check_outputs();
        repeat (3) @(negedge clk);
        #2 reset = 0;
        // Reset from 0099 checks carry enables remain state-derived until edge.
        repeat (99) @(negedge clk);
        #2 reset = 1;
        #1 check_outputs();
        repeat (2) @(negedge clk);
        #2 reset = 0;
        repeat (21) @(negedge clk);
        #2 check_outputs();
        if (checked_edges < 10100) $fatal(1, "Insufficient coverage");
        $display("PASS exhaustive BCD period, enables, wraparound, synchronous and held reset (%0d edges)", checked_edges);
        $finish;
    end
    initial begin
        #200000;
        $fatal(1, "Timeout");
    end
endmodule
