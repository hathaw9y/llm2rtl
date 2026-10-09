`timescale 1ns/1ps
module dev_tb;
    reg a, b;
    wire out_and, out_or, out_xor, out_nand, out_nor, out_xnor, out_anotb;
    wire [6:0] actual = {out_and, out_or, out_xor, out_nand,
                         out_nor, out_xnor, out_anotb};
    integer checks = 0;
    TopModule dut(.a(a), .b(b), .out_and(out_and), .out_or(out_or),
        .out_xor(out_xor), .out_nand(out_nand), .out_nor(out_nor),
        .out_xnor(out_xnor), .out_anotb(out_anotb));

    // Literal truth-table oracle from the original gate descriptions.
    task check(input reg va, input reg vb, input reg [6:0] expected);
        begin
            a = va; b = vb;
            #1;
            if (actual !== expected)
                $fatal(1, "a=%b b=%b expected=%b actual=%b", a,b,expected,actual);
            checks = checks + 1;
        end
    endtask

    initial begin
        check(0,0,7'b0001110);
        check(0,1,7'b0111000);
        check(1,0,7'b0111001);
        check(1,1,7'b1100010);
        check(1,0,7'b0111001);
        check(0,0,7'b0001110);
        check(1,1,7'b1100010);
        check(0,1,7'b0111000);
        // Supplemental normal four-state gate propagation checks.
        check(1'bx,0,7'b0xx1xxx);
        check(0,1'bx,7'b0xx1xx0);
        check(1'bx,1,7'bx1xx0x0);
        check(1,1'bx,7'bx1xx0xx);
        check(1'bz,0,7'b0xx1xxx);
        check(0,1'bz,7'b0xx1xx0);
        check(0,0,7'b0001110);
        $display("PASS: %0d gate checks",checks);
        $finish;
    end
    initial begin
        #100;
        $fatal(1,"Timeout");
    end
endmodule
