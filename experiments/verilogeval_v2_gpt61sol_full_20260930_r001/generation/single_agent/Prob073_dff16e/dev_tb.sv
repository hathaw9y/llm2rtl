`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic resetn = 1;
    logic [1:0] byteena = 0;
    logic [15:0] d = 0;
    wire [15:0] q;
    logic [15:0] expected;
    integer checks = 0;
    TopModule dut (.clk(clk), .resetn(resetn), .byteena(byteena), .d(d), .q(q));
    always #5 clk = ~clk;
    task automatic cycle(input logic rn, input logic [1:0] en, input logic [15:0] data);
        @(negedge clk);
        resetn = rn;
        byteena = en;
        d = data;
        #1;
        if (checks != 0 && q !== expected)
            $fatal(1, "Output changed between rising edges");
        @(posedge clk);
        if (!rn) expected = 16'h0000;
        else expected = (expected & ~{{8{en[1]}}, {8{en[0]}}}) |
                        (data & {{8{en[1]}}, {8{en[0]}}});
        #1;
        if (q !== expected) $fatal(1, "Mismatch: q=%h expected=%h", q, expected);
        checks = checks + 1;
    endtask
    initial begin
        cycle(0, 2'b11, 16'hffff);
        cycle(1, 2'b11, 16'habcd);
        cycle(1, 2'b00, 16'h0000);
        cycle(1, 2'b01, 16'h1234);
        cycle(1, 2'b10, 16'h5678);
        cycle(0, 2'b00, 16'hffff);
        cycle(1, 2'b11, 16'hffff);
        cycle(0, 2'b11, 16'hffff);
        for (integer i = 0; i < 256; i = i + 1)
            cycle((i % 17) != 0, i % 4, 16'(i * 257));
        $display("PASS: %0d cycles checked", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Development simulation timeout");
    end
endmodule
