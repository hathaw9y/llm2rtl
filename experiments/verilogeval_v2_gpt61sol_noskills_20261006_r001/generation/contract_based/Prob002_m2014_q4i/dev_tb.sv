`timescale 1ns/1ps
module dev_tb;
    wire out;
    TopModule dut(.out(out));

    // Original requirement: out always drives logic low, with no inputs.
    initial begin
        #0;
        if (out !== 1'b0) $fatal(1, "out must be zero at initialization, got %b", out);
        repeat (100) begin
            #1;
            if (out !== 1'b0) $fatal(1, "out must remain zero at time %0t, got %b", $time, out);
        end
        $display("PASS: out is zero at initialization and all subsequent observations");
        $finish;
    end

    initial begin
        #101;
        $fatal(1, "Development test timeout");
    end
endmodule
