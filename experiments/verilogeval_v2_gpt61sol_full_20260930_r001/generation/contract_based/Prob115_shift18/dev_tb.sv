`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic load = 0, ena = 0;
    logic [1:0] amount = 0;
    logic [63:0] data = 0;
    wire [63:0] q;
    logic [63:0] expected;
    logic [31:0] rng = 32'h13579bdf;
    integer checks = 0;
    TopModule dut (.clk(clk), .load(load), .ena(ena), .amount(amount), .data(data), .q(q));
    always #5 clk = ~clk;

    function automatic [63:0] model_shift(input logic [63:0] value, input logic [1:0] mode);
        integer distance, source, bit_index;
        begin
            distance = mode[0] ? 8 : 1;
            for (bit_index = 0; bit_index < 64; bit_index = bit_index + 1) begin
                source = mode[1] ? bit_index + distance : bit_index - distance;
                if (source < 0) model_shift[bit_index] = 1'b0;
                else if (source >= 64) model_shift[bit_index] = value[63];
                else model_shift[bit_index] = value[source];
            end
        end
    endfunction

    function automatic [31:0] next_random(input logic [31:0] state);
        logic [31:0] value;
        begin
            value = state ^ (state << 13);
            value = value ^ (value >> 17);
            next_random = value ^ (value << 5);
        end
    endfunction

    task automatic step(input logic ld, input logic en, input logic [1:0] mode, input logic [63:0] word);
        logic [63:0] prior;
        begin
            @(negedge clk);
            prior = q;
            load = ld; ena = en; amount = mode; data = word;
            #1;
            if (q !== prior) $fatal(1, "Asynchronous state change");
            if (ld) expected = word;
            else if (en) expected = model_shift(expected, mode);
            @(posedge clk);
            #1;
            checks = checks + 1;
            if (q !== expected) $fatal(1, "Check %0d: q=%h expected=%h", checks, q, expected);
        end
    endtask

    initial begin
        step(1, 0, 0, 64'h0123456789abcdef);
        for (integer mode = 0; mode < 4; mode = mode + 1) begin
            step(1, 1, mode[1:0], 64'h8123456789abcdef);
            step(0, 0, mode[1:0], 64'hffffffffffffffff);
            step(0, 1, mode[1:0], 0);
            step(1, 0, mode[1:0], 64'h7123456789abcdef);
            step(0, 1, mode[1:0], 0);
            step(1, 1, mode[1:0], 64'h8000000000000001);
            repeat (70) step(0, 1, mode[1:0], 0);
            step(1, 0, mode[1:0], 64'hffffffffffffffff);
            step(0, 1, mode[1:0], 0);
            step(1, 1, mode[1:0], 0);
            step(0, 1, mode[1:0], 0);
        end
        for (integer trial = 0; trial < 1000; trial = trial + 1) begin
            logic [31:0] controls, upper, lower;
            rng = next_random(rng); controls = rng;
            rng = next_random(rng); upper = rng;
            rng = next_random(rng); lower = rng;
            step(controls[0] & controls[1], controls[2], controls[4:3], {upper, lower});
        end
        $display("PASS: %0d post-edge checks plus synchronous stability checks", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Watchdog timeout");
    end
endmodule
