`timescale 1ns/1ps
module dev_tb;
    logic a, b;
    wire out_and, out_or, out_xor, out_nand, out_nor, out_xnor, out_anotb;
    TopModule dut (.a(a), .b(b), .out_and(out_and), .out_or(out_or),
        .out_xor(out_xor), .out_nand(out_nand), .out_nor(out_nor),
        .out_xnor(out_xnor), .out_anotb(out_anotb));

    // Explicit rows from the original gate definitions, in output port order.
    task automatic check_pair(input logic av, input logic bv);
        logic [6:0] expected;
        begin
            case ({av, bv})
                2'b00: expected = 7'b0001110;
                2'b01: expected = 7'b0111000;
                2'b10: expected = 7'b0111001;
                2'b11: expected = 7'b1100010;
                default: $fatal(1, "Invalid binary test stimulus");
            endcase
            a = av;
            b = bv;
            #1;
            if ({out_and,out_or,out_xor,out_nand,out_nor,out_xnor,out_anotb} !== expected)
                $fatal(1, "Gate mismatch a=%b b=%b expected=%b actual=%b", a, b, expected,
                    {out_and,out_or,out_xor,out_nand,out_nor,out_xnor,out_anotb});
        end
    endtask

    initial begin
        check_pair(0,0);
        check_pair(0,1);
        check_pair(1,1);
        check_pair(1,0);
        check_pair(0,0);
        check_pair(1,1);
        check_pair(0,1);
        check_pair(1,0);
        check_pair(1,0);
        $display("PASS all seven gates: exhaustive binary truth table and transitions");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
