`timescale 1ns/1ps
module dev_tb;
    wire zero;
    TopModule dut (.zero(zero));

    task automatic check_low;
        if (zero !== 1'b0)
            $fatal(1, "Expected constant LOW at time %0t, got %b", $time, zero);
    endtask

    initial begin
        #0;
        check_low();
        #0.001;
        check_low();
        repeat (100) begin
            #1;
            check_low();
        end
        $display("PASS constant LOW at initialization and throughout observation");
        $finish;
    end

    initial begin
        #200;
        $fatal(1, "Timeout");
    end
endmodule
