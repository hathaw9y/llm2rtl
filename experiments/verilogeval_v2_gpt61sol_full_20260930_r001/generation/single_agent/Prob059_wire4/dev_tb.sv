`timescale 1ns/1ps
module dev_tb;
    logic a, b, c;
    wire w, x, y, z;
    logic [1:0] values [0:3];
    TopModule dut (.a(a), .b(b), .c(c), .w(w), .x(x), .y(y), .z(z));
    initial begin
        values[0] = 2'b00;
        values[1] = 2'b01;
        values[2] = 2'bxx;
        values[3] = 2'bzz;
        for (int i = 0; i < 4; i++) begin
            for (int j = 0; j < 4; j++) begin
                for (int k = 0; k < 4; k++) begin
                    a = values[i][0];
                    b = values[j][0];
                    c = values[k][0];
                    #1;
                    if ({w,x,y,z} !== {a,b,b,c})
                        $fatal(1, "FAIL: wire mapping mismatch");
                end
            end
        end
        $display("PASS: all 64 four-state input combinations");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: timeout");
    end
endmodule
