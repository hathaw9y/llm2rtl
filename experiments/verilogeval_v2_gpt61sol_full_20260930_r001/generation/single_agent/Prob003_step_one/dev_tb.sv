`timescale 1ns/1ps
module dev_tb;
    wire one;
    TopModule dut (.one(one));
    initial begin
        #0;
        if (one !== 1'b1) $fatal(1, "FAIL: output is not high at time zero");
        repeat (10) begin
            #1;
            if (one !== 1'b1) $fatal(1, "FAIL: output is not high");
        end
        $display("PASS: output remains constant high");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
