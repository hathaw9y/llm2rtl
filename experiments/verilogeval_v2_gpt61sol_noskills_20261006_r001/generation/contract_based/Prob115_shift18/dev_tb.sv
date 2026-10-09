`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg load = 0, ena = 0;
    reg [1:0] amount = 0;
    reg [63:0] data = 0;
    wire [63:0] q;
    reg [63:0] expected;
    reg known = 0;
    integer checks = 0;
    reg [63:0] patterns [0:7];
    reg [63:0] rng = 64'hc0ffee123456789a;
    integer p, a, n;
    TopModule dut (.clk(clk), .load(load), .ena(ena), .amount(amount), .data(data), .q(q));
    always #5 clk = ~clk;

    task step(input reg l, input reg e, input reg [1:0] sel, input reg [63:0] d);
        reg [63:0] next_value;
        integer bit_index, distance;
        begin
            @(negedge clk);
            load = l; ena = e; amount = sel; data = d;
            #1;
            if (known && q !== expected)
                $fatal(1, "Non-synchronous change: q=%h expected=%h", q, expected);
            next_value = expected;
            if (l) begin
                next_value = d;
                known = 1;
            end else if (e && known) begin
                if (sel[0]) distance = 8;
                else distance = 1;
                for (bit_index = 0; bit_index < 64; bit_index = bit_index + 1) begin
                    if (sel[1]) begin
                        if (bit_index + distance < 64)
                            next_value[bit_index] = expected[bit_index + distance];
                        else next_value[bit_index] = expected[63];
                    end else begin
                        if (bit_index >= distance)
                            next_value[bit_index] = expected[bit_index - distance];
                        else next_value[bit_index] = 0;
                    end
                end
            end
            @(posedge clk);
            #1;
            expected = next_value;
            if (known) begin
                checks = checks + 1;
                if (q !== expected)
                    $fatal(1, "Mismatch check=%0d load=%b ena=%b amount=%b q=%h expected=%h", checks, l, e, sel, q, expected);
            end
        end
    endtask

    initial begin
        patterns[0] = 64'h0;
        patterns[1] = 64'hffffffffffffffff;
        patterns[2] = 64'h8000000000000000;
        patterns[3] = 64'h7fffffffffffffff;
        patterns[4] = 64'h0000000000000001;
        patterns[5] = 64'h0123456789abcdef;
        patterns[6] = 64'hfedcba9876543210;
        patterns[7] = 64'h8100000000000081;
        // Before the first load the specification gives no defined value.
        step(0, 0, 0, 0);
        for (p = 0; p < 8; p = p + 1) begin
            for (a = 0; a < 4; a = a + 1) begin
                step(1, 0, a[1:0], patterns[p]);
                step(0, 0, a[1:0], ~patterns[p]);
                step(0, 1, a[1:0], 0);
                step(1, 1, a[1:0], patterns[p]);
                for (n = 0; n < 66; n = n + 1)
                    step(0, 1, a[1:0], ~patterns[p]);
            end
        end
        for (n = 0; n < 500; n = n + 1) begin
            rng = rng ^ (rng << 13);
            rng = rng ^ (rng >> 7);
            rng = rng ^ (rng << 17);
            step(rng[0] & rng[4], rng[1], rng[3:2], rng);
        end
        $display("PASS %0d register checks", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Timeout");
    end
endmodule
