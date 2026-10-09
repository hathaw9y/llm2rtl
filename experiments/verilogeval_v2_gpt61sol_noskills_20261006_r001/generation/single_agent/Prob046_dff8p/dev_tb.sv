`timescale 1ns/1ps
module dev_tb;
    reg clk = 1'b0;
    reg reset = 1'b0;
    reg [7:0] d = 8'h00;
    wire [7:0] q;
    reg [7:0] expected;
    integer i;
    TopModule dut (.clk(clk), .reset(reset), .d(d), .q(q));

    task check;
        input [7:0] value;
        begin
            if (q !== value)
                $fatal(1, "q mismatch: expected %h, got %h at %t", value, q, $time);
        end
    endtask

    // Each cycle checks input changes, rising-edge hold, falling-edge capture,
    // and input changes after capture. Reset is sampled only on falling edges.
    task cycle;
        input rst;
        input [7:0] data;
        begin
            reset = rst;
            d = data;
            #2; check(expected);
            clk = 1;
            #2; check(expected);
            clk = 0;
            if (rst) expected = 8'h34;
            else expected = data;
            #1; check(expected);
            d = ~data;
            #1; check(expected);
        end
    endtask

    initial begin
        // Establish state via synchronous reset; no power-up value is assumed.
        #1;
        clk = 1;
        reset = 1;
        d = 8'hff;
        #2;
        clk = 0;
        expected = 8'h34;
        #1; check(expected);
        cycle(0, 8'h00);
        // Reset assertion between edges must leave an existing value intact.
        cycle(1, 8'hff);
        cycle(1, 8'h00);
        cycle(0, 8'hff);
        cycle(0, 8'haa);
        cycle(0, 8'h55);
        for (i = 0; i < 256; i = i + 1)
            cycle(0, i[7:0]);
        for (i = 0; i < 8; i = i + 1) begin
            cycle(1, 8'h01 << i);
            cycle(0, 8'h01 << i);
        end
        $display("PASS: falling-edge DFF capture, synchronous reset to 0x34, and hold checks");
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
