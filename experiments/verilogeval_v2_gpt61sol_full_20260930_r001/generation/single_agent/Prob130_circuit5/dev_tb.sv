`timescale 1ns/1ps
module dev_tb;
    logic [3:0] a, b, c, d, e;
    wire [3:0] q;
    logic [3:0] expected;
    logic [15:0] choices;
    integer vector_idx;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .e(e), .q(q));
    initial begin
        for (vector_idx = 0; vector_idx < 1048576; vector_idx = vector_idx + 1) begin
            {a,b,c,d,e} = vector_idx[19:0];
            choices = {d,a,e,b};
            expected = (c < 4) ? choices[c*4 +: 4] : 4'hf;
            #1;
            if (q !== expected)
                $fatal(1, "FAIL a=%h b=%h c=%h d=%h e=%h q=%h expected=%h", a,b,c,d,e,q,expected);
        end
        $display("PASS: all 1048576 binary input combinations");
        $finish;
    end
    initial begin
        #1100000;
        $fatal(1, "FAIL: simulation timeout");
    end
endmodule
