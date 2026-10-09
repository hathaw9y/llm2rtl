`timescale 1ns/1ps
module dev_tb;
    reg stimulus;
    wire observed;
    integer checks = 0;
    integer i;
    TopModule dut (.in(stimulus), .out(observed));

    task automatic check_wire(input reg expected);
        begin
            if (observed !== expected)
                $fatal(1, "Wire mismatch: input=%b expected=%b output=%b", stimulus, expected, observed);
            checks = checks + 1;
        end
    endtask

    task automatic drive_and_check(input reg value);
        begin
            stimulus = value;
            #1;
            check_wire(value);
        end
    endtask

    initial begin
        // An uninitialized input starts unknown; a wire propagates it.
        #1;
        check_wire(1'bx);
        drive_and_check(1'b0);
        drive_and_check(1'b1);
        drive_and_check(1'b1);
        drive_and_check(1'b0);
        for (i = 0; i < 16; i = i + 1) begin
            drive_and_check(1'b1);
            drive_and_check(1'b0);
        end
        drive_and_check(1'bx);
        drive_and_check(1'b1);
        drive_and_check(1'bz);
        drive_and_check(1'b0);
        $display("PASS: wire checks completed (%0d checks)", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
