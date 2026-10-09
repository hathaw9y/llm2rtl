`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic load = 0;
    logic [1:0] ena = 0;
    logic [99:0] data = 0;
    wire [99:0] q;
    logic [99:0] expected;
    logic [99:0] prior;
    logic [99:0] next_expected;
    logic [99:0] pattern;
    integer checks = 0;
    integer i, j;
    TopModule dut (.clk(clk), .load(load), .ena(ena), .data(data), .q(q));
    always #5 clk = ~clk;
    initial begin
        #100000;
        $fatal(1, "Timeout");
    end
    task automatic step(input logic ld, input logic [1:0] en, input logic [99:0] payload);
        integer bit_index;
        begin
            @(negedge clk);
            prior = q;
            load = ld;
            ena = en;
            data = payload;
            next_expected = expected;
            if (ld) next_expected = payload;
            else if (en == 2'b01) begin
                for (bit_index=0; bit_index<100; bit_index=bit_index+1)
                    next_expected[bit_index] = expected[(bit_index+1)%100];
            end else if (en == 2'b10) begin
                for (bit_index=0; bit_index<100; bit_index=bit_index+1)
                    next_expected[bit_index] = expected[(bit_index+99)%100];
            end
            #2;
            if (q !== prior) $fatal(1, "Asynchronous output change");
            @(posedge clk);
            #1;
            expected = next_expected;
            if (q !== expected)
                $fatal(1, "Mismatch check %0d load=%b ena=%b got=%h expected=%h", checks, ld, en, q, expected);
            checks = checks + 1;
        end
    endtask
    initial begin
        // No specified power-up value: initialize the oracle and DUT by load.
        expected = 'x;
        step(1, 0, 100'b1);
        for (i=0; i<4; i=i+1) begin
            pattern = {100{1'b1}} ^ (100'b1 << (i*31));
            step(1, i[1:0], pattern);
            step(0, 0, ~pattern);
            step(0, 3, ~pattern);
        end
        for (i=0; i<100; i=i+1) begin
            pattern = 100'b1 << i;
            step(1, 3, pattern);
            step(0, 1, 0);
            step(0, 2, 0);
            step(0, 2, 0);
            step(0, 1, 0);
        end
        pattern = 100'h0123456789abcdef012345678;
        step(1, 1, pattern);
        for (j=0; j<100; j=j+1) step(0, 1, 0);
        if (q !== pattern) $fatal(1, "Right rotation period");
        for (j=0; j<100; j=j+1) step(0, 2, 0);
        if (q !== pattern) $fatal(1, "Left rotation period");
        step(1, 2, 0);
        step(0, 1, '1);
        step(0, 2, '1);
        step(1, 1, '1);
        step(0, 1, 0);
        step(0, 2, 0);
        for (i=0; i<100; i=i+1) pattern[i] = i%2;
        step(1, 0, pattern);
        step(0, 1, 0);
        step(0, 2, 0);
        for (j=0; j<300; j=j+1) begin
            for (i=0; i<100; i=i+1) pattern[i] = $urandom_range(0,1);
            step((j%7)==0, j%4, pattern);
        end
        $display("PASS %0d rotator checks", checks);
        $finish;
    end
endmodule
