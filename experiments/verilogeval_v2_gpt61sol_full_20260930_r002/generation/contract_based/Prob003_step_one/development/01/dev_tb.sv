`timescale 1ns/1ps
module dev_tb;
    wire one;
    integer checks = 0;
    bit monitoring = 0;

    TopModule dut (.one(one));

    task automatic check_high;
        begin
            if (one !== 1'b1)
                $fatal(1, "Expected constant logic high at %0t, observed %b", $time, one);
            checks = checks + 1;
        end
    endtask

    always @(one) begin
        if (monitoring && one !== 1'b1)
            $fatal(1, "Output departed from logic high at %0t: %b", $time, one);
    end

    initial begin
        #0;
        check_high();
        monitoring = 1;
        #0.001;
        check_high();
        #0.999;
        check_high();
        repeat (100) begin
            #1;
            check_high();
        end
        #100;
        check_high();
        $display("PASS constant-high output: %0d observations", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout before successful verification");
    end
endmodule
