`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    wire [2:0] ena;
    wire [15:0] q;
    integer expected = 0;
    integer cycles = 0;
    integer i;
    TopModule dut(.clk(clk), .reset(reset), .ena(ena), .q(q));

    task check;
        reg [15:0] bcd;
        reg [2:0] enables;
        begin
            bcd[3:0] = expected % 10;
            bcd[7:4] = (expected / 10) % 10;
            bcd[11:8] = (expected / 100) % 10;
            bcd[15:12] = expected / 1000;
            enables[0] = (expected % 10 == 9);
            enables[1] = (expected % 100 == 99);
            enables[2] = (expected % 1000 == 999);
            if (q !== bcd) $fatal(1,"Count mismatch cycle=%0d expected=%h got=%h", cycles,bcd,q);
            if (ena !== enables) $fatal(1,"Enable mismatch count=%0d expected=%b got=%b",expected,enables,ena);
        end
    endtask

    task tick;
        begin
            #2; clk = 1;
            if (reset) expected = 0;
            else expected = (expected + 1) % 10000;
            cycles = cycles + 1;
            #1; check;
            clk = 0;
            #1; check;
        end
    endtask

    initial begin
        // The original specification supplies no power-up state.
        // Establish a known state only with a synchronous reset edge.
        reset = 1;
        tick;
        tick;
        reset = 0;
        for (i = 0; i < 20005; i = i + 1) tick;
        // Reset between clock edges must not change the count.
        reset = 1;
        #1; check;
        tick;
        tick;
        reset = 0;
        for (i = 0; i < 999; i = i + 1) tick;
        // At 0999 the carry enables remain visible before the reset edge.
        reset = 1;
        #1; check;
        tick;
        reset = 0;
        for (i = 0; i < 12; i = i + 1) tick;
        $display("PASS: decimal counting, all carries, wraparound, enables and synchronous reset (%0d edges)",cycles);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1,"Timeout");
    end
endmodule
