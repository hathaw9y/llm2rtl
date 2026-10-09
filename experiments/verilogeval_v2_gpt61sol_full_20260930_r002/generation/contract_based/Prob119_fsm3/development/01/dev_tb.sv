`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic areset = 0;
    logic in = 0;
    wire out;
    integer model;
    integer checks = 0;
    integer coverage [0:7];
    integer seq_num, bit_num, target, i;
    TopModule dut (.clk(clk), .areset(areset), .in(in), .out(out));

    task automatic check_output;
        begin
            if (out !== (model == 3))
                $fatal(1, "Mismatch at %0t state=%0d in=%b reset=%b out=%b", $time, model, in, areset, out);
            checks = checks + 1;
        end
    endtask

    task automatic tick(input logic value);
        integer prior;
        begin
            in = value;
            #2;
            check_output(); // Moore output cannot change with input alone.
            prior = model;
            clk = 1;
            if (areset) model = 0;
            else begin
                coverage[2*prior + value] = coverage[2*prior + value] + 1;
                // Original table: A=0, B=1, C=2, D=3.
                if (value) begin
                    if (prior == 2) model = 3;
                    else model = 1;
                end else begin
                    if (prior == 1 || prior == 3) model = 2;
                    else model = 0;
                end
            end
            #1;
            check_output();
            #2;
            clk = 0;
            #1;
            check_output();
        end
    endtask

    task automatic reset_fsm;
        begin
            // Assert between clock edges: reset must work without a clock.
            #1;
            areset = 1;
            model = 0;
            #1;
            check_output();
            tick(1);
            tick(0);
            areset = 0;
            #1;
            check_output(); // Deassertion alone must retain state A.
        end
    endtask

    initial begin
        for (i = 0; i < 8; i = i + 1) coverage[i] = 0;
        reset_fsm();
        // Every binary sequence of length eight, starting in A.
        for (seq_num = 0; seq_num < 256; seq_num = seq_num + 1) begin
            reset_fsm();
            for (bit_num = 0; bit_num < 8; bit_num = bit_num + 1)
                tick((seq_num >> bit_num) & 1);
        end
        // Reset while in each reachable state, including asserted output D.
        for (target = 0; target < 4; target = target + 1) begin
            reset_fsm();
            if (target >= 1) tick(1);
            if (target >= 2) tick(0);
            if (target >= 3) tick(1);
            if (model != target) $fatal(1, "Test setup failed");
            reset_fsm();
        end
        for (i = 0; i < 8; i = i + 1)
            if (coverage[i] == 0) $fatal(1, "Uncovered transition %0d", i);
        $display("PASS all transitions, exhaustive input sequences, Moore stability and asynchronous reset; checks=%0d", checks);
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "Timeout");
    end
endmodule
