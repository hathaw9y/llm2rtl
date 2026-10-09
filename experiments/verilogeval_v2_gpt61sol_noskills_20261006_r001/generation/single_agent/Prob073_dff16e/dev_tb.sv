`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg resetn = 1;
    reg [1:0] byteena = 0;
    reg [15:0] d = 0;
    wire [15:0] q;
    reg [15:0] expected;
    integer checks = 0;
    integer i;
    TopModule dut(.clk(clk), .resetn(resetn), .byteena(byteena), .d(d), .q(q));

    task check_q;
        begin
            if (q !== expected)
                $fatal(1, "Mismatch at %0t: q=%h expected=%h", $time, q, expected);
            checks = checks + 1;
        end
    endtask

    task cycle(input reg rn, input reg [1:0] enables, input reg [15:0] value);
        reg [15:0] mask;
        begin
            // Change inputs while clock is low: synchronous state must hold.
            resetn = rn;
            byteena = enables;
            d = value;
            #2; check_q;
            mask = {{8{enables[1]}}, {8{enables[0]}}};
            if (!rn) expected = 16'h0000;
            else expected = (expected & ~mask) | (value & mask);
            clk = 1;
            #1; check_q;
            // Input changes while clock is high also must not update state.
            d = ~value;
            #1; check_q;
            clk = 0;
            #1; check_q;
        end
    endtask

    initial begin
        // Establish a defined state with the first synchronous reset edge.
        resetn = 0;
        byteena = 3;
        d = 16'hffff;
        #2; clk = 1;
        expected = 0;
        #1; check_q;
        clk = 0;
        #1; check_q;
        cycle(1, 3, 16'h1234);
        cycle(1, 1, 16'habcd);
        cycle(1, 2, 16'h5678);
        cycle(1, 0, 16'hffff);
        // A reset pulse with no positive edge must leave the register intact.
        resetn = 0;
        #2; check_q;
        resetn = 1;
        #2; check_q;
        // Reset overrides every enable combination.
        for (i = 0; i < 4; i = i + 1) begin
            cycle(1, 3, 16'hffff);
            cycle(0, i[1:0], 16'hffff);
            cycle(1, 0, 16'habcd);
        end
        // Exercise all enable patterns with distinct byte data and extremes.
        for (i = 0; i < 256; i = i + 1)
            cycle(1, i[1:0], {i[7:0], ~i[7:0]});
        cycle(1, 3, 16'h0000);
        cycle(1, 1, 16'hffff);
        cycle(1, 2, 16'hffff);
        cycle(1, 0, 16'h0000);
        $display("PASS: %0d synchronous reset, byte-enable, and edge checks", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
