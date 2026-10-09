`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic areset = 0;
    logic predict_valid = 0, predict_taken = 0;
    logic train_mispredicted = 0, train_taken = 0;
    logic [31:0] train_history = 0;
    wire [31:0] predict_history;
    logic [31:0] expected = 0;
    integer checks = 0;
    TopModule dut (.*);
    always #5 clk = ~clk;
    task automatic check;
        if (predict_history !== expected)
            $fatal(1, "FAIL expected=%h actual=%h", expected, predict_history);
        checks = checks + 1;
    endtask
    task automatic step(input logic pv, pt, tm, tt, input logic [31:0] th);
        @(negedge clk);
        predict_valid = pv;
        predict_taken = pt;
        train_mispredicted = tm;
        train_taken = tt;
        train_history = th;
        @(posedge clk);
        if (areset) expected = 0;
        else if (tm) expected = (th << 1) | {31'b0, tt};
        else if (pv) expected = (expected << 1) | {31'b0, pt};
        #1; check();
    endtask
    initial begin
        #2; areset = 1; expected = 0;
        #1; check();
        #1; areset = 0;
        step(0, 1, 0, 1, 32'hffffffff);
        step(1, 1, 0, 0, 0);
        step(1, 0, 0, 0, 0);
        repeat (35) step(1, 1, 0, 0, 0);
        step(0, 0, 1, 0, 32'h80000001);
        step(1, 0, 1, 1, 32'h12345678);
        step(0, 1, 0, 0, 32'hffffffff);
        for (integer i = 0; i < 500; i = i + 1)
            step($urandom_range(0,1), $urandom_range(0,1),
                 $urandom_range(0,1), $urandom_range(0,1), $urandom);
        @(negedge clk);
        #2; areset = 1; expected = 0;
        #1; check();
        @(posedge clk); #1; check();
        @(negedge clk); areset = 0;
        step(1, 1, 0, 0, 0);
        $display("PASS: %0d checks", checks);
        $finish;
    end
    initial begin
        #20000; $fatal(1, "FAIL timeout");
    end
endmodule
