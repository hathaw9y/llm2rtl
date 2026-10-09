`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg ar = 0;
    reg d = 0;
    wire q;
    integer checks = 0;
    integer i;
    TopModule dut(.clk(clk), .ar(ar), .d(d), .q(q));

    task check(input reg expected, input [255:0] description);
        begin
            checks = checks + 1;
            if (q !== expected)
                $fatal(1, "%0s: expected %b, got %b at %0t", description, expected, q, $time);
        end
    endtask

    initial begin
        // No reset or active clock edge has initialized the storage.
        #1; check(1'bx, "initial storage");
        d = 1;
        #1; check(1'bx, "data alone does not initialize");
        ar = 1;
        #1; check(0, "asynchronous reset with clock low");
        ar = 0;
        #1; check(0, "reset release holds state");
        clk = 1;
        #1; check(1, "rising edge captures one");
        d = 0;
        #1; check(1, "data change with clock high");
        clk = 0;
        #1; check(1, "falling edge holds state");
        clk = 1;
        #1; check(0, "rising edge captures zero");
        clk = 0; d = 1;
        #1; clk = 1;
        #1; check(1, "capture before asynchronous reset");
        ar = 1;
        #1; check(0, "asynchronous reset with clock high");
        ar = 0;
        #1; check(0, "release while clock high");
        clk = 0;
        #1; ar = 1; clk = 1;
        #1; check(0, "reset priority at rising edge");
        clk = 0;
        #1; clk = 1;
        #1; check(0, "held reset across rising edge");
        clk = 0; ar = 0;
        for (i = 0; i < 16; i = i + 1) begin
            d = (i % 3 == 0);
            #2; clk = 1;
            #1; check((i % 3 == 0), "directed rising edge capture");
            d = ~d;
            #1; check((i % 3 == 0), "data transition holds state");
            clk = 0;
            #1; check((i % 3 == 0), "directed falling edge retention");
        end
        $display("PASS: %0d D flip-flop checks", checks);
        $finish;
    end
    initial begin
        #200;
        $fatal(1, "Timeout");
    end
endmodule
