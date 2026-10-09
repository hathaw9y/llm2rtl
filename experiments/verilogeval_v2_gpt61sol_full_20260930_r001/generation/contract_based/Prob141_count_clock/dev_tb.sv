`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic ena = 0;
    wire pm;
    wire [7:0] hh, mm, ss;
    integer reference_seconds = 0;
    integer checked = 0;
    integer i;
    logic [24:0] previous_display;
    TopModule dut (.clk(clk), .reset(reset), .ena(ena),
                   .pm(pm), .hh(hh), .mm(mm), .ss(ss));
    always #5 clk = ~clk;
    function automatic [7:0] bcd(input integer value);
        bcd = ((value / 10) << 4) | (value % 10);
    endfunction
    task automatic check_display;
        integer hour24, hour12;
        begin
            hour24 = reference_seconds / 3600;
            hour12 = hour24 % 12;
            if (hour12 == 0) hour12 = 12;
            if (pm !== (hour24 >= 12) || hh !== bcd(hour12) ||
                mm !== bcd((reference_seconds / 60) % 60) ||
                ss !== bcd(reference_seconds % 60)) begin
                $display("FAIL seconds=%0d actual=%b %h:%h:%h", reference_seconds, pm, hh, mm, ss);
                $fatal(1, "Display mismatch");
            end
            checked = checked + 1;
        end
    endtask
    task automatic step(input logic reset_value, input logic enable_value);
        begin
            @(negedge clk);
            previous_display = {pm, hh, mm, ss};
            reset = reset_value;
            ena = enable_value;
            #1;
            if ({pm, hh, mm, ss} !== previous_display)
                $fatal(1, "Outputs changed before rising edge");
            @(posedge clk);
            if (reset_value) reference_seconds = 0;
            else if (enable_value) reference_seconds = (reference_seconds + 1) % 86400;
            #1;
            check_display();
        end
    endtask
    initial begin
        step(1, 0);
        step(0, 0);
        step(1, 1);
        for (i = 0; i < 172800; i = i + 1) begin
            step(0, 1);
            if (i % 997 == 0) step(0, 0);
        end
        for (i = 0; i < 2000; i = i + 1)
            step((i == 321 || i == 1234), ((i % 7) < 4));
        step(1, 0);
        step(1, 1);
        step(0, 1);
        $display("PASS: %0d checked cycles; two complete days, holds, burst enables, synchronous reset and reset priority", checked);
        $finish;
    end
    initial begin
        #3000000;
        $fatal(1, "Simulation timeout");
    end
endmodule
