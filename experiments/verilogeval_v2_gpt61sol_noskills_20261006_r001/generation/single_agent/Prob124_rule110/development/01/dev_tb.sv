`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg load = 0;
    reg [511:0] data = 0;
    wire [511:0] q;
    reg [511:0] expected;
    reg [511:0] pattern;
    integer checks = 0;
    integer i, j, k;
    TopModule dut (.clk(clk), .load(load), .data(data), .q(q));
    always #5 clk = ~clk;

    function automatic [511:0] advance(input [511:0] state);
        integer n;
        reg l, c, r;
        begin
            for (n = 0; n < 512; n = n + 1) begin
                if (n == 511) l = 0; else l = state[n+1];
                c = state[n];
                if (n == 0) r = 0; else r = state[n-1];
                case ({l,c,r})
                    3'b111: advance[n] = 0;
                    3'b110: advance[n] = 1;
                    3'b101: advance[n] = 1;
                    3'b100: advance[n] = 0;
                    3'b011: advance[n] = 1;
                    3'b010: advance[n] = 1;
                    3'b001: advance[n] = 1;
                    3'b000: advance[n] = 0;
                    default: advance[n] = 1'bx;
                endcase
            end
        end
    endfunction

    task automatic cycle(input reg loading, input reg [511:0] value);
        reg [511:0] before_edge;
        begin
            @(negedge clk);
            before_edge = q;
            load = loading;
            data = value;
            #1;
            if (q !== before_edge) $fatal(1, "Output changed without positive clock edge");
            if (loading) expected = value;
            else expected = advance(expected);
            @(posedge clk);
            #1;
            checks = checks + 1;
            if (q !== expected)
                $fatal(1, "Mismatch at check %0d: got %h expected %h", checks, q, expected);
        end
    endtask

    initial begin
        // No reset or initialization is specified; load before checking states.
        expected = 'x;
        cycle(1, '0);
        repeat (4) cycle(0, '1);
        cycle(1, '1);
        repeat (5) cycle(0, '0);
        // Cover all eight neighborhoods at an interior cell.
        for (k = 0; k < 8; k = k + 1) begin
            pattern = 0;
            pattern[257:255] = k;
            cycle(1, pattern);
            cycle(0, ~pattern);
        end
        // Single cells exercise both fixed-zero boundaries and propagation.
        for (k = 0; k < 3; k = k + 1) begin
            pattern = 0;
            if (k == 0) pattern[0] = 1;
            else if (k == 1) pattern[511] = 1;
            else pattern[256] = 1;
            cycle(1, pattern);
            repeat (12) cycle(0, '0);
        end
        pattern = {256{2'b10}};
        cycle(1, pattern);
        repeat (10) cycle(0, '1);
        // Consecutive loads must replace evolution at each rising edge.
        for (i = 0; i < 20; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1)
                pattern[j*32 +: 32] = $random;
            cycle(1, pattern);
        end
        for (i = 0; i < 30; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1)
                pattern[j*32 +: 32] = $random;
            cycle(1, pattern);
            repeat (10) cycle(0, ~pattern);
        end
        $display("PASS Rule 110: %0d checked cycles", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
