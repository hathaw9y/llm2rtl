`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg load = 0;
    reg [1:0] ena = 0;
    reg [99:0] data = 0;
    wire [99:0] q;
    reg [99:0] expected;
    reg [99:0] next_expected;
    reg [99:0] pattern;
    reg [31:0] rng = 32'h714c5a39;
    integer steps = 0;
    integer i, j, k;
    TopModule dut(.clk(clk), .load(load), .ena(ena), .data(data), .q(q));

    task check;
        input [99:0] value;
        begin
            if (q !== value)
                $fatal(1, "Mismatch step=%0d clk=%b load=%b ena=%b expected=%h got=%h",
                       steps, clk, load, ena, value, q);
        end
    endtask

    task cycle;
        input ld;
        input [1:0] en;
        input [99:0] word;
        integer bit_index;
        begin
            load = ld;
            ena = en;
            data = word;
            #2;
            check(expected);
            next_expected = expected;
            if (ld) next_expected = word;
            else if (en == 2'b01) begin
                for (bit_index=0; bit_index<100; bit_index=bit_index+1)
                    next_expected[bit_index] = expected[(bit_index+1)%100];
            end else if (en == 2'b10) begin
                for (bit_index=0; bit_index<100; bit_index=bit_index+1)
                    next_expected[bit_index] = expected[(bit_index+99)%100];
            end
            clk = 1;
            #1;
            expected = next_expected;
            steps = steps + 1;
            check(expected);
            clk = 0;
            #1;
            check(expected);
        end
    endtask

    initial begin
        expected = {100{1'bx}};
        #1;
        check(expected);
        cycle(0, 0, 0);
        cycle(0, 3, {100{1'b1}});
        cycle(0, 1, 0);
        cycle(0, 2, 0);
        // Synchronous loading and load priority for every enable value.
        for (i=0; i<4; i=i+1) begin
            pattern = 0;
            for (j=0; j<100; j=j+1)
                pattern[j] = ((j+i)%3 == 0);
            cycle(1, i, pattern);
            cycle(0, 0, ~pattern);
            cycle(0, 3, ~pattern);
        end
        // Uniform words remain uniform in either direction.
        for (i=0; i<2; i=i+1) begin
            pattern = {100{1'b0}};
            if (i == 1) pattern = {100{1'b1}};
            cycle(1, 0, pattern);
            cycle(0, 1, 0);
            cycle(0, 2, 0);
        end
        // Traverse every bit and each wrap boundary in both directions.
        pattern = 100'b1;
        cycle(1, 1, pattern);
        for (i=0; i<100; i=i+1) cycle(0, 1, 0);
        check(pattern);
        pattern = 0;
        pattern[99] = 1;
        cycle(1, 2, pattern);
        for (i=0; i<100; i=i+1) cycle(0, 2, 0);
        check(pattern);
        // Mixed reproducible data, loads, rotates and holds.
        for (i=0; i<300; i=i+1) begin
            for (k=0; k<100; k=k+1) begin
                rng = {rng[30:0], rng[31]^rng[21]^rng[1]^rng[0]};
                pattern[k] = rng[0];
            end
            cycle((i%13)==0, rng[3:2], pattern);
        end
        $display("PASS: %0d rotator cycles and phase checks", steps);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
