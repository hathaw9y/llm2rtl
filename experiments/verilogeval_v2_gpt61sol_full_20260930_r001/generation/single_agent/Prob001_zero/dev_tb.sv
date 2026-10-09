`timescale 1ns/1ps
module dev_tb;
    wire zero;
    TopModule dut (.zero(zero));
    initial begin
        #0;
        if (zero !== 1'b0) $fatal(1, "FAIL: zero is not LOW");
        repeat (10) begin
            #1;
            if (zero !== 1'b0) $fatal(1, "FAIL: zero is not LOW");
        end
        $display("PASS: zero remains LOW");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: timeout");
    end
endmodule
