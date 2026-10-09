`timescale 1ns/1ps
module dev_tb;
    logic in;
    wire out;
    integer checks = 0;

    TopModule dut (.in(in), .out(out));

    // The original specification requires the output to equal the input.
    task automatic drive_check(input logic value);
        begin
            in = value;
            #1;
            if (out !== value)
                $fatal(1, "Mismatch: in=%b expected=%b out=%b", in, value, out);
            checks = checks + 1;
        end
    endtask

    initial begin
        // No initialization/reset is required; initially undriven input is X.
        #1;
        if (out !== in)
            $fatal(1, "Initial mismatch: in=%b out=%b", in, out);
        checks = checks + 1;
        drive_check(1'b0);
        drive_check(1'b0);
        drive_check(1'b1);
        drive_check(1'b1);
        drive_check(1'b0);
        drive_check(1'b1);
        drive_check(1'bx);
        drive_check(1'b0);
        drive_check(1'bz);
        drive_check(1'b1);
        drive_check(1'b0);
        $display("PASS: combinational identity, %0d checks", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
