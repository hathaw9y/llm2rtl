`timescale 1ns/1ps
module dev_tb;
    logic [2:0] vec;
    wire [2:0] outv;
    wire o2, o1, o0;
    TopModule dut (.vec(vec), .outv(outv), .o2(o2), .o1(o1), .o0(o0));
    initial begin
        for (integer i = 0; i < 8; i = i + 1) begin
            vec = 3'(i);
            #1;
            if (outv !== vec || {o2, o1, o0} !== vec)
                $fatal(1, "FAIL: vec=%b outv=%b split=%b", vec, outv, {o2,o1,o0});
        end
        $display("PASS: all eight input vectors");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: timeout");
    end
endmodule
