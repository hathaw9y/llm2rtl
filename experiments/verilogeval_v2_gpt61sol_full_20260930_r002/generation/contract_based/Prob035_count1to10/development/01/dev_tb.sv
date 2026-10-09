`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    wire [3:0] q;
    integer expected;
    integer checks = 0;
    TopModule dut (.clk(clk), .reset(reset), .q(q));

    task automatic check(input integer value);
        if (q !== value[3:0])
            $fatal(1, "q mismatch at %0t: got %b expected %0d", $time, q, value);
        checks = checks + 1;
    endtask

    task automatic tick(input bit rst);
        reset = rst;
        #2;
        check(expected); // synchronous reset must not act before edge
        clk = 1;
        if (rst) expected = 1;
        else expected = (expected % 10) + 1;
        #1;
        check(expected);
        #2;
        clk = 0;
        #1;
        check(expected); // falling edge cannot advance count
    endtask

    initial begin
        // No assertion about unspecified power-up contents.
        reset = 1;
        #2;
        clk = 1;
        expected = 1;
        #1;
        check(expected);
        #2;
        clk = 0;
        #1;
        tick(1);
        tick(1);
        for (integer i = 0; i < 40; i = i + 1) tick(0);
        // Reset from each reachable value, including the wrap boundary.
        for (integer value = 1; value <= 10; value = value + 1) begin
            tick(1);
            for (integer j = 1; j < value; j = j + 1) tick(0);
            reset = 0;
            #1;
            check(expected);
            reset = 1;
            #1;
            check(expected);
            reset = 0; // pulse has no positive clock edge
            #1;
            check(expected);
            tick(0);
            tick(1);
            tick(0);
        end
        $display("PASS counter checks=%0d", checks);
        $finish;
    end
    initial begin
        #5000;
        $fatal(1, "timeout");
    end
endmodule
