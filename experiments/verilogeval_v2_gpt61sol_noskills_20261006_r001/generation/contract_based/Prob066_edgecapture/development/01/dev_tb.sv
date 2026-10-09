`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    reg [31:0] in = 0;
    wire [31:0] out;
    reg [31:0] expected;
    reg [31:0] last_sample;
    reg [31:0] random_state = 32'h9e3779b9;
    reg [31:0] held;
    integer checks = 0;
    integer i;
    integer b;
    TopModule dut (.clk(clk), .reset(reset), .in(in), .out(out));

    // Per-bit oracle: use the previous clock's sample, then remember this one.
    task tick(input reg rst, input reg [31:0] value);
        integer k;
        begin
            clk = 0;
            reset = rst;
            in = value;
            #4;
            if (rst)
                expected = 0;
            else
                for (k = 0; k < 32; k = k + 1)
                    if ((last_sample[k] === 1'b1) && (value[k] === 1'b0))
                        expected[k] = 1'b1;
            last_sample = value;
            clk = 1;
            #1;
            checks = checks + 1;
            if (out !== expected)
                $fatal(1, "Check %0d: reset=%b in=%h expected=%h got=%h",
                       checks, rst, value, expected, out);
            clk = 0;
            #1;
        end
    endtask

    initial begin
        // Establish known output through the specified synchronous reset.
        tick(1, 32'hffffffff);
        // A falling transition immediately after reset uses the preceding sample.
        tick(0, 32'h00000000);
        tick(0, 32'hffffffff);
        tick(0, 32'hffffffff);

        // Reset must wait for a rising edge.
        held = out;
        reset = 1;
        in = 0;
        #2;
        if (out !== held) $fatal(1, "Reset acted without a rising edge");
        tick(1, 0);
        tick(1, 32'hffffffff); // reset wins over any transitions
        tick(1, 0);
        tick(0, 0);
        tick(0, 32'hffffffff); // rising edges do not capture
        tick(0, 32'hffffffff);
        tick(0, 32'h55555555);
        tick(0, 32'haaaaaaaa);
        tick(0, 32'hffffffff); // captures remain sticky

        for (b = 0; b < 32; b = b + 1) begin
            tick(1, 0);
            tick(0, 32'b1 << b);
            tick(0, 0);
            tick(0, 32'b1 << b);
            tick(0, 0);
        end

        // A pulse wholly between sampling edges is not a sampled transition.
        tick(1, 0);
        reset = 0;
        in = 32'hffffffff;
        #1;
        in = 0;
        #1;
        if (out !== 0) $fatal(1, "Input pulse changed output without clock");
        tick(0, 0);

        for (i = 0; i < 256; i = i + 1) begin
            random_state = random_state ^ (random_state << 13);
            random_state = random_state ^ (random_state >> 17);
            random_state = random_state ^ (random_state << 5);
            tick((i % 17) == 0, random_state);
        end
        $display("PASS: %0d sampled checks plus synchronous timing checks", checks);
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Bounded timeout");
    end
endmodule
