`timescale 1ns/1ps
module dev_tb;
    wire out;
    TopModule dut (.out(out));

    task automatic check_low;
        if (out !== 1'b0)
            $fatal(1, "Expected constant zero at time %0t, got %b", $time, out);
    endtask

    initial begin
        // Sample after initial continuous-assignment settling at time zero.
        #0;
        check_low();
        #0.001;
        check_low();
        #0.999;
        check_low();
        repeat (100) begin
            #1;
            check_low();
        end
        $display("PASS constant-low output at startup and throughout observation");
        $finish;
    end

    initial begin
        #200;
        $fatal(1, "Timeout");
    end
endmodule
