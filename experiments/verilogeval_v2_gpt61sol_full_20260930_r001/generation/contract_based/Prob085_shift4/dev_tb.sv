`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic areset = 0;
    logic load = 0;
    logic ena = 0;
    logic [3:0] data = 0;
    wire [3:0] q;
    integer expected = 0;
    integer checks = 0;
    integer prior, control, datum, k;
    TopModule dut (.clk(clk), .areset(areset), .load(load), .ena(ena), .data(data), .q(q));
    task automatic check;
        begin
            checks = checks + 1;
            if (q !== expected[3:0])
                $fatal(1, "FAIL check %0d: q=%b expected=%b", checks, q, expected[3:0]);
        end
    endtask
    task automatic tick;
        begin
            #2;
            clk = 1;
            if (areset) expected = 0;
            else if (load) expected = data;
            else if (ena) expected = expected / 2;
            #1; check();
            clk = 0;
            #1;
        end
    endtask
    initial begin
        #1; areset = 1; expected = 0;
        #1; check();
        load = 1; ena = 1; data = 15;
        tick();
        areset = 0;
        #1; check();
        for (prior = 0; prior < 16; prior = prior + 1)
            for (control = 0; control < 4; control = control + 1)
                for (datum = 0; datum < 16; datum = datum + 1) begin
                    load = 1; ena = 0; data = prior;
                    tick();
                    load = (control / 2) != 0;
                    ena = (control % 2) != 0;
                    data = datum;
                    #1; check(); // input changes alone cannot update q
                    tick();
                end
        load = 1; ena = 1; data = 15;
        tick();
        #1; areset = 1; expected = 0;
        #1; check(); // reset without a rising clock edge
        tick(); tick();
        areset = 0;
        #1; check();
        tick();
        load = 0; ena = 1;
        for (k = 0; k < 6; k = k + 1) tick();
        $display("PASS: %0d comparisons; exhaustive states/controls/data and reset timing", checks);
        $finish;
    end
    initial begin
        #20000; $fatal(1, "FAIL watchdog timeout");
    end
endmodule
