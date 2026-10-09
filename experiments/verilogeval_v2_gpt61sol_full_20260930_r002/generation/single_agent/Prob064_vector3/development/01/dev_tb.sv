`timescale 1ns/1ps
module dev_tb;
    logic [4:0] a, b, c, d, e, f;
    wire [7:0] w, x, y, z;
    integer checks = 0;
    integer i;
    logic [29:0] stimulus;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .e(e), .f(f),
                   .w(w), .x(x), .y(y), .z(z));

    task automatic check_outputs;
        logic [7:0] ew, ex, ey, ez;
        begin
            #1;
            // Explicit byte boundaries derived from the original input ordering.
            ew[7:3] = a;
            ew[2:0] = b[4:2];
            ex[7:6] = b[1:0];
            ex[5:1] = c;
            ex[0] = d[4];
            ey[7:4] = d[3:0];
            ey[3:0] = e[4:1];
            ez[7] = e[0];
            ez[6:2] = f;
            ez[1:0] = 2'b11;
            if (w !== ew || x !== ex || y !== ey || z !== ez)
                $fatal(1, "Mismatch a=%b b=%b c=%b d=%b e=%b f=%b got=%h/%h/%h/%h expected=%h/%h/%h/%h",
                       a,b,c,d,e,f,w,x,y,z,ew,ex,ey,ez);
            checks = checks + 1;
        end
    endtask

    initial begin
        a=0; b=0; c=0; d=0; e=0; f=0;
        check_outputs();
        a=31; b=31; c=31; d=31; e=31; f=31;
        check_outputs();
        a=1; b=2; c=4; d=8; e=16; f=21;
        check_outputs();
        for (i=0; i<30; i=i+1) begin
            stimulus = 30'b1 << i;
            {a,b,c,d,e,f} = stimulus;
            check_outputs();
            {a,b,c,d,e,f} = ~stimulus;
            check_outputs();
        end
        for (i=0; i<1000; i=i+1) begin
            {a,b,c,d,e,f} = $urandom;
            check_outputs();
        end
        // Check four-state propagation through this pure wiring function.
        a='x; b='z; c=5'b10x01; d=5'bz1010; e='x; f='z;
        check_outputs();
        $display("PASS %0d concatenation checks", checks);
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
