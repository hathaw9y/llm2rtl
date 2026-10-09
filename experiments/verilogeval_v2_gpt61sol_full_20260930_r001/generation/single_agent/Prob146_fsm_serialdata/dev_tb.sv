`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic in = 1;
    logic reset = 0;
    wire [7:0] out_byte;
    wire done;
    integer checked_cycles = 0;
    TopModule dut (.clk(clk), .in(in), .reset(reset), .out_byte(out_byte), .done(done));
    always #5 clk = ~clk;

    task automatic step(input logic serial_bit, input logic rst,
                        input logic expected_done, input logic [7:0] expected_byte);
        @(negedge clk);
        in = serial_bit;
        reset = rst;
        @(posedge clk);
        #1;
        checked_cycles = checked_cycles + 1;
        if (done !== expected_done)
            $fatal(1, "done mismatch cycle %0d: got %b expected %b", checked_cycles, done, expected_done);
        if (expected_done && out_byte !== expected_byte)
            $fatal(1, "byte mismatch: got %h expected %h", out_byte, expected_byte);
    endtask

    task automatic frame(input logic [7:0] value, input logic good_stop);
        step(0, 0, 0, 0);
        for (integer b = 0; b < 8; b = b + 1)
            step(value[b], 0, 0, 0);
        step(good_stop, 0, good_stop, value);
    endtask

    initial begin
        step(1, 1, 0, 0);
        repeat (4) step(1, 0, 0, 0);
        for (integer value = 0; value < 256; value = value + 1)
            frame(8'(value), 1);
        step(1, 0, 0, 0);
        frame(8'ha6, 0);
        repeat (12) step(0, 0, 0, 0);
        step(1, 0, 0, 0);
        frame(8'h53, 1);
        // Reset at each position in an incomplete frame, including stop wait.
        for (integer position = 0; position < 10; position = position + 1) begin
            step(1, 1, 0, 0);
            step(0, 0, 0, 0);
            repeat (position) step(0, 0, 0, 0);
            step(0, 1, 0, 0);
            step(1, 0, 0, 0);
            frame(8'h81, 1);
        end
        step(1, 1, 0, 0);
        frame(8'hff, 1);
        step(0, 1, 0, 0);
        repeat (3) step(1, 0, 0, 0);
        $display("PASS: %0d checked cycles", checked_cycles);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "development test timeout");
    end
endmodule
