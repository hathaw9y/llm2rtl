`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    reg ena = 0;
    wire pm;
    wire [7:0] hh, mm, ss;
    integer elapsed = 0;
    integer cycles = 0;
    integer i;
    reg valid = 0;
    reg [24:0] previous;
    TopModule dut(.clk(clk), .reset(reset), .ena(ena), .pm(pm), .hh(hh), .mm(mm), .ss(ss));
    always #5 clk = ~clk;

    function [7:0] bcd(input integer value);
        bcd = ((value / 10) << 4) | (value % 10);
    endfunction

    task tick(input reg rst, input reg en);
        integer hour_value;
        reg expected_pm;
        begin
            @(negedge clk);
            previous = {pm, hh, mm, ss};
            reset = rst;
            ena = en;
            #1;
            if (valid && {pm, hh, mm, ss} !== previous)
                $fatal(1, "Outputs changed before positive edge");
            @(posedge clk);
            if (rst) begin
                elapsed = 0;
                valid = 1;
            end else if (en && valid) begin
                elapsed = (elapsed + 1) % 86400;
            end
            #1;
            cycles = cycles + 1;
            if (valid) begin
                hour_value = (elapsed / 3600) % 12;
                if (hour_value == 0) hour_value = 12;
                expected_pm = (elapsed >= 43200);
                if ({pm, hh, mm, ss} !== {expected_pm, bcd(hour_value), bcd((elapsed / 60) % 60), bcd(elapsed % 60)})
                    $fatal(1, "Mismatch cycle=%0d elapsed=%0d observed=%b %h:%h:%h", cycles, elapsed, pm, hh, mm, ss);
            end
        end
    endtask

    initial begin
        // Establish state through synchronous reset, first with enable low.
        tick(1, 0);
        tick(0, 0);
        tick(1, 1);
        // More than two days covers every BCD carry and both AM/PM transitions.
        for (i = 0; i < 180000; i = i + 1) begin
            tick(0, 1);
            if (i % 997 == 0) tick(0, 0);
        end
        tick(1, 0);
        for (i = 0; i < 73; i = i + 1) tick(0, 1);
        tick(1, 1);
        tick(0, 0);
        tick(0, 1);
        $display("PASS clock verified across two days, holds, and reset priority");
        $finish;
    end
    initial begin
        #3000000;
        $fatal(1, "Timeout");
    end
endmodule
