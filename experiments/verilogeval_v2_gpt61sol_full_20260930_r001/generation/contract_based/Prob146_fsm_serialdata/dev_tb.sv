`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic in = 1;
    logic reset = 0;
    wire [7:0] out_byte;
    wire done;
    TopModule dut (.clk(clk), .in(in), .reset(reset), .out_byte(out_byte), .done(done));
    always #5 clk = ~clk;

    integer phase = -1; // -1 idle, 0..7 data, 8 stop, 9 recovery
    logic [7:0] expected_byte = 0;
    logic expected_done;
    integer samples = 0;
    integer completions = 0;
    integer i, j;
    logic [31:0] rng = 32'h7259ab13;

    task automatic tick(input logic bit_value, input logic rst_value);
        @(negedge clk);
        in = bit_value;
        reset = rst_value;
        @(posedge clk);
        expected_done = 0;
        if (rst_value) begin
            phase = -1;
            expected_byte = 0;
        end else if (phase == -1) begin
            if (!bit_value) phase = 0;
        end else if (phase < 8) begin
            expected_byte[phase] = bit_value;
            phase = phase + 1;
        end else if (phase == 8) begin
            if (bit_value) begin
                expected_done = 1;
                phase = -1;
            end else phase = 9;
        end else if (bit_value) phase = -1;
        #1;
        samples = samples + 1;
        if (done !== expected_done)
            $fatal(1, "done mismatch sample %0d phase %0d actual %b expected %b", samples, phase, done, expected_done);
        if (expected_done) begin
            completions = completions + 1;
            if (out_byte !== expected_byte)
                $fatal(1, "byte mismatch sample %0d actual %h expected %h", samples, out_byte, expected_byte);
        end
    endtask

    task automatic frame(input logic [7:0] payload, input logic stop_bit);
        integer k;
        tick(0,0);
        for (k=0; k<8; k=k+1) tick(payload[k],0);
        tick(stop_bit,0);
    endtask

    initial begin
        tick(1,1);
        repeat (12) tick(1,0);
        for (i=0; i<256; i=i+1) frame(i[7:0],1);
        frame(8'ha5,0);
        repeat (20) tick(0,0);
        tick(1,0);
        frame(8'h96,1);
        // Reset after every possible prefix, including stop/recovery phase.
        for (i=0; i<=10; i=i+1) begin
            tick(1,1);
            tick(0,0);
            for (j=0; j<i; j=j+1) tick(0,0);
            tick(0,1);
            tick(1,0);
            frame(8'h81,1);
        end
        // Synchronous reset has no effect between rising edges.
        frame(8'h42,1);
        @(negedge clk);
        reset = 1;
        #1;
        if (done !== 1 || out_byte !== 8'h42)
            $fatal(1, "reset acted asynchronously");
        reset = 0;
        tick(1,0);
        for (i=0; i<12000; i=i+1) begin
            rng = rng ^ (rng << 13);
            rng = rng ^ (rng >> 17);
            rng = rng ^ (rng << 5);
            tick(rng[0], rng[9:4] == 0);
        end
        tick(1,1);
        frame(8'hff,1);
        $display("PASS: %0d samples checked, %0d valid frames", samples, completions);
        $finish;
    end
    initial begin
        #300000;
        $fatal(1, "testbench timeout");
    end
endmodule
