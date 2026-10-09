`timescale 1ns/1ps
module dev_tb;
    wire out;
    TopModule dut (.out(out));

    initial begin
        // Check after time-zero continuous assignments have settled.
        #0;
        if (out !== 1'b0) $fatal(1, "out must be zero at time zero");
        #1;
        if (out !== 1'b0) $fatal(1, "out must be zero at 1 ns");
        repeat (100) begin
            #1;
            if (out !== 1'b0) $fatal(1, "out must remain zero");
        end
        $display("PASS: output remains logic low");
        $finish;
    end

    initial begin
        #200;
        $fatal(1, "Testbench timeout");
    end
endmodule
