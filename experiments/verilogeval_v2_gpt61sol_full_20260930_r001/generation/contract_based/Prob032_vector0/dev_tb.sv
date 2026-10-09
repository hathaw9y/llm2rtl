`timescale 1ns/1ps
module dev_tb;
    logic [2:0] vec;
    wire [2:0] outv;
    wire o2, o1, o0;
    integer n;
    integer checks = 0;
    TopModule dut (.vec(vec), .outv(outv), .o2(o2), .o1(o1), .o0(o0));
    task automatic check_vector(input integer value);
        begin
            vec = value[2:0];
            #1;
            if (outv !== value[2:0] ||
                o0 !== ((value % 2) == 1) ||
                o1 !== (((value / 2) % 2) == 1) ||
                o2 !== (((value / 4) % 2) == 1))
                $fatal(1, "FAIL: value=%0d outv=%b scalars=%b%b%b", value, outv, o2, o1, o0);
            checks = checks + 1;
        end
    endtask
    initial begin
        for (n = 0; n < 8; n = n + 1) check_vector(n);
        for (n = 7; n >= 0; n = n - 1) check_vector(n);
        $display("PASS: %0d checked vectors, all eight binary inputs in both orders", checks);
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: watchdog timeout");
    end
endmodule
