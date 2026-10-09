`timescale 1ns/1ps
module dev_tb;
    wire zero;
    TopModule dut (.zero(zero));

    task check_zero;
        begin
            if (zero !== 1'b0)
                $fatal(1, "Expected LOW at time %0t, got %b", $time, zero);
        end
    endtask

    initial begin
        // Sample after time-zero continuous assignments have settled.
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
        $display("PASS: output remains LOW from initial settling through 101 ns");
        $finish;
    end

    always @(zero) begin
        if (zero !== 1'b0)
            $fatal(1, "Output changed to a non-LOW value: %b", zero);
    end

    initial begin
        #200;
        $fatal(1, "Timeout");
    end
endmodule
