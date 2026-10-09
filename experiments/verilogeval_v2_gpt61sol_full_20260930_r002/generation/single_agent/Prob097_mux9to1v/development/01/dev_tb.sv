`timescale 1ns/1ps
module dev_tb;
    logic [15:0] inputs [0:8];
    logic [3:0] sel;
    wire [15:0] out;
    integer checks = 0;
    TopModule dut (.a(inputs[0]), .b(inputs[1]), .c(inputs[2]),
                   .d(inputs[3]), .e(inputs[4]), .f(inputs[5]),
                   .g(inputs[6]), .h(inputs[7]), .i(inputs[8]),
                   .sel(sel), .out(out));
    task automatic check_output(input integer selection);
        logic [15:0] expected;
        begin
            sel = selection;
            #1;
            if (selection < 9) expected = inputs[selection];
            else expected = 16'hffff;
            if (out !== expected)
                $fatal(1, "sel=%0d expected=%h actual=%h", selection, expected, out);
            checks = checks + 1;
        end
    endtask
    initial begin
        for (integer n = 0; n < 9; n = n + 1) inputs[n] = 16'h1020 + n;
        for (integer s = 0; s < 16; s = s + 1) check_output(s);
        for (integer bit_index = 0; bit_index < 16; bit_index = bit_index + 1) begin
            for (integer n = 0; n < 9; n = n + 1) inputs[n] = 16'h0000;
            for (integer n = 0; n < 9; n = n + 1) begin
                inputs[n] = 16'h0001 << bit_index;
                for (integer s = 0; s < 16; s = s + 1) check_output(s);
                inputs[n] = 16'h0000;
            end
        end
        for (integer trial = 0; trial < 100; trial = trial + 1) begin
            for (integer n = 0; n < 9; n = n + 1) inputs[n] = $urandom;
            for (integer s = 15; s >= 0; s = s - 1) check_output(s);
        end
        for (integer n = 0; n < 9; n = n + 1) inputs[n] = 16'hffff;
        for (integer s = 0; s < 16; s = s + 1) check_output(s);
        $display("PASS %0d multiplexer checks", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
