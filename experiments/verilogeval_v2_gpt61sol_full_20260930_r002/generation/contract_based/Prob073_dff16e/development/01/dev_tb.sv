`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic resetn = 1;
    logic [1:0] byteena = 0;
    logic [15:0] d = 0;
    wire [15:0] q;
    logic [15:0] expected = 16'hxxxx;
    integer checks = 0;
    integer i;
    integer mask;
    TopModule dut (.clk(clk), .resetn(resetn), .byteena(byteena), .d(d), .q(q));

    task automatic compare;
        begin
            checks = checks + 1;
            if (q !== expected)
                $fatal(1, "Mismatch at %0t: q=%h expected=%h resetn=%b byteena=%b d=%h", $time, q, expected, resetn, byteena, d);
        end
    endtask

    // The oracle models each of the 16 stated DFFs independently.
    task automatic cycle(input logic rst, input logic [1:0] enables, input logic [15:0] data);
        integer bit_index;
        begin
            clk = 0;
            resetn = rst;
            byteena = enables;
            d = data;
            #2;
            compare(); // Neither reset assertion nor input changes are asynchronous.
            clk = 1;
            for (bit_index = 0; bit_index < 16; bit_index = bit_index + 1) begin
                if (!rst) expected[bit_index] = 1'b0;
                else if (enables[bit_index / 8]) expected[bit_index] = data[bit_index];
            end
            #1;
            compare(); // Observe after nonblocking assignment settlement.
            d = ~data;
            byteena = ~enables;
            resetn = ~rst;
            #1;
            compare();
            clk = 0;
            #1;
            compare(); // Falling edge does not capture changed inputs.
        end
    endtask

    initial begin
        #1;
        compare();
        cycle(1, 2'b00, 16'hffff);
        cycle(1, 2'b01, 16'h12a5); // Upper byte remains unknown.
        cycle(1, 2'b00, 16'hffff);
        cycle(1, 2'b10, 16'h5a00);
        cycle(0, 2'b00, 16'hffff);
        cycle(1, 2'b11, 16'ha55a);
        for (mask = 0; mask < 4; mask = mask + 1) begin
            cycle(0, mask[1:0], 16'hffff);
            cycle(1, 2'b11, 16'hc33c);
            cycle(1, mask[1:0], 16'h5aa5);
            cycle(1, 2'b00, 16'h0000);
        end
        for (i = 0; i < 16; i = i + 1) begin
            cycle(1, 2'b11, 16'h0001 << i);
            cycle(1, 2'b01, ~(16'h0001 << i));
            cycle(1, 2'b10, 16'h0001 << i);
        end
        cycle(1, 2'b11, 16'hffff);
        cycle(1, 2'b00, 16'h0000);
        cycle(1, 2'b11, 16'h0000);
        cycle(0, 2'b11, 16'hffff);
        cycle(0, 2'b01, 16'hffff);
        cycle(1, 2'b00, 16'hffff);
        $display("PASS: %0d comparisons completed", checks);
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
