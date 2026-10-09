`timescale 1ns/1ps
module dev_tb;
    logic a, b, c;
    logic out;
    logic expected;
    integer i;
    TopModule dut (.a(a), .b(b), .c(c), .out(out));
    initial begin
        for (i = 0; i < 8; i = i + 1) begin
            {a, b, c} = i[2:0];
            case (i)
                0: expected = 1'b0;
                default: expected = 1'b1;
            endcase
            #1;
            if (out !== expected)
                $fatal(1, "FAIL inputs=%b%b%b expected=%b actual=%b", a, b, c, expected, out);
        end
        $display("PASS: all 8 Karnaugh-map entries checked");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
