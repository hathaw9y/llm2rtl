`timescale 1ns/1ps
module dev_tb;
    wire zero;
    TopModule dut (.zero(zero));

    task automatic check_low;
        if (zero !== 1'b0)
            $fatal(1, "zero must always be LOW, got %b at %0t", zero, $time);
    endtask

    initial begin
        // Observe time zero after continuous assignments have settled.
        #0;
        check_low();
        #0.001;
        check_low();
        repeat (100) begin
            #1;
            check_low();
        end
        $display("PASS: zero remains LOW at initialization and all sampled times");
        $finish;
    end

    initial begin
        #200;
        $fatal(1, "Timeout before verification completed");
    end
endmodule
