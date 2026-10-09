`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    reg ena = 0;
    wire pm;
    wire [7:0] hh, mm, ss;
    integer model = 0;
    integer checks = 0;
    integer i;
    reg known = 0;
    reg [31:0] rng = 32'h31415926;
    TopModule dut(.clk(clk), .reset(reset), .ena(ena),
                  .pm(pm), .hh(hh), .mm(mm), .ss(ss));
    always #5 clk = ~clk;

    function automatic [7:0] bcd(input integer value);
        bcd = ((value / 10) << 4) | (value % 10);
    endfunction

    task automatic compare;
        integer hour24, hour12, minute, second;
        reg expected_pm;
        begin
            hour24 = model / 3600;
            hour12 = hour24 % 12;
            if (hour12 == 0) hour12 = 12;
            minute = (model / 60) % 60;
            second = model % 60;
            expected_pm = (hour24 >= 12);
            if (pm !== expected_pm || hh !== bcd(hour12) ||
                mm !== bcd(minute) || ss !== bcd(second))
                $fatal(1, "Mismatch at %0t model=%0d got=%b %h:%h:%h expected=%b %h:%h:%h",
                       $time, model, pm, hh, mm, ss, expected_pm,
                       bcd(hour12), bcd(minute), bcd(second));
            checks = checks + 1;
        end
    endtask

    task automatic step(input reg r, input reg e);
        begin
            @(negedge clk);
            reset = r;
            ena = e;
            #1;
            // Changing reset or enable must not change state between rising edges.
            if (known) compare();
            @(posedge clk);
            if (r) begin
                model = 0;
                known = 1;
            end else if (e && known) begin
                model = (model + 1) % 86400;
            end
            #1;
            if (known) compare();
        end
    endtask

    initial begin
        // No specified power-up value: first establish state via reset.
        step(1, 0);
        step(0, 0);
        step(0, 1);
        step(1, 1);
        for (i = 0; i < 172800; i = i + 1) begin
            // Holds immediately around decimal, minute, and hour boundaries.
            if (model % 10 == 9) step(0, 0);
            step(0, 1);
        end
        // Reset from a nonzero time, including reset while disabled.
        for (i = 0; i < 3671; i = i + 1) step(0, 1);
        step(1, 0);
        for (i = 0; i < 61; i = i + 1) step(0, 1);
        step(1, 1);
        for (i = 0; i < 10000; i = i + 1) begin
            rng = {rng[30:0], rng[31] ^ rng[21] ^ rng[1] ^ rng[0]};
            step(i % 1997 == 1996, rng[0]);
        end
        $display("PASS: %0d independent clock checks", checks);
        $finish;
    end
    initial begin
        #3000000;
        $fatal(1, "Bounded timeout");
    end
endmodule
