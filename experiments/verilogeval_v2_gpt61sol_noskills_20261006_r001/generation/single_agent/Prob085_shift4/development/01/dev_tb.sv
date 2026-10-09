`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg areset = 0;
    reg load = 0;
    reg ena = 0;
    reg [3:0] data = 0;
    wire [3:0] q;
    reg [3:0] expected;
    integer value, control, payload, step;
    integer checks = 0;
    TopModule dut(.clk(clk), .areset(areset), .load(load),
                  .ena(ena), .data(data), .q(q));

    task check;
        begin
            if (q !== expected)
                $fatal(1, "At %0t expected %b, got %b (reset=%b load=%b ena=%b)",
                       $time, expected, q, areset, load, ena);
            checks = checks + 1;
        end
    endtask

    task cycle(input reg l, input reg e, input reg [3:0] d);
        begin
            // Change synchronous inputs while the clock is low.
            load = l; ena = e; data = d;
            #2; check(); // Inputs alone must not change the register.
            clk = 1;
            if (areset) expected = 0;
            else if (l) expected = d;
            else if (e) expected = expected / 2;
            #1; check(); // Observe after nonblocking assignments settle.
            clk = 0;
            #1; check();
        end
    endtask

    initial begin
        // First reset arrives between clock edges.
        #1; areset = 1; expected = 0;
        #1; check();
        cycle(1, 1, 4'hf); // Reset dominates load and enable.
        areset = 0;
        #1; check();
        for (value = 0; value < 16; value = value + 1) begin
            for (control = 0; control < 4; control = control + 1) begin
                for (payload = 0; payload < 16; payload = payload + 1) begin
                    cycle(1, 0, value);
                    cycle((control & 2) != 0, (control & 1) != 0, payload);
                end
            end
            cycle(1, 1, value);
            for (step = 0; step < 5; step = step + 1)
                cycle(0, 1, 4'hf);
        end
        // Assert reset with a nonzero register while the clock stays low.
        cycle(1, 0, 4'hf);
        #1; areset = 1; expected = 0;
        #1; check();
        areset = 0;
        #1; check();
        cycle(1, 0, 4'ha);
        // Assert asynchronous reset while clock is held high.
        clk = 1;
        expected = 4'ha;
        #1; check();
        areset = 1; expected = 0;
        #1; check();
        load = 1; ena = 1; data = 4'hf;
        #1; check();
        areset = 0;
        #1; check(); // Reset release does not load data.
        clk = 0;
        #1;
        cycle(1, 1, 4'h9);
        cycle(0, 0, 4'h6);
        $display("PASS: %0d shift-register checks", checks);
        $finish;
    end
    initial begin
        #20000;
        $fatal(1, "Timeout");
    end
endmodule
