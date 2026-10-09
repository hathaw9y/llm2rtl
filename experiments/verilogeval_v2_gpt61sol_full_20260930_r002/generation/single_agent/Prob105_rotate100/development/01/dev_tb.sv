`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic load = 0;
    logic [1:0] ena = 0;
    logic [99:0] data = 0;
    wire [99:0] q;
    logic [99:0] expected = 'x;
    logic [99:0] previous;
    logic [99:0] next_expected;
    logic [99:0] pattern;
    integer cycles = 0;
    TopModule dut (.clk(clk), .load(load), .ena(ena), .data(data), .q(q));
    always #5 clk = ~clk;

    task automatic step(input logic ld, input logic [1:0] mode,
                        input logic [99:0] payload);
        @(negedge clk);
        previous = expected;
        load = ld;
        ena = mode;
        data = payload;
        #1;
        if (q !== previous) $fatal(1, "Output changed without rising edge");
        next_expected = expected;
        if (ld) next_expected = payload;
        else if (mode == 2'b01) begin
            for (integer bit_index = 0; bit_index < 100; bit_index = bit_index + 1)
                next_expected[bit_index] = expected[(bit_index + 1) % 100];
        end else if (mode == 2'b10) begin
            for (integer bit_index = 0; bit_index < 100; bit_index = bit_index + 1)
                next_expected[bit_index] = expected[(bit_index + 99) % 100];
        end
        @(posedge clk);
        #1;
        expected = next_expected;
        cycles = cycles + 1;
        if (q !== expected)
            $fatal(1, "Cycle %0d: load=%b ena=%b expected=%h actual=%h", cycles, ld, mode, expected, q);
    endtask

    initial begin
        #1;
        if (q !== {100{1'bx}}) $fatal(1, "Register unexpectedly initialized");
        step(0, 2'b00, '0);
        step(0, 2'b11, '1);
        step(1, 2'b01, 100'b1);
        step(0, 2'b01, '0);
        step(0, 2'b10, '0);
        step(1, 2'b10, {1'b1, 99'b0});
        step(0, 2'b10, '0);
        step(0, 2'b01, '0);
        step(1, 2'b00, '0);
        step(0, 2'b10, '1);
        step(1, 2'b11, '1);
        step(0, 2'b01, '0);
        pattern = 100'h8a76543210fedcba987654321;
        step(1, 2'b00, pattern);
        repeat (100) step(0, 2'b01, '0);
        if (q !== pattern) $fatal(1, "Right full revolution failed");
        repeat (100) step(0, 2'b10, '0);
        if (q !== pattern) $fatal(1, "Left full revolution failed");
        step(0, 2'b00, ~pattern);
        step(0, 2'b11, ~pattern);
        for (integer iteration = 0; iteration < 200; iteration = iteration + 1) begin
            pattern = {$urandom, $urandom, $urandom, $urandom};
            step((iteration % 7) == 0, iteration % 4, pattern);
        end
        $display("PASS rotator: %0d checked cycles", cycles);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
