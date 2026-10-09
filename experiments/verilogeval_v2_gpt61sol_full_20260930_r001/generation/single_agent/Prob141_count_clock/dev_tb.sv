`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic ena = 0;
    wire pm;
    wire [7:0] hh, mm, ss;
    integer elapsed = 0;
    integer cycles = 0;
    integer hour_expected;
    TopModule dut (.clk(clk), .reset(reset), .ena(ena), .pm(pm), .hh(hh), .mm(mm), .ss(ss));
    always #5 clk = ~clk;
    function automatic [7:0] bcd(input integer value);
        bcd = ((value / 10) << 4) | (value % 10);
    endfunction
    task automatic step(input logic r, input logic e);
        @(negedge clk);
        reset = r;
        ena = e;
        @(posedge clk);
        if (r) elapsed = 0;
        else if (e) elapsed = (elapsed + 1) % 86400;
        #1;
        hour_expected = (elapsed / 3600) % 12;
        if (hour_expected == 0) hour_expected = 12;
        if (hh !== bcd(hour_expected) || mm !== bcd((elapsed / 60) % 60) ||
            ss !== bcd(elapsed % 60) || pm !== (elapsed >= 43200)) begin
            $display("FAIL cycle=%0d elapsed=%0d actual=%b %h:%h:%h", cycles, elapsed, pm, hh, mm, ss);
            $fatal(1);
        end
        cycles = cycles + 1;
    endtask
    initial begin
        step(1, 0);
        step(0, 0);
        step(1, 1);
        for (integer i = 0; i < 172800; i = i + 1) begin
            step(0, 1);
            if (i % 97 == 0) step(0, 0);
        end
        for (integer i = 0; i < 5000; i = i + 1)
            step(i % 811 == 0, i % 7 != 0);
        step(1, 0);
        step(0, 1);
        $display("PASS: %0d checked cycles, two full days plus stalls and resets", cycles);
        $finish;
    end
    initial begin
        #3000000;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
