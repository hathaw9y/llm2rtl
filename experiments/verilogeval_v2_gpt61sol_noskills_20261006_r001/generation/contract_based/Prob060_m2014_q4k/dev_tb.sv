`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg resetn = 1;
    reg in = 0;
    wire out;
    TopModule dut(.clk(clk), .resetn(resetn), .in(in), .out(out));

    // Ring of input samples: output is the sample three edges before
    // the current one. A reset edge starts a new zero-filled history.
    reg samples [0:3];
    integer head = 0;
    integer checks = 0;
    integer i;
    integer j;
    reg known = 0;
    reg expected;
    reg previous;
    reg [15:0] stimulus = 16'h9a35;

    task step(input reg data, input reg rn);
        begin
            previous = expected;
            in = data;
            resetn = rn;
            #2;
            if (known && out !== previous)
                $fatal(1, "Output changed without rising edge: expected %b got %b", previous, out);
            #3;
            clk = 1;
            if (!rn) begin
                for (j = 0; j < 4; j = j + 1) samples[j] = 0;
                head = 0;
                expected = 0;
                known = 1;
            end else if (known) begin
                samples[head] = data;
                head = (head + 1) % 4;
                expected = samples[head];
            end
            #1;
            if (known && out !== expected)
                $fatal(1, "Rising-edge mismatch at check %0d: expected %b got %b", checks, expected, out);
            checks = checks + 1;
            #2;
            clk = 0;
            in = ~data;
            #1;
            if (known && out !== expected)
                $fatal(1, "Output changed on falling edge/input change");
        end
    endtask

    initial begin
        // Establish state only through the specified synchronous reset.
        step(1, 0);
        step(1, 1);
        for (i = 0; i < 7; i = i + 1) step(0, 1);
        for (i = 0; i < 8; i = i + 1) step(1, 1);
        // Reset asserts while output is high, but takes effect only at edge.
        step(1, 0);
        step(0, 0);
        for (i = 0; i < 12; i = i + 1) step(i % 2, 1);
        for (i = 0; i < 128; i = i + 1) begin
            stimulus = {stimulus[14:0], stimulus[15] ^ stimulus[13] ^ stimulus[12] ^ stimulus[10]};
            step(stimulus[0], (i % 19 != 7));
        end
        step(0, 0);
        for (i = 0; i < 5; i = i + 1) step(0, 1);
        $display("PASS: four-stage shift and synchronous reset, %0d cycles", checks);
        $finish;
    end
    initial begin
        #5000;
        $fatal(1, "Bounded timeout");
    end
endmodule
