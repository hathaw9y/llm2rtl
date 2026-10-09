`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic resetn = 1;
    logic in = 0;
    wire out;
    logic history [0:3];
    bit known = 0;
    integer checks = 0;
    integer pattern;
    integer index;
    integer cycle;
    logic [15:0] sequence_r = 16'hace1;

    TopModule dut (.clk(clk), .resetn(resetn), .in(in), .out(out));
    always #5 clk = ~clk;

    task automatic compare_output;
        if (known) begin
            if (out !== history[3])
                $fatal(1, "Mismatch at %0t: out=%b expected=%b resetn=%b", $time, out, history[3], resetn);
            checks = checks + 1;
        end
    endtask

    always @(posedge clk) begin
        // Oracle uses four independent stages, preserving old downstream values.
        if (!resetn) begin
            history[0] = 0;
            history[1] = 0;
            history[2] = 0;
            history[3] = 0;
            known = 1;
        end else if (known) begin
            history[3] = history[2];
            history[2] = history[1];
            history[1] = history[0];
            history[0] = in;
        end
        #1;
        compare_output();
    end

    task automatic drive_cycle(input logic bit_in, input logic rn);
        @(negedge clk);
        compare_output();
        in = bit_in;
        resetn = rn;
        #2;
        compare_output(); // Synchronous reset and input cannot affect out here.
        @(posedge clk);
        #2;
        compare_output();
    endtask

    initial begin
        // First reset is between edges; no assumption about power-up state.
        #2 resetn = 0;
        @(posedge clk);
        #2 compare_output();
        drive_cycle(1, 0);
        drive_cycle(0, 0);
        drive_cycle(1, 1);
        repeat (7) drive_cycle(0, 1);
        repeat (5) drive_cycle(1, 1);
        // Assert/deassert reset entirely between rising edges while out is one.
        @(negedge clk);
        resetn = 0;
        #1 compare_output();
        resetn = 1;
        #1 compare_output();
        drive_cycle(1, 0); // Clear occupied pipeline, despite high input.
        drive_cycle(1, 1);
        drive_cycle(0, 1);
        drive_cycle(1, 1);
        drive_cycle(0, 1);
        for (pattern = 0; pattern < 16; pattern = pattern + 1) begin
            drive_cycle(0, 0);
            for (index = 3; index >= 0; index = index - 1)
                drive_cycle((pattern >> index) & 1, 1);
            repeat (4) drive_cycle(0, 1);
        end
        for (cycle = 0; cycle < 100; cycle = cycle + 1) begin
            sequence_r = {sequence_r[14:0], sequence_r[15] ^ sequence_r[13] ^ sequence_r[12] ^ sequence_r[10]};
            drive_cycle(sequence_r[0], (cycle % 19 != 0));
        end
        $display("PASS four-stage shift register: %0d comparisons", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
