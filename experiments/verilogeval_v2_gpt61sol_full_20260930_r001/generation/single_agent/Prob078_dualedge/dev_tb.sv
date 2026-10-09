`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic d = 0;
    wire q;
    logic expected;
    integer checks = 0;
    TopModule dut (.clk(clk), .d(d), .q(q));

    task automatic check_output;
        if (q !== expected)
            $fatal(1, "FAIL clk=%b d=%b q=%b expected=%b", clk, d, q, expected);
        checks = checks + 1;
    endtask

    initial begin
        // Alternate edges with data changes strictly between edges.
        for (integer i = 0; i < 128; i = i + 1) begin
            d = ((i % 7) < 3);
            #2;
            clk = ~clk;
            expected = d;
            #1;
            check_output();
            d = ~d;
            #1;
            check_output();
            d = ~d;
            #1;
            check_output();
        end
        $display("PASS: %0d output checks across 128 alternating edges", checks);
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "FAIL timeout");
    end
endmodule
