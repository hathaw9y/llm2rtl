`timescale 1ns/1ps
module dev_tb;
    wire out;
    TopModule dut (.out(out));
    initial begin
        #0;
        if (out !== 1'b0) $fatal(1, "FAIL: output at initialization");
        repeat (100) begin
            #1;
            if (out !== 1'b0) $fatal(1, "FAIL: output must remain low");
        end
        $display("PASS: output remains zero");
        $finish;
    end
    initial begin
        #200;
        $fatal(1, "FAIL: timeout");
    end
endmodule
