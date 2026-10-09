`timescale 1ns/1ps
module dev_tb;
    wire one;
    TopModule dut (.one(one));

    task check_high;
        begin
            if (one !== 1'b1)
                $fatal(1, "Expected one=1 at time %0t, observed %b", $time, one);
        end
    endtask

    initial begin
        // Allow the continuous assignment to settle within time zero.
        #0;
        check_high();
        #1;
        check_high();
        repeat (100) begin
            #1;
            check_high();
        end
        $display("PASS constant output remains logic high");
        $finish;
    end

    initial begin
        #200;
        $fatal(1, "Development test timed out");
    end
endmodule
