`timescale 1ns/1ps
module dev_tb;
    wire out;
    TopModule dut (.out(out));
    initial begin
        #0;
        if (out !== 1'b0) $fatal(1, "FAIL: out is not zero at time-zero settling");
        repeat (100) begin
            #1;
            if (out !== 1'b0) $fatal(1, "FAIL: out is not zero at time %0t", $time);
        end
        $display("PASS: constant-low output at 101 observations");
        $finish;
    end
    initial begin
        #200;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
