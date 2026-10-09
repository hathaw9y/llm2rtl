`timescale 1ns/1ps
module dev_tb;
    logic a, b;
    wire out_and, out_or, out_xor, out_nand, out_nor, out_xnor, out_anotb;
    TopModule dut (.*);

    task automatic check(input logic av, input logic bv, input logic [6:0] expected);
        begin
            a = av;
            b = bv;
            #1;
            if ({out_and, out_or, out_xor, out_nand, out_nor, out_xnor, out_anotb} !== expected)
                $fatal(1, "a=%b b=%b expected=%b actual=%b", a, b, expected,
                    {out_and, out_or, out_xor, out_nand, out_nor, out_xnor, out_anotb});
        end
    endtask

    initial begin
        check(1'b0, 1'b0, 7'b0001110);
        check(1'b0, 1'b1, 7'b0111000);
        check(1'b1, 1'b1, 7'b1100010);
        check(1'b1, 1'b0, 7'b0111001);
        check(1'b0, 1'b0, 7'b0001110);
        check(1'b1, 1'b1, 7'b1100010);
        check(1'b0, 1'b1, 7'b0111000);
        check(1'b1, 1'b0, 7'b0111001);
        $display("PASS all gate truth-table cases and repeated transitions");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
