`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic in = 1;
    wire done;
    TopModule dut(.clk(clk), .reset(reset), .in(in), .done(done));
    always #5 clk = ~clk;
    integer remaining = 0;
    bit recovery = 0;
    bit expected_done = 0;
    integer checked = 0;
    integer b, j, k;
    logic [31:0] rng = 32'h137a5eed;

    task automatic tick(input bit value, input bit rst);
        @(negedge clk);
        in = value;
        reset = rst;
        @(posedge clk);
        expected_done = 0;
        if (rst) begin
            remaining = 0;
            recovery = 0;
        end else if (recovery) begin
            if (value) recovery = 0;
        end else if (remaining > 1) begin
            remaining = remaining - 1;
        end else if (remaining == 1) begin
            remaining = 0;
            if (value) expected_done = 1;
            else recovery = 1;
        end else if (!value) begin
            remaining = 9;
        end
        #1;
        checked = checked + 1;
        if (done !== expected_done)
            $fatal(1, "FAIL sample=%0d in=%b reset=%b expected=%b actual=%b", checked, value, rst, expected_done, done);
    endtask

    initial begin
        tick(1,1);
        repeat (5) tick(1,0);
        for (b=0; b<256; b=b+1) begin
            tick(0,0);
            for (j=0; j<8; j=j+1) tick((b >> j) & 1,0);
            tick(1,0);
        end
        tick(0,0);
        repeat (8) tick(1,0);
        tick(0,0);
        repeat (20) tick(0,0);
        tick(1,0);
        tick(0,0);
        repeat (8) tick(0,0);
        tick(1,0);
        // Assert reset between edges during a done pulse: it is synchronous.
        @(negedge clk);
        reset = 1;
        #1;
        if (done !== 1'b1) $fatal(1,"FAIL asynchronous reset effect");
        @(posedge clk);
        #1;
        if (done !== 1'b0) $fatal(1,"FAIL reset clearing done");
        remaining = 0;
        recovery = 0;
        for (k=0; k<11; k=k+1) begin
            tick(1,1);
            tick(0,0);
            for (j=0; j<k; j=j+1) tick(0,0);
            tick(0,1);
            tick(1,0);
        end
        for (k=0; k<10000; k=k+1) begin
            rng = rng ^ (rng << 13);
            rng = rng ^ (rng >> 17);
            rng = rng ^ (rng << 5);
            tick(rng[0], rng[7:1] == 7'd0);
        end
        $display("PASS: %0d checked serial samples", checked);
        $finish;
    end
    initial begin
        #200000;
        $fatal(1,"FAIL timeout");
    end
endmodule
