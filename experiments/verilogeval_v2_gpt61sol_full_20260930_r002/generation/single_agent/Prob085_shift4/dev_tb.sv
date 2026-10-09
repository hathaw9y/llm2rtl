`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic areset = 0;
    logic load = 0;
    logic ena = 0;
    logic [3:0] data = 0;
    wire [3:0] q;
    logic [3:0] expected;
    integer value, controls, step;
    integer checks = 0;
    TopModule dut (.clk(clk), .areset(areset), .load(load),
                   .ena(ena), .data(data), .q(q));

    task automatic check_q;
        begin
            checks = checks + 1;
            if (q !== expected)
                $fatal(1, "Mismatch at %0t: q=%b expected=%b reset=%b load=%b ena=%b",
                       $time, q, expected, areset, load, ena);
        end
    endtask

    task automatic cycle(input logic l, input logic e, input logic [3:0] d);
        begin
            clk = 0;
            load = l;
            ena = e;
            data = d;
            #2;
            check_q(); // synchronous controls must not affect q before the edge
            if (areset) expected = 0;
            else if (l) expected = d;
            else if (e) expected = expected / 2;
            clk = 1;
            #1;
            check_q(); // sample after nonblocking assignments
            clk = 0;
            #1;
            check_q(); // negative edge does not update state
        end
    endtask

    initial begin
        #1;
        areset = 1;
        expected = 0;
        #1;
        check_q(); // reset asserted without a clock edge
        cycle(1, 1, 4'hf); // reset dominates both controls
        areset = 0;
        #1;
        check_q();
        for (value = 0; value < 16; value = value + 1) begin
            for (controls = 0; controls < 4; controls = controls + 1) begin
                cycle(1, 0, value[3:0]);
                cycle(controls[1], controls[0], 4'hf - value[3:0]);
            end
            cycle(1, 1, value[3:0]);
            for (step = 0; step < 6; step = step + 1)
                cycle(0, 1, 4'hf);
            cycle(0, 0, value[3:0]);
        end
        cycle(1, 0, 4'hf);
        #1;
        areset = 1;
        expected = 0;
        #1;
        check_q();
        cycle(1, 0, 4'h9);
        areset = 0;
        #1;
        check_q();
        cycle(0, 0, 4'hf);
        cycle(1, 1, 4'h9);
        cycle(0, 1, 0);
        $display("PASS: shift register verified (%0d comparisons)", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
