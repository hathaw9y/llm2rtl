`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic areset = 0;
    logic predict_valid = 0, predict_taken = 0;
    logic train_mispredicted = 0, train_taken = 0;
    logic [31:0] train_history = 0;
    wire [31:0] predict_history;
    logic [31:0] expected;
    integer checks = 0;
    integer i;
    TopModule dut (.*);
    always #5 clk = ~clk;

    task automatic check;
        begin
            if (predict_history !== expected)
                $fatal(1, "history mismatch at %0t: got %h expected %h", $time, predict_history, expected);
            checks = checks + 1;
        end
    endtask

    task automatic step(input bit pv, input bit pt, input bit tm,
                        input bit tt, input logic [31:0] th);
        begin
            @(negedge clk);
            predict_valid = pv;
            predict_taken = pt;
            train_mispredicted = tm;
            train_taken = tt;
            train_history = th;
            #1;
            check(); // Inputs must not change the history before the rising edge.
            @(posedge clk);
            if (areset) expected = 0;
            else if (tm) expected = (th * 32'd2) + tt;
            else if (pv) expected = (expected * 32'd2) + pt;
            #1;
            check();
        end
    endtask

    initial begin
        // Establish defined state with an asynchronous edge away from the clock.
        #2 areset = 1;
        expected = 0;
        #1 check();
        #1 areset = 0;
        step(0, 1, 0, 1, 32'hffffffff);
        step(1, 1, 0, 0, 0);
        step(1, 0, 0, 0, 0);
        step(1, 1, 0, 0, 0);
        for (i = 0; i < 34; i = i + 1) step(1, 1, 0, 0, 0);
        for (i = 0; i < 33; i = i + 1) step(1, 0, 0, 0, 0);
        step(0, 0, 1, 1, 32'h80000000);
        step(0, 0, 1, 0, 32'hffffffff);
        step(1, 0, 1, 1, 32'h12345678);
        step(1, 1, 1, 0, 32'h87654321);
        step(0, 1, 0, 1, 32'hdeadbeef);
        // Reset while prediction and rollback are both requested.
        @(negedge clk);
        predict_valid = 1;
        train_mispredicted = 1;
        train_history = 32'hffffffff;
        train_taken = 1;
        #2 areset = 1;
        expected = 0;
        #1 check();
        @(posedge clk);
        #1 check();
        @(negedge clk);
        predict_valid = 0;
        train_mispredicted = 0;
        #2 areset = 0;
        #1 check();
        for (i = 0; i < 200; i = i + 1)
            step($urandom_range(0,1), $urandom_range(0,1),
                 $urandom_range(0,1), $urandom_range(0,1), $urandom);
        $display("PASS history register: %0d checks", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "timeout");
    end
endmodule
