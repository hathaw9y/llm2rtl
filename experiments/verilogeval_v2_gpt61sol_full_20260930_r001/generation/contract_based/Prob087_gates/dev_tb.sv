`timescale 1ns/1ps
module dev_tb;
    logic a, b;
    wire out_and, out_or, out_xor, out_nand, out_nor, out_xnor, out_anotb;
    TopModule dut (.*);
    task automatic check(input logic [1:0] inputs, input logic [6:0] expected);
        {a,b} = inputs;
        #1;
        if ({out_and,out_or,out_xor,out_nand,out_nor,out_xnor,out_anotb} !== expected)
            $fatal(1, "FAIL input=%b expected=%b actual=%b", inputs, expected,
                   {out_and,out_or,out_xor,out_nand,out_nor,out_xnor,out_anotb});
    endtask
    initial begin
        check(2'b00,7'b0001110);
        check(2'b01,7'b0111000);
        check(2'b10,7'b0111001);
        check(2'b11,7'b1100010);
        check(2'b11,7'b1100010);
        check(2'b10,7'b0111001);
        check(2'b01,7'b0111000);
        check(2'b00,7'b0001110);
        $display("PASS: all four binary input pairs, eight checks");
        $finish;
    end
    initial begin
        #100;
        $fatal(1,"FAIL: testbench timeout");
    end
endmodule
