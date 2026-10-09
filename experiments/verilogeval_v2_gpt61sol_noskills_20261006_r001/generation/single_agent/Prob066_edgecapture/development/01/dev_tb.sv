`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    reg [31:0] in = 0;
    wire [31:0] out;
    reg previous_bit [0:31];
    reg captured_bit [0:31];
    reg [31:0] expected;
    reg [31:0] pattern;
    integer checks = 0;
    integer i;
    integer n;

    TopModule dut(.clk(clk), .reset(reset), .in(in), .out(out));

    task cycle(input reg rst, input reg [31:0] value);
        integer b;
        begin
            reset = rst;
            in = value;
            #2;
            clk = 1;
            for (b = 0; b < 32; b = b + 1) begin
                if (rst)
                    captured_bit[b] = 0;
                else if (previous_bit[b] == 1 && value[b] == 0)
                    captured_bit[b] = 1;
                previous_bit[b] = value[b];
                expected[b] = captured_bit[b];
            end
            #1;
            if (out !== expected)
                $fatal(1, "Cycle %0d: reset=%b in=%h expected=%h got=%h",
                       checks, rst, value, expected, out);
            checks = checks + 1;
            clk = 0;
            #2;
        end
    endtask

    initial begin
        // First reset establishes defined output and sampled input history.
        cycle(1, 32'hffffffff);
        cycle(0, 32'h00000000);
        cycle(0, 32'hffffffff);
        cycle(0, 32'hffffffff);
        // A reset suppresses coincident falling edges.
        cycle(1, 32'h00000000);
        cycle(0, 32'h00000000);
        // An input sampled during reset still precedes the next cycle.
        cycle(1, 32'haaaaaaaa);
        cycle(0, 32'h00000000);
        cycle(0, 32'h55555555);
        cycle(0, 32'h00000000);
        // Capture each bit independently, including the two boundary bits.
        for (i = 0; i < 32; i = i + 1) begin
            cycle(1, 0);
            cycle(0, 32'b1 << i);
            cycle(0, 0);
            cycle(0, 32'b1 << i);
            cycle(0, 0);
        end
        // Reset is synchronous: a pulse entirely between edges has no effect.
        cycle(1, 0);
        cycle(0, 32'h80000001);
        cycle(0, 0);
        reset = 1;
        #1;
        if (out !== 32'h80000001) $fatal(1, "Reset acted asynchronously");
        reset = 0;
        #1;
        cycle(0, 0);
        // Deterministic varied stimulus with periodic resets.
        pattern = 32'hc1935a7e;
        for (n = 0; n < 256; n = n + 1) begin
            pattern = {pattern[30:0], pattern[31] ^ pattern[21] ^ pattern[1] ^ pattern[0]};
            cycle((n % 19) == 0, pattern);
        end
        $display("PASS: %0d edge capture cycles checked", checks);
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
