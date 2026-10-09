`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic ena = 0;
    wire pm;
    wire [7:0] hh, mm, ss;
    integer elapsed = 0;
    integer checks = 0;
    integer i;
    TopModule dut (.clk(clk), .reset(reset), .ena(ena),
                   .pm(pm), .hh(hh), .mm(mm), .ss(ss));
    always #5 clk = ~clk;

    function automatic [7:0] bcd(input integer value);
        bcd = ((value / 10) << 4) | (value % 10);
    endfunction

    task automatic compare_clock;
        integer hour24;
        integer hour12;
        reg expected_pm;
        begin
            hour24 = elapsed / 3600;
            hour12 = hour24 % 12;
            if (hour12 == 0) hour12 = 12;
            expected_pm = (hour24 >= 12);
            if (pm !== expected_pm || hh !== bcd(hour12) ||
                mm !== bcd((elapsed / 60) % 60) || ss !== bcd(elapsed % 60))
                $fatal(1, "elapsed=%0d expected %0d:%0d:%0d pm=%0b got %h:%h:%h pm=%b",
                       elapsed, hour12, (elapsed/60)%60, elapsed%60,
                       expected_pm, hh, mm, ss, pm);
            checks = checks + 1;
        end
    endtask

    task automatic tick(input bit reset_value, input bit enable_value);
        begin
            @(negedge clk);
            reset = reset_value;
            ena = enable_value;
            #1;
            // Reset is synchronous: even asserted reset must hold until posedge.
            compare_clock();
            @(posedge clk);
            if (reset_value) elapsed = 0;
            else if (enable_value) elapsed = (elapsed + 1) % 86400;
            #1;
            compare_clock();
        end
    endtask

    initial begin
        // First reset establishes defined state; no power-up value is required.
        @(negedge clk);
        reset = 1;
        ena = 0;
        @(posedge clk);
        #1;
        elapsed = 0;
        compare_clock();
        tick(1, 1);
        tick(0, 0);
        // Full day: both AM/PM transitions and every reachable BCD carry.
        for (i = 0; i < 86400; i = i + 1) begin
            if ((i % 997) == 0) tick(0, 0);
            tick(0, 1);
        end
        // Burst enables interspersed with holds; then reset during active counting.
        for (i = 0; i < 731; i = i + 1) tick(0, (i % 7) < 4);
        tick(1, 0);
        tick(0, 1);
        tick(1, 1);
        tick(0, 0);
        tick(0, 1);
        $display("PASS clock oracle checks=%0d", checks);
        $finish;
    end
    initial begin
        #2000000;
        $fatal(1, "Timeout");
    end
endmodule
