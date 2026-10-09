`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic areset = 0;
    logic load = 0;
    logic ena = 0;
    logic [3:0] data = 0;
    wire [3:0] q;
    integer expected;
    integer checks = 0;
    integer value, controls, shifts;
    TopModule dut (.clk(clk), .areset(areset), .load(load), .ena(ena), .data(data), .q(q));
    always #5 clk = ~clk;

    task automatic check(input integer wanted);
        begin
            if (q !== wanted[3:0])
                $fatal(1, "t=%0t expected=%h actual=%h load=%b ena=%b reset=%b", $time, wanted[3:0], q, load, ena, areset);
            checks = checks + 1;
        end
    endtask

    task automatic cycle(input logic ld, input logic en, input logic [3:0] payload);
        begin
            @(negedge clk);
            load = ld;
            ena = en;
            data = payload;
            #1;
            check(expected);
            if (areset) expected = 0;
            else if (ld) expected = payload;
            else if (en) expected = expected / 2;
            @(posedge clk);
            #1;
            check(expected);
        end
    endtask

    initial begin
        // No specified power-up value: establish state with an off-edge reset.
        #2;
        areset = 1;
        expected = 0;
        #1;
        check(expected);
        @(negedge clk);
        areset = 0;
        #1;
        check(expected);

        for (value = 0; value < 16; value = value + 1) begin
            for (controls = 0; controls < 4; controls = controls + 1) begin
                cycle(1, 0, value[3:0]);
                cycle(controls[1], controls[0], (15-value));
                cycle(0, 0, value[3:0]);
            end
            cycle(1, 1, value[3:0]);
            for (shifts = 0; shifts < 6; shifts = shifts + 1)
                cycle(0, 1, 4'hf);
        end

        // Reset must clear a nonzero value without waiting for a clock.
        cycle(1, 0, 4'hf);
        #1;
        load = 1;
        ena = 1;
        data = 4'ha;
        #1;
        check(15);
        areset = 1;
        expected = 0;
        #1;
        check(expected);
        cycle(1, 1, 4'hf);
        cycle(1, 0, 4'h5);
        @(negedge clk);
        load = 0;
        ena = 0;
        areset = 0;
        #1;
        check(expected);
        cycle(0, 0, 4'hf);
        cycle(1, 1, 4'h9);
        cycle(0, 1, 4'h0);
        $display("PASS dev_tb checks=%0d", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
