`timescale 1ns/1ps
module dev_tb;
    logic clk;
    logic d;
    wire q;
    logic expected;
    integer edge_checks = 0;
    integer hold_checks = 0;
    integer i;
    TopModule dut (.clk(clk), .d(d), .q(q));

    // Oracle: sample the input on each clock transition, then hold it.
    always @(posedge clk or negedge clk) begin
        expected = d;
        #0.001;
        if (q !== expected)
            $fatal(1, "edge mismatch at %0t: q=%b expected=%b", $time, q, expected);
        edge_checks = edge_checks + 1;
    end

    task automatic check_hold;
        begin
            #1;
            if (q !== expected)
                $fatal(1, "hold mismatch at %0t: q=%b expected=%b", $time, q, expected);
            hold_checks = hold_checks + 1;
        end
    endtask

    task automatic half_cycle(input logic sampled_d, input integer dwell);
        begin
            d = sampled_d;
            #2;
            clk = ~clk;
            #1;
            d = ~sampled_d;
            check_hold();
            d = sampled_d;
            check_hold();
            #(dwell);
            check_hold();
        end
    endtask

    initial begin
        d = 0;
        clk = 0;
        #2;
        // Both data values on both edge polarities; changes between edges
        // must not pass through to q. Unequal dwell times exercise duty cycle.
        half_cycle(0, 1);
        half_cycle(0, 4);
        half_cycle(1, 2);
        half_cycle(1, 5);
        half_cycle(0, 3);
        half_cycle(1, 1);
        half_cycle(1, 4);
        half_cycle(0, 2);
        for (i = 0; i < 64; i = i + 1)
            half_cycle(((i * 13 + i / 3) % 7) < 3, (i % 5) + 1);
        if (edge_checks < 72 || hold_checks != 216)
            $fatal(1, "insufficient checks: edges=%0d holds=%0d", edge_checks, hold_checks);
        $display("PASS dual-edge capture: %0d edge checks and %0d hold checks", edge_checks, hold_checks);
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "timeout");
    end
endmodule
