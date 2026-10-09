`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg resetn = 1;
    reg in = 0;
    wire out;
    reg expected [0:3];
    reg valid = 0;
    reg held;
    integer i;
    integer cycles = 0;
    reg [15:0] pattern = 16'hace1;
    TopModule dut(.clk(clk), .resetn(resetn), .in(in), .out(out));

    task cycle(input reg reset_value, input reg data_value);
        integer j;
        begin
            held = out;
            resetn = reset_value;
            in = data_value;
            #2;
            if (valid && out !== held)
                $fatal(1, "Output changed without a rising edge at cycle %0d", cycles);
            clk = 1;
            if (!reset_value) begin
                for (j = 0; j < 4; j = j + 1) expected[j] = 0;
                valid = 1;
            end else begin
                for (j = 3; j > 0; j = j - 1) expected[j] = expected[j-1];
                expected[0] = data_value;
            end
            #1;
            if (valid && out !== expected[3])
                $fatal(1, "Cycle %0d: expected %b, got %b", cycles, expected[3], out);
            held = out;
            clk = 0;
            #1;
            if (out !== held) $fatal(1, "Output changed on falling edge");
            cycles = cycles + 1;
        end
    endtask

    initial begin
        cycle(0, 1); // Reset dominates input.
        cycle(1, 1); // Single impulse emerges on the fourth sampling edge.
        cycle(1, 0);
        cycle(1, 0);
        cycle(1, 0);
        cycle(1, 0);
        for (i = 0; i < 6; i = i + 1) cycle(1, 1);
        // A reset pulse with no rising clock edge must not clear stored ones.
        resetn = 0;
        in = 0;
        #2;
        if (out !== 1'b1) $fatal(1, "Reset incorrectly acted asynchronously");
        resetn = 1;
        #2;
        if (out !== 1'b1) $fatal(1, "Between-edge reset pulse changed output");
        cycle(1, 1);
        cycle(0, 1);
        cycle(0, 0);
        for (i = 0; i < 10; i = i + 1) cycle(1, i % 2);
        for (i = 0; i < 100; i = i + 1) begin
            pattern = {pattern[14:0], pattern[15] ^ pattern[13] ^ pattern[12] ^ pattern[10]};
            cycle((i % 17 != 0), pattern[0]);
        end
        repeat (5) cycle(1, 0);
        $display("PASS: four-stage shift, reset priority, synchronous reset, and edge hold checks");
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
