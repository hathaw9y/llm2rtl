`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic resetn = 1;
    logic [1:0] byteena = 0;
    logic [15:0] d = 0;
    wire [15:0] q;
    logic [15:0] expected;
    logic [31:0] prng = 32'h729be041;
    integer checks = 0;
    integer i, en;
    TopModule dut (.clk(clk), .resetn(resetn), .byteena(byteena), .d(d), .q(q));

    task automatic check_output;
        begin
            checks = checks + 1;
            if (q !== expected)
                $fatal(1, "Mismatch check=%0d q=%h expected=%h resetn=%b byteena=%b d=%h", checks, q, expected, resetn, byteena, d);
        end
    endtask

    task automatic cycle(input logic rn, input logic [1:0] be, input logic [15:0] data);
        integer bit_index;
        begin
            resetn = rn;
            byteena = be;
            d = data;
            #2;
            check_output();
            for (bit_index = 0; bit_index < 16; bit_index = bit_index + 1) begin
                if (!rn) expected[bit_index] = 1'b0;
                else if (be[bit_index / 8]) expected[bit_index] = data[bit_index];
            end
            clk = 1;
            #1;
            check_output();
            clk = 0;
            #1;
            check_output();
        end
    endtask

    initial begin
        // Establish state without assuming a power-up value.
        resetn = 0;
        byteena = 2'b11;
        d = 16'hffff;
        #2;
        clk = 1;
        expected = 16'h0000;
        #1;
        check_output();
        clk = 0;
        #1;
        for (en = 0; en < 4; en = en + 1) begin
            cycle(1, 2'b11, 16'ha55a);
            cycle(1, en[1:0], 16'h3cc3);
            cycle(1, en[1:0], 16'hffff);
            cycle(1, en[1:0], 16'h0000);
            cycle(0, en[1:0], 16'hffff);
            cycle(0, en[1:0], 16'h1234);
            cycle(1, 2'b00, 16'hffff);
        end
        for (i = 0; i < 16; i = i + 1) begin
            cycle(0, 2'b00, 16'hffff);
            cycle(1, 2'b01, 16'h0001 << i);
            cycle(1, 2'b10, 16'h0001 << i);
            cycle(1, 2'b00, ~(16'h0001 << i));
        end
        // Explicit between-edge reset pulse must leave existing data intact.
        cycle(1, 2'b11, 16'hb69d);
        resetn = 0;
        #1;
        check_output();
        resetn = 1;
        #1;
        check_output();
        cycle(1, 2'b00, 16'hffff);
        for (i = 0; i < 1000; i = i + 1) begin
            prng = prng ^ (prng << 13);
            prng = prng ^ (prng >> 17);
            prng = prng ^ (prng << 5);
            cycle(prng[7:4] != 4'h0, prng[1:0], prng[31:16]);
        end
        $display("PASS: independent per-bit scoreboard, %0d checks", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Development simulation timeout");
    end
endmodule
