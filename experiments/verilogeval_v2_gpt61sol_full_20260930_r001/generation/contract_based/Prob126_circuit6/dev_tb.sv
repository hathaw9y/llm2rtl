`timescale 1ns/1ps
module dev_tb;
    logic [2:0] a;
    wire [15:0] q;
    logic [15:0] expected [0:7];
    integer checks = 0;
    TopModule dut (.a(a), .q(q));

    task automatic check_selector(input logic [2:0] selector);
        a = selector;
        #1;
        if (q !== expected[selector])
            $fatal(1, "a=%0d expected=%h got=%h", selector, expected[selector], q);
        checks = checks + 1;
    endtask

    initial begin
        expected[0] = 16'h1232;
        expected[1] = 16'haee0;
        expected[2] = 16'h27d4;
        expected[3] = 16'h5a0e;
        expected[4] = 16'h2066;
        expected[5] = 16'h64ce;
        expected[6] = 16'hc526;
        expected[7] = 16'h2f19;
        a = 3'bxxx;
        #1;
        if (q !== 16'hxxxx) $fatal(1, "Expected initial unknown output");
        checks = checks + 1;
        for (integer i = 0; i < 8; i = i + 1) check_selector(i[2:0]);
        for (integer i = 0; i < 8; i = i + 1)
            for (integer j = 0; j < 8; j = j + 1) begin
                check_selector(i[2:0]);
                check_selector(j[2:0]);
            end
        for (integer i = 0; i < 8; i = i + 1) begin
            a = 3'bxxx;
            #1;
            if (q !== 16'hxxxx) $fatal(1, "Unknown input retained previous result");
            checks = checks + 1;
            check_selector(i[2:0]);
        end
        $display("PASS: %0d checks, all selectors and ordered transitions", checks);
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "Testbench timeout");
    end
endmodule
