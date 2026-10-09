`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic ena = 0;
    wire pm;
    wire [7:0] hh, mm, ss;
    integer seconds_of_day = 0;
    integer cycles = 0;
    integer i;
    bit initialized = 0;
    TopModule dut (.clk(clk), .reset(reset), .ena(ena),
                   .pm(pm), .hh(hh), .mm(mm), .ss(ss));
    always #5 clk = ~clk;

    function automatic [7:0] bcd(input integer value);
        bcd = ((value / 10) << 4) | (value % 10);
    endfunction

    task automatic check_outputs;
        integer hour_value;
        reg expected_pm;
        reg [7:0] expected_hh, expected_mm, expected_ss;
        begin
            hour_value = (seconds_of_day / 3600) % 12;
            if (hour_value == 0) hour_value = 12;
            expected_pm = (seconds_of_day >= 43200);
            expected_hh = bcd(hour_value);
            expected_mm = bcd((seconds_of_day / 60) % 60);
            expected_ss = bcd(seconds_of_day % 60);
            if ({pm, hh, mm, ss} !== {expected_pm, expected_hh, expected_mm, expected_ss})
                $fatal(1, "cycle %0d time %0d: got %b %h:%h:%h expected %b %h:%h:%h",
                       cycles, seconds_of_day, pm, hh, mm, ss,
                       expected_pm, expected_hh, expected_mm, expected_ss);
        end
    endtask

    task automatic step(input bit reset_value, input bit enable_value);
        begin
            @(negedge clk);
            reset = reset_value;
            ena = enable_value;
            #1;
            // Inputs, including reset, must not change outputs between rising edges.
            if (initialized) check_outputs();
            @(posedge clk);
            if (reset_value) begin
                seconds_of_day = 0;
                initialized = 1;
            end else if (enable_value && initialized) begin
                seconds_of_day = (seconds_of_day + 1) % 86400;
            end
            cycles = cycles + 1;
            #1;
            if (initialized) check_outputs();
        end
    endtask

    initial begin
        step(1, 0);
        step(0, 0);
        step(0, 1);
        step(1, 1);
        // Exhaust all seconds of two days, with periodic disabled cycles.
        for (i = 0; i < 172800; i = i + 1) begin
            if ((i % 97) == 0) step(0, 0);
            step(0, 1);
        end
        for (i = 0; i < 1234; i = i + 1) step(0, 1);
        step(1, 0);
        step(1, 1);
        step(0, 0);
        step(0, 1);
        $display("PASS clock: full two-day sequence, holds, synchronous reset and priority (%0d cycles)", cycles);
        $finish;
    end
    initial begin
        #2000000;
        $fatal(1, "timeout");
    end
endmodule
