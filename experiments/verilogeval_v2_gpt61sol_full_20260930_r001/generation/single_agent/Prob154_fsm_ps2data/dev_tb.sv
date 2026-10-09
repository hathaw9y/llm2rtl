`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset;
    logic [7:0] in;
    wire [23:0] out_bytes;
    wire done;
    TopModule dut(.*);
    always #5 clk = ~clk;
    integer count = 0;
    integer checks = 0;
    logic pending = 0;
    logic expected_done;
    logic [23:0] assembled = 0;
    logic [23:0] expected_packet = 0;
    task automatic step(input logic rst, input logic [7:0] byte_in);
        begin
            @(negedge clk);
            reset = rst;
            in = byte_in;
            @(posedge clk);
            expected_done = pending;
            if (rst) begin
                count = 0;
                pending = 0;
                expected_done = 0;
            end else begin
                pending = 0;
                if (count == 0) begin
                    if (byte_in[3]) begin
                        assembled = {byte_in, 16'b0};
                        count = 1;
                    end
                end else if (count == 1) begin
                    assembled[15:8] = byte_in;
                    count = 2;
                end else begin
                    assembled[7:0] = byte_in;
                    count = 0;
                    pending = 1;
                    expected_packet = assembled;
                end
            end
            #1;
            if (done !== expected_done)
                $fatal(1, "done mismatch at check %0d", checks);
            if (expected_done && out_bytes !== expected_packet)
                $fatal(1, "packet mismatch at check %0d: %h expected %h", checks, out_bytes, expected_packet);
            checks = checks + 1;
        end
    endtask
    initial begin
        reset = 1;
        in = 0;
        step(1, 0);
        step(0, 8'h2c); step(0, 8'h81); step(0, 8'h09);
        step(0, 8'h6b); step(0, 8'h0d); step(0, 8'h8d);
        step(0, 8'h6d); step(0, 8'h12); step(0, 8'h01);
        step(0, 8'h0d); step(0, 8'h76); step(0, 8'h3d);
        step(0, 8'hed); step(0, 8'h8c); step(0, 8'hf9);
        step(0, 8'hce); step(0, 8'hc5); step(0, 8'haa);
        // Search gaps, unrestricted payload bytes, and reset in each phase.
        for (integer phase = 0; phase < 4; phase = phase + 1) begin
            step(1, 8'hff);
            for (integer j = 0; j < phase; j = j + 1) step(0, 8'hff);
            step(1, 8'hff);
            step(0, 8'h00); step(0, 8'hf7);
            step(0, 8'h08); step(0, 8'h00); step(0, 8'hff);
            step(0, 8'h00);
        end
        for (integer k = 0; k < 2000; k = k + 1)
            step(($urandom_range(0, 39) == 0), $urandom);
        step(1, 0);
        $display("PASS: %0d checked cycles", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "testbench timeout");
    end
endmodule
