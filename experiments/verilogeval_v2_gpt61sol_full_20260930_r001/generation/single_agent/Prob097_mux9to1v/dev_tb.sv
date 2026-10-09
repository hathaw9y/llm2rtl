`timescale 1ns/1ps
module dev_tb;
    logic [15:0] a,b,c,d,e,f,g,h,i;
    logic [3:0] sel;
    wire [15:0] out;
    logic [15:0] expected;
    integer trial, selection, checks;
    TopModule dut (.a(a),.b(b),.c(c),.d(d),.e(e),.f(f),.g(g),.h(h),.i(i),.sel(sel),.out(out));
    initial begin
        checks = 0;
        for (trial=0; trial<102; trial=trial+1) begin
            if (trial==0) begin
                {a,b,c,d,e,f,g,h,i} = '0;
            end else if (trial==1) begin
                {a,b,c,d,e,f,g,h,i} = '1;
            end else begin
                a=$urandom; b=$urandom; c=$urandom;
                d=$urandom; e=$urandom; f=$urandom;
                g=$urandom; h=$urandom; i=$urandom;
            end
            for (selection=0; selection<16; selection=selection+1) begin
                sel = selection;
                case (selection)
                    0: expected=a; 1: expected=b; 2: expected=c;
                    3: expected=d; 4: expected=e; 5: expected=f;
                    6: expected=g; 7: expected=h; 8: expected=i;
                    default: expected=16'hffff;
                endcase
                #1;
                if (out !== expected)
                    $fatal(1,"FAIL trial=%0d sel=%0d expected=%h actual=%h",trial,selection,expected,out);
                checks=checks+1;
            end
        end
        $display("PASS: %0d mux comparisons",checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1,"FAIL: testbench timeout");
    end
endmodule
