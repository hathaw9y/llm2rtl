`timescale 1ns/1ps
module dev_tb;
    wire out;
    TopModule dut (.out(out));

    task automatic check_zero;
        if (out !== 1'b0)
            $fatal(1, "out must always be zero: t=%0t out=%b", $time, out);
    endtask

    initial begin
        // Check initial settled time without introducing startup latency.
        #0;
        check_zero();
        #0.001;
        check_zero();
        #0.999;
        check_zero();
        repeat (100) begin
            #1;
            check_zero();
        end
        $display("PASS constant-zero output at initial and later times");
        $finish;
    end

    // Also reject any later transition away from the required constant.
    always @(out) begin
        if ($time > 0 && out !== 1'b0)
            $fatal(1, "Unexpected output transition: out=%b", out);
    end

    initial begin
        #200;
        $fatal(1, "Timeout");
    end
endmodule
