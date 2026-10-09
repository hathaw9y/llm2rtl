`timescale 1ns/1ps
module dev_tb;
    wire one;
    TopModule dut (.one(one));
    initial begin
        #0;
        if (one !== 1'b1) $fatal(1, "FAIL: one is not high at time-zero settling");
        repeat (100) begin
            #1;
            if (one !== 1'b1) $fatal(1, "FAIL: one is not high at time %0t", $time);
        end
        $display("PASS: one remained logic high at all 101 observations");
        $finish;
    end
    initial begin
        #200;
        $fatal(1, "FAIL: development simulation timeout");
    end
endmodule
