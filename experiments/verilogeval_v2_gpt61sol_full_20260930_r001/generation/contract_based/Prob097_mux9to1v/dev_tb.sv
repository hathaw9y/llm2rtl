`timescale 1ns/1ps
module dev_tb;
    logic [15:0] data [0:8];
    logic [3:0] sel;
    wire [15:0] out;
    logic [15:0] expected;
    logic [31:0] rng = 32'hcafe1234;
    integer checks = 0;
    integer n, s, bit_idx, p;
    TopModule dut (.a(data[0]), .b(data[1]), .c(data[2]),
        .d(data[3]), .e(data[4]), .f(data[5]), .g(data[6]),
        .h(data[7]), .i(data[8]), .sel(sel), .out(out));
    task automatic check;
        begin
            #1;
            expected = (sel < 9) ? data[sel] : 16'hffff;
            if (out !== expected)
                $fatal(1, "FAIL sel=%0d expected=%h actual=%h", sel, expected, out);
            checks = checks + 1;
        end
    endtask
    initial begin
        for (p=0; p<9; p=p+1) data[p] = 16'h1234 ^ (p * 16'h1111);
        for (s=0; s<16; s=s+1) begin sel=s; check(); end
        for (n=0; n<2; n=n+1) begin
            for (p=0; p<9; p=p+1) data[p] = n ? 16'hffff : 16'h0000;
            for (s=0; s<16; s=s+1) begin sel=s; check(); end
        end
        for (s=0; s<9; s=s+1) begin
            sel=s;
            for (bit_idx=0; bit_idx<16; bit_idx=bit_idx+1) begin
                for (p=0; p<9; p=p+1) data[p]=16'h0000;
                data[s]=16'h0001 << bit_idx;
                check();
                for (p=0; p<9; p=p+1) data[p]=16'hffff;
                data[s]=~(16'h0001 << bit_idx);
                check();
            end
        end
        for (s=0; s<16; s=s+1) begin
            sel=s;
            for (n=0; n<128; n=n+1) begin
                for (p=0; p<9; p=p+1) begin
                    rng=rng ^ (rng << 13);
                    rng=rng ^ (rng >> 17);
                    rng=rng ^ (rng << 5);
                    data[p]=rng[15:0];
                end
                check();
            end
        end
        $display("PASS: %0d comparisons", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
