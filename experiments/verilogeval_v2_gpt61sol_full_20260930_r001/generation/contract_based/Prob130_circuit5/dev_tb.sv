`timescale 1ns/1ps
module dev_tb;
    logic [3:0] a, b, c, d, e;
    wire [3:0] q;
    logic [3:0] source [0:3];
    logic [3:0] expected;
    integer vector_index, selector, checks;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .e(e), .q(q));

    task automatic check_output;
        begin
            source[0] = b;
            source[1] = e;
            source[2] = a;
            source[3] = d;
            if (c < 4) expected = source[c];
            else expected = 4'hf;
            #1;
            if (q !== expected)
                $fatal(1, "FAIL a=%h b=%h c=%h d=%h e=%h q=%h expected=%h", a,b,c,d,e,q,expected);
            checks = checks + 1;
        end
    endtask

    initial begin
        checks = 0;
        a=4'ha; b=4'hb; d=4'hd; e=4'he;
        for (selector=0; selector<16; selector=selector+1) begin
            c=selector[3:0];
            check_output();
        end
        for (vector_index=0; vector_index<1048576; vector_index=vector_index+1) begin
            {a,b,c,d,e}=vector_index[19:0];
            check_output();
        end
        for (selector=0; selector<4; selector=selector+1) begin
            a=4'bx0z1; b=4'bz1x0; d=4'b1zx0; e=4'b0xz1;
            c=selector[3:0];
            check_output();
        end
        $display("PASS: %0d comparisons; exhaustive binary inputs, waveform replay, selected X/Z propagation", checks);
        $finish;
    end
    initial begin
        #1100000;
        $fatal(1, "FAIL: development simulation timeout");
    end
endmodule
