module dev_tb;
    logic a, b;
    wire out_and, out_or, out_xor, out_nand, out_nor, out_xnor, out_anotb;
    logic [6:0] expected;
    TopModule dut (.*);
    initial begin
        for (integer i = 0; i < 4; i = i + 1) begin
            {a, b} = i[1:0];
            case (i)
                0: expected = 7'b0001110;
                1: expected = 7'b0111000;
                2: expected = 7'b0111001;
                3: expected = 7'b1100010;
            endcase
            #1;
            if ({out_and, out_or, out_xor, out_nand, out_nor, out_xnor, out_anotb} !== expected)
                $fatal(1, "FAIL a=%b b=%b", a, b);
        end
        $display("PASS: all four binary input combinations, all seven outputs");
        $finish;
    end
    initial begin
        #20;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
