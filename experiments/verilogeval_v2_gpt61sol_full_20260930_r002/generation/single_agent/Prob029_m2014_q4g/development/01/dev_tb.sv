`timescale 1ns/1ps
module dev_tb;
    logic in1, in2, in3;
    wire out;
    // Truth table indexed by {in1,in2,in3}: 1,0,0,1,0,1,1,0.
    localparam logic [7:0] EXPECTED = 8'b01101001;
    TopModule dut (.in1(in1), .in2(in2), .in3(in3), .out(out));

    task automatic check(input logic a, b, c, expected);
        in1 = a;
        in2 = b;
        in3 = c;
        #1;
        if (out !== expected)
            $fatal(1, "Inputs %b%b%b: expected %b, got %b", a,b,c,expected,out);
    endtask

    initial begin
        for (integer i = 0; i < 8; i = i + 1)
            check(i[2], i[1], i[0], EXPECTED[i]);
        for (integer i = 7; i >= 0; i = i - 1)
            check(i[2], i[1], i[0], EXPECTED[i]);
        check(1'bx, 1'b0, 1'b0, 1'bx);
        check(1'b1, 1'bx, 1'b1, 1'bx);
        check(1'b0, 1'b1, 1'bx, 1'bx);
        check(1'bz, 1'b1, 1'b0, 1'bx);
        check(1'b0, 1'bz, 1'b1, 1'bx);
        check(1'b1, 1'b1, 1'bz, 1'bx);
        $display("PASS: binary truth table and unknown propagation");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
