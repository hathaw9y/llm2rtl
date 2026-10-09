`timescale 1ns/1ps
module dev_tb;
    wire zero;
    TopModule dut (.zero(zero));
    initial begin
        #0;
        if (zero !== 1'b0) $fatal(1, "FAIL: zero is not LOW at time zero");
        repeat (100) begin
            #1;
            if (zero !== 1'b0) $fatal(1, "FAIL: zero is not LOW at %0t", $time);
        end
        $display("PASS: zero remains LOW across 101 checks");
        $finish;
    end
    initial begin
        #200;
        $fatal(1, "FAIL: development simulation timeout");
    end
endmodule
