`timescale 1ns/1ps
module dev_tb;
    logic [15:0] lanes [0:8];
    logic [3:0] sel;
    wire [15:0] out;
    integer checks = 0;
    integer lane, selector, bit_index, iteration;
    TopModule dut (.a(lanes[0]), .b(lanes[1]), .c(lanes[2]),
                   .d(lanes[3]), .e(lanes[4]), .f(lanes[5]),
                   .g(lanes[6]), .h(lanes[7]), .i(lanes[8]),
                   .sel(sel), .out(out));
    task automatic check_selection(input integer selected);
        logic [15:0] expected;
        begin
            sel = selected;
            if (selected < 9) expected = lanes[selected];
            else expected = 16'hffff;
            #1;
            if (out !== expected)
                $fatal(1, "selector=%0d expected=%h actual=%h", selected, expected, out);
            checks = checks + 1;
        end
    endtask
    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
    initial begin
        for (lane = 0; lane < 9; lane = lane + 1)
            lanes[lane] = 16'h1234 + lane * 16'h1111;
        for (selector = 0; selector < 16; selector = selector + 1)
            check_selection(selector);
        for (bit_index = 0; bit_index < 16; bit_index = bit_index + 1) begin
            for (lane = 0; lane < 9; lane = lane + 1)
                lanes[lane] = (16'h0001 << bit_index) ^ (16'h0101 * lane);
            for (selector = 0; selector < 16; selector = selector + 1)
                check_selection(selector);
        end
        for (lane = 0; lane < 9; lane = lane + 1) lanes[lane] = 16'h0000;
        for (selector = 0; selector < 16; selector = selector + 1) check_selection(selector);
        for (lane = 0; lane < 9; lane = lane + 1) lanes[lane] = 16'hffff;
        for (selector = 0; selector < 16; selector = selector + 1) check_selection(selector);
        for (iteration = 0; iteration < 100; iteration = iteration + 1) begin
            for (lane = 0; lane < 9; lane = lane + 1) lanes[lane] = $urandom;
            for (selector = 0; selector < 16; selector = selector + 1) check_selection(selector);
        end
        // A selected unknown data bit must pass through unchanged.
        lanes[8] = 16'hx5a5;
        check_selection(8);
        check_selection(9);
        $display("PASS %0d mux checks", checks);
        $finish;
    end
endmodule
