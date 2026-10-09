`timescale 1ns/1ps
module dev_tb;
    reg [2:0] vec;
    wire [2:0] outv;
    wire o2, o1, o0;
    integer i;
    TopModule dut (.vec(vec), .outv(outv), .o2(o2), .o1(o1), .o0(o0));

    task check(input [2:0] stimulus);
        begin
            vec = stimulus;
            #1;
            if (outv !== stimulus || o0 !== stimulus[0] ||
                o1 !== stimulus[1] || o2 !== stimulus[2])
                $fatal(1, "Vector mapping mismatch: vec=%b outv=%b o2=%b o1=%b o0=%b",
                       stimulus, outv, o2, o1, o0);
        end
    endtask

    initial begin
        for (i = 0; i < 8; i = i + 1)
            check(i[2:0]);
        for (i = 7; i >= 0; i = i - 1)
            check(i[2:0]);
        check(3'bxxx);
        check(3'bzzz);
        check(3'bx10);
        check(3'b0z1);
        check(3'b10x);
        check(3'b000);
        $display("PASS: vector forwarding and individual bit connections");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Testbench timeout");
    end
endmodule
