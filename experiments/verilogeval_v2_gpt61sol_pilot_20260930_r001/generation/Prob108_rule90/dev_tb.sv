`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic load = 0;
    logic [511:0] data = '0;
    wire [511:0] q;
    logic [511:0] expected, next_expected, seed;
    integer checks = 0;
    integer i, j, k;
    reg [31:0] rng = 32'h5380a261;
    TopModule dut (.clk(clk), .load(load), .data(data), .q(q));
    always #5 clk = ~clk;
    task automatic cycle(input logic do_load, input logic [511:0] payload);
        begin
            @(negedge clk);
            load = do_load;
            data = payload;
            #1;
            if (checks > 0 && q !== expected)
                $fatal(1, "State changed away from rising edge");
            if (do_load) next_expected = payload;
            else begin
                for (integer n = 0; n < 512; n = n + 1) begin
                    if (n == 0) next_expected[n] = expected[1];
                    else if (n == 511) next_expected[n] = expected[510];
                    else next_expected[n] = expected[n-1] ^ expected[n+1];
                end
            end
            @(posedge clk);
            #1;
            expected = next_expected;
            if (q !== expected) $fatal(1,"Mismatch at check %0d", checks);
            checks = checks + 1;
        end
    endtask
    initial begin
        cycle(1, '0);
        cycle(0, '1);
        cycle(1, '1);
        repeat (8) cycle(0, '0);
        for (i = 0; i < 512; i = i + 1) begin
            seed = '0;
            seed[i] = 1'b1;
            cycle(1, seed);
            repeat (4) cycle(0, '0);
        end
        cycle(1, {256{2'b10}});
        repeat (32) cycle(0, '0);
        for (j = 0; j < 300; j = j + 1) begin
            for (k = 0; k < 512; k = k + 1) begin
                rng = rng ^ (rng << 13);
                rng = rng ^ (rng >> 17);
                rng = rng ^ (rng << 5);
                seed[k] = rng[0];
            end
            cycle((j % 7 < 2), seed);
        end
        $display("PASS: %0d complete-state comparisons", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Timeout");
    end
endmodule
