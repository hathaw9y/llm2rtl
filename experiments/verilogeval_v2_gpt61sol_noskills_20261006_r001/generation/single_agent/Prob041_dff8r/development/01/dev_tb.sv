`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    reg [7:0] d = 0;
    wire [7:0] q;
    integer i;
    TopModule dut (.clk(clk), .reset(reset), .d(d), .q(q));

    task check;
        input [7:0] expected;
        begin
            if (q !== expected)
                $fatal(1, "q mismatch: expected %h got %h", expected, q);
        end
    endtask

    task cycle;
        input rst;
        input [7:0] data;
        reg [7:0] previous;
        begin
            previous = q;
            reset = rst;
            d = data;
            #2;
            check(previous);
            clk = 1;
            #1;
            if (rst) check(8'h00);
            else check(data);
            clk = 0;
            #1;
            if (rst) check(8'h00);
            else check(data);
        end
    endtask

    initial begin
        // Establish a known value by synchronous reset; no power-up value is specified.
        cycle(1, 8'hff);
        cycle(0, 8'ha5);
        // Reset assertion and input changes between edges must leave q unchanged.
        reset = 1;
        d = 8'h3c;
        #2; check(8'ha5);
        clk = 1;
        #1; check(8'h00);
        reset = 0;
        d = 8'hff;
        #2; check(8'h00);
        clk = 0;
        #1; check(8'h00);
        cycle(0, 8'hff);
        cycle(0, 8'h00);
        for (i = 0; i < 8; i = i + 1) begin
            cycle(0, 8'h01 << i);
            cycle(0, ~(8'h01 << i));
        end
        for (i = 0; i < 256; i = i + 1)
            cycle(0, i[7:0]);
        cycle(1, 8'hff);
        cycle(1, 8'h55);
        cycle(0, 8'h81);
        $display("PASS: synchronous reset, edge capture, hold behavior, and all byte values");
        $finish;
    end

    initial begin
        #5000;
        $fatal(1, "Timeout");
    end
endmodule
