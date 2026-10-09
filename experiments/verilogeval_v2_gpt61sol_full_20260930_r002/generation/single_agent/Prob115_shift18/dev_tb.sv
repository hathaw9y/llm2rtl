`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic load = 0, ena = 0;
    logic [1:0] amount = 0;
    logic [63:0] data = 0;
    wire [63:0] q;
    logic [63:0] expected;
    integer checks = 0;
    integer i, j, k;
    logic [63:0] patterns [0:7];
    TopModule dut(.clk(clk), .load(load), .ena(ena), .amount(amount), .data(data), .q(q));
    always #5 clk = ~clk;

    task automatic step(input logic l, input logic e,
                        input logic [1:0] a, input logic [63:0] d);
        logic [63:0] before_q, next_q;
        integer bit_idx, distance;
        begin
            @(negedge clk);
            before_q = q;
            load = l; ena = e; amount = a; data = d;
            next_q = expected;
            if (l) next_q = d;
            else if (e) begin
                distance = a[0] ? 8 : 1;
                for (bit_idx = 0; bit_idx < 64; bit_idx = bit_idx + 1) begin
                    if (!a[1]) begin
                        if (bit_idx < distance) next_q[bit_idx] = 0;
                        else next_q[bit_idx] = expected[bit_idx-distance];
                    end else begin
                        if (bit_idx + distance >= 64) next_q[bit_idx] = expected[63];
                        else next_q[bit_idx] = expected[bit_idx+distance];
                    end
                end
            end
            #1;
            if (q !== before_q) $fatal(1, "q changed before rising edge");
            @(posedge clk);
            #1;
            expected = next_q;
            checks = checks + 1;
            if (q !== expected)
                $fatal(1, "check %0d load=%b ena=%b amount=%b expected=%h actual=%h", checks, l, e, a, expected, q);
        end
    endtask

    initial begin
        // No reset or initialization is specified: hold the simulator's unknown state.
        expected = 64'hxxxxxxxxxxxxxxxx;
        step(0, 0, 0, 0);
        patterns[0] = 64'h0000000000000000;
        patterns[1] = 64'hffffffffffffffff;
        patterns[2] = 64'h8000000000000000;
        patterns[3] = 64'h7fffffffffffffff;
        patterns[4] = 64'h0000000000000001;
        patterns[5] = 64'h0123456789abcdef;
        patterns[6] = 64'hfedcba9876543210;
        patterns[7] = 64'haa55aa55aa55aa55;
        for (i = 0; i < 8; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                step(1, 0, j, patterns[i]);
                step(0, 0, j, ~patterns[i]);
                for (k = 0; k < 65; k = k + 1) step(0, 1, j, 0);
                // Simultaneous load and enable must select load.
                step(1, 1, j, patterns[i]);
                step(0, 1, j, 0);
            end
        end
        for (i = 0; i < 400; i = i + 1)
            step($urandom_range(0,1), $urandom_range(0,1), $urandom_range(0,3), {$urandom, $urandom});
        $display("PASS %0d development checks", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "timeout");
    end
endmodule
