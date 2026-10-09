`timescale 1ns/1ps
module dev_tb;
    wire zero;
    TopModule dut (.zero(zero));

    task automatic check_zero;
        if (zero !== 1'b0)
            $fatal(1, "Expected zero=0 at time %0t, got %b", $time, zero);
    endtask

    initial begin
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
        $display("PASS constant LOW at initialization and all sampled times");
        $finish;
    end

    initial begin
        #200;
        $fatal(1, "Timeout");
    end
endmodule
