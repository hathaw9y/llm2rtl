`timescale 1ns/1ps
module dev_tb;
    reg [15:0] data [0:8];
    reg [3:0] sel;
    wire [15:0] out;
    integer n, s, bit_index, round_index;
    integer checks = 0;
    reg [31:0] rng = 32'h12345678;
    TopModule dut (.a(data[0]), .b(data[1]), .c(data[2]),
        .d(data[3]), .e(data[4]), .f(data[5]),
        .g(data[6]), .h(data[7]), .i(data[8]), .sel(sel), .out(out));

    task check_output;
        reg [15:0] expected;
        begin
            #1;
            if (sel < 9) expected = data[sel];
            else expected = 16'hffff;
            if (out !== expected)
                $fatal(1, "sel=%0d expected=%h actual=%h", sel, expected, out);
            checks = checks + 1;
        end
    endtask

    task check_all_selectors;
        integer selector;
        begin
            for (selector = 0; selector < 16; selector = selector + 1) begin
                sel = selector;
                check_output;
            end
        end
    endtask

    initial begin
        sel = 0;
        for (n = 0; n < 9; n = n + 1) data[n] = 0;
        check_all_selectors;
        for (n = 0; n < 9; n = n + 1) data[n] = 16'hffff;
        check_all_selectors;
        for (n = 0; n < 9; n = n + 1)
            data[n] = (n % 2) ? 16'haaaa : 16'h5555;
        check_all_selectors;
        for (n = 0; n < 9; n = n + 1) begin
            for (s = 0; s < 9; s = s + 1) data[s] = 0;
            for (bit_index = 0; bit_index < 16; bit_index = bit_index + 1) begin
                data[n] = 16'h0001 << bit_index;
                check_all_selectors;
                data[n] = ~(16'h0001 << bit_index);
                check_all_selectors;
            end
        end
        for (round_index = 0; round_index < 64; round_index = round_index + 1) begin
            for (n = 0; n < 9; n = n + 1) begin
                rng = rng ^ (rng << 13);
                rng = rng ^ (rng >> 17);
                rng = rng ^ (rng << 5);
                data[n] = rng[15:0];
            end
            check_all_selectors;
        end
        for (s = 0; s < 9; s = s + 1) begin
            sel = s;
            data[s] = 16'h0000;
            check_output;
            data[s] = 16'hffff;
            check_output;
            data[s] = 16'hxxxx;
            check_output;
        end
        $display("PASS: %0d mux checks", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Development test timeout");
    end
endmodule
