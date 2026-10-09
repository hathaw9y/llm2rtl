`timescale 1ns/1ps
module dev_tb;
    reg a, b;
    wire out_and, out_or, out_xor, out_nand, out_nor, out_xnor, out_anotb;
    TopModule dut (
        .a(a), .b(b), .out_and(out_and), .out_or(out_or),
        .out_xor(out_xor), .out_nand(out_nand), .out_nor(out_nor),
        .out_xnor(out_xnor), .out_anotb(out_anotb)
    );
    task check(input reg av, input reg bv, input reg [6:0] expected);
        begin
            a = av;
            b = bv;
            #1;
            if ({out_and, out_or, out_xor, out_nand, out_nor,
                 out_xnor, out_anotb} !== expected)
                $fatal(1, "a=%b b=%b expected=%b actual=%b", a, b, expected,
                       {out_and, out_or, out_xor, out_nand, out_nor,
                        out_xnor, out_anotb});
        end
    endtask
    initial begin
        // Literal truth table, in AND/OR/XOR/NAND/NOR/XNOR/A-not-B order.
        check(0, 0, 7'b0001110);
        check(0, 1, 7'b0111000);
        check(1, 0, 7'b0111001);
        check(1, 1, 7'b1100010);
        // Reverse transitions exercise changing each input in both directions.
        check(1, 0, 7'b0111001);
        check(0, 1, 7'b0111000);
        check(0, 0, 7'b0001110);
        $display("PASS: all seven gate truth tables and transitions");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
