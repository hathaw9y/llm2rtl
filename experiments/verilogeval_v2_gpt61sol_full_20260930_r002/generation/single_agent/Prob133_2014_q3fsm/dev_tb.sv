`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic s = 0;
    logic w = 0;
    wire z;
    TopModule dut (.clk(clk), .reset(reset), .s(s), .w(w), .z(z));
    always #5 clk = ~clk;

    bit active = 0;
    integer samples = 0;
    integer ones = 0;
    logic expected = 0;
    integer checks = 0;
    integer pattern;
    integer k;
    integer random_index;
    reg [31:0] rng = 32'h137abcde;

    // Independent oracle: count input samples in successive blocks of three.
    task automatic tick(input bit rst, input bit start, input bit value);
        logic before_z;
        begin
            @(negedge clk);
            before_z = z;
            reset = rst;
            s = start;
            w = value;
            #1;
            if (z !== before_z)
                $fatal(1, "Output changed away from clock edge");
            @(posedge clk);
            if (rst) begin
                active = 0;
                samples = 0;
                ones = 0;
                expected = 0;
            end else if (!active) begin
                expected = 0;
                if (start) active = 1;
            end else begin
                expected = 0;
                samples = samples + 1;
                if (value) ones = ones + 1;
                if (samples == 3) begin
                    expected = (ones == 2);
                    samples = 0;
                    ones = 0;
                end
            end
            #1;
            if (z !== expected)
                $fatal(1, "Check %0d: z=%b expected=%b samples=%0d ones=%0d", checks, z, expected, samples, ones);
            checks = checks + 1;
        end
    endtask

    initial begin
        tick(1, 1, 1);
        repeat (5) tick(0, 0, 1);
        // Every pair of three-bit groups, including consecutive matches.
        for (pattern = 0; pattern < 64; pattern = pattern + 1) begin
            tick(1, 0, 0);
            tick(0, 0, 1);
            tick(0, 1, 1); // w on entry into B must not be sampled.
            for (k = 0; k < 6; k = k + 1)
                tick(0, k[0], ((pattern >> k) & 1));
            tick(0, 0, 0);
        end
        // Reset at each sampling phase and during an asserted result.
        for (k = 0; k < 4; k = k + 1) begin
            tick(1, 1, 1);
            tick(0, 1, 0);
            if (k >= 1) tick(0, 0, 1);
            if (k >= 2) tick(0, 0, 1);
            if (k >= 3) tick(0, 0, 0);
            tick(1, 1, 1);
            tick(0, 0, 1);
        end
        for (random_index = 0; random_index < 600; random_index = random_index + 1) begin
            rng = {rng[30:0], rng[31] ^ rng[21] ^ rng[1] ^ rng[0]};
            tick(rng[7:3] == 0, rng[1], rng[0]);
        end
        $display("PASS %0d cycle checks", checks);
        $finish;
    end
    initial begin
        #20000;
        $fatal(1, "Timeout");
    end
endmodule
