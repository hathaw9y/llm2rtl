`timescale 1ns/1ps
module dev_tb;
    reg [4:0] a, b, c, d, e, f;
    wire [7:0] w, x, y, z;
    reg [29:0] stimulus;
    reg [31:0] expected;
    integer i, j;
    integer checks = 0;
    TopModule dut(.a(a), .b(b), .c(c), .d(d), .e(e), .f(f),
                  .w(w), .x(x), .y(y), .z(z));

    task check;
        begin
            // Map each source bit independently into its specified output position.
            expected = 32'b0;
            expected[0] = 1'b1;
            expected[1] = 1'b1;
            for (j = 0; j < 5; j = j + 1) begin
                expected[27+j] = a[j];
                expected[22+j] = b[j];
                expected[17+j] = c[j];
                expected[12+j] = d[j];
                expected[7+j] = e[j];
                expected[2+j] = f[j];
            end
            #1;
            if (w !== expected[31:24] || x !== expected[23:16] ||
                y !== expected[15:8] || z !== expected[7:0])
                $fatal(1, "Mismatch: got %h expected %h", {w,x,y,z}, expected);
            checks = checks + 1;
        end
    endtask

    task drive(input reg [29:0] value);
        begin
            a = value[29:25]; b = value[24:20]; c = value[19:15];
            d = value[14:10]; e = value[9:5]; f = value[4:0];
            check;
        end
    endtask

    initial begin
        drive(30'b0);
        drive({30{1'b1}});
        for (i = 0; i < 30; i = i + 1) begin
            stimulus = 30'b1 << i;
            drive(stimulus);
            drive(~stimulus);
        end
        drive(30'b101010101010101010101010101010);
        drive(30'b010101010101010101010101010101);
        for (i = 0; i < 1000; i = i + 1) drive($random);
        // Check four-state propagation without affecting the constant low bits.
        drive({30{1'bx}});
        drive({30{1'bz}});
        $display("PASS: %0d concatenation checks", checks);
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
