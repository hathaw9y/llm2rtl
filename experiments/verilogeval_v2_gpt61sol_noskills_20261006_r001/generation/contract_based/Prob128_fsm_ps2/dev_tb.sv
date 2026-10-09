`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    reg [7:0] in = 0;
    wire done;
    integer remaining = 0;
    reg expected = 0;
    reg established = 0;
    integer checks = 0;
    integer a, b, c, position, j;
    reg [31:0] rng = 32'h13579bdf;
    TopModule dut (.clk(clk), .reset(reset), .in(in), .done(done));
    always #5 clk = ~clk;

    // Oracle counts outstanding bytes, independently of the DUT's states.
    task tick(input reg rst, input reg [7:0] value);
        begin
            @(negedge clk);
            reset = rst;
            in = value;
            #1;
            if (established && done !== expected)
                $fatal(1, "Output changed between clock edges: expected %b got %b", expected, done);
            @(posedge clk);
            if (rst) begin
                remaining = 0;
                expected = 0;
                established = 1;
            end else begin
                expected = 0;
                if (remaining != 0) begin
                    remaining = remaining - 1;
                    if (remaining == 0) expected = 1;
                end else if (value[3]) remaining = 2;
            end
            #1;
            if (done !== expected)
                $fatal(1, "Check %0d reset=%b byte=%h outstanding=%0d expected=%b got=%b", checks, rst, value, remaining, expected, done);
            checks = checks + 1;
        end
    endtask

    initial begin
        tick(1, 8'hff);
        tick(1, 8'h00);
        for (j = 0; j < 16; j = j + 1) tick(0, 8'hf7);
        // All marker-bit combinations in bytes 2 and 3; immediate next messages.
        for (a = 0; a < 2; a = a + 1)
            for (b = 0; b < 2; b = b + 1) begin
                tick(0, 8'h08);
                tick(0, a ? 8'hff : 8'h00);
                tick(0, b ? 8'h08 : 8'hf7);
            end
        tick(0, 8'h00);
        tick(0, 8'h00);
        // Every possible byte value as a search candidate, reset for each trial.
        for (c = 0; c < 256; c = c + 1) begin
            tick(1, 0);
            tick(0, c);
            tick(0, 0);
            tick(0, 0);
            tick(0, 0);
        end
        // Reset before/after each byte, including while completion is asserted.
        for (position = 0; position <= 3; position = position + 1) begin
            tick(1, 0);
            for (j = 0; j < position; j = j + 1) tick(0, 8'h08);
            tick(1, 8'h08);
            tick(0, 0);
            tick(0, 0);
            tick(0, 8'h08);
            tick(0, 8'hff);
            tick(0, 0);
            tick(0, 0);
        end
        for (j = 0; j < 1000; j = j + 1) begin
            rng = {rng[30:0], rng[31] ^ rng[21] ^ rng[1] ^ rng[0]};
            tick(rng[15:12] == 4'h0, rng[7:0]);
        end
        $display("PASS %0d byte-cycle checks", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Bounded simulation timeout");
    end
endmodule
