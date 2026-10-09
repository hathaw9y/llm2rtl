`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg areset = 0;
    reg load = 0;
    reg ena = 0;
    reg [3:0] data = 0;
    wire [3:0] q;
    integer expected;
    integer checks = 0;
    integer value;
    integer step;
    TopModule dut (.clk(clk), .areset(areset), .load(load),
                   .ena(ena), .data(data), .q(q));
    always #5 clk = ~clk;

    task check;
        begin
            if (q !== expected[3:0])
                $fatal(1, "At %0t q=%b expected=%b", $time, q, expected[3:0]);
            checks = checks + 1;
        end
    endtask

    task cycle(input bit loading, input bit enabling, input integer datum);
        begin
            @(negedge clk);
            load = loading;
            ena = enabling;
            data = datum;
            #1;
            check(); // Synchronous inputs must not alter state between clock edges.
            @(posedge clk);
            if (areset) expected = 0;
            else if (loading) expected = datum;
            else if (enabling) expected = expected / 2;
            #1;
            check();
        end
    endtask

    initial begin
        // First reset occurs strictly between clock edges; startup is unspecified.
        #2;
        areset = 1;
        expected = 0;
        #1;
        check();
        @(negedge clk);
        areset = 0;
        #1;
        check();
        for (value = 0; value < 16; value = value + 1) begin
            cycle(1, 0, value);
            cycle(0, 0, 15-value);
            cycle(1, 1, value); // Load must win over shift.
            for (step = 0; step < 5; step = step + 1)
                cycle(0, 1, 15-value);
        end
        cycle(1, 0, 15);
        @(negedge clk);
        load = 1;
        ena = 1;
        data = 15;
        #2;
        check();
        areset = 1;
        expected = 0;
        #1;
        check();
        cycle(1, 1, 15); // Reset dominates load and enable while held.
        cycle(0, 1, 15);
        @(negedge clk);
        load = 0;
        ena = 0;
        #2;
        areset = 0;
        #1;
        check();
        cycle(0, 0, 15);
        cycle(1, 1, 9);
        cycle(0, 1, 0);
        $display("PASS: %0d checks", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
