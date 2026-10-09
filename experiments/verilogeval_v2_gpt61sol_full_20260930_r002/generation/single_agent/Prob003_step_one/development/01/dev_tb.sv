`timescale 1ns/1ps
module dev_tb;
    wire one;
    TopModule dut (.one(one));

    task automatic check_high;
        if (one !== 1'b1)
            $fatal(1, "Expected one=1 at time %0t, got %b", $time, one);
    endtask

    initial begin
        #0;
        check_high();
        #0.001;
        check_high();
        repeat (100) begin
            #1;
            check_high();
        end
        $display("PASS constant output remains high");
        $finish;
    end

    initial begin
        #200;
        $fatal(1, "Timeout");
    end
endmodule
