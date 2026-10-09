`timescale 1ns/1ps
module dev_tb;
    reg stimulus;
    wire observed;
    integer checks = 0;
    TopModule dut (.in(stimulus), .out(observed));

    task automatic check_value(input reg value);
        begin
            stimulus = value;
            #1;
            if (observed !== value)
                $fatal(1, "Identity mismatch: input=%b output=%b", value, observed);
            checks = checks + 1;
        end
    endtask

    initial begin
        // Undriven register starts X; check propagation after settling.
        #1;
        if (observed !== 1'bx)
            $fatal(1, "Initial unknown input did not propagate");
        checks = checks + 1;
        check_value(1'b0);
        check_value(1'b1);
        check_value(1'b1);
        check_value(1'b0);
        check_value(1'bx);
        check_value(1'b1);
        check_value(1'bz);
        check_value(1'b0);
        check_value(1'bz);
        check_value(1'bx);
        check_value(1'b0);
        check_value(1'b1);
        $display("PASS combinational identity: %0d checks", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
