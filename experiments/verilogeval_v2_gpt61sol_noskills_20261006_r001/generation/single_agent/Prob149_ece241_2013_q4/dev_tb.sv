`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg reset = 0;
    reg [2:0] s = 0;
    wire fr2, fr1, fr0, dfr;
    TopModule dut (.clk(clk), .reset(reset), .s(s),
                   .fr2(fr2), .fr1(fr1), .fr0(fr0), .dfr(dfr));
    integer current_level;
    integer last_distinct_level;
    integer count = 0;
    integer a, b, c, k;
    reg [3:0] expected;

    function [2:0] sensors(input integer water);
        case (water)
            0: sensors = 3'b000;
            1: sensors = 3'b001;
            2: sensors = 3'b011;
            3: sensors = 3'b111;
        endcase
    endfunction

    task check_outputs;
        begin
            case (current_level)
                0: expected = 4'b1111;
                1: expected = {3'b011, (last_distinct_level < current_level)};
                2: expected = {3'b001, (last_distinct_level < current_level)};
                3: expected = 4'b0000;
            endcase
            if ({fr2, fr1, fr0, dfr} !== expected)
                $fatal(1, "Check %0d level=%0d prior=%0d got=%b expected=%b",
                       count, current_level, last_distinct_level,
                       {fr2, fr1, fr0, dfr}, expected);
            count = count + 1;
        end
    endtask

    task sample(input integer water, input reg rst);
        begin
            @(negedge clk);
            s = sensors(water);
            reset = rst;
            #1;
            // Synchronous inputs must not change the state before the clock.
            check_outputs;
            @(posedge clk);
            if (rst) begin
                current_level = 0;
                last_distinct_level = 0;
            end else if (water != current_level) begin
                last_distinct_level = current_level;
                current_level = water;
            end
            #1;
            check_outputs;
        end
    endtask

    initial begin
        // No power-up state is specified; first establish it with a clocked reset.
        reset = 1;
        s = 3'b111;
        @(posedge clk);
        current_level = 0;
        last_distinct_level = 0;
        #1;
        check_outputs;
        sample(0, 0);
        sample(1, 0);
        sample(1, 0);
        sample(2, 0);
        sample(2, 0);
        sample(3, 0);
        sample(2, 0);
        sample(2, 0);
        sample(1, 0);
        sample(1, 0);
        sample(0, 0);
        // All valid ordered triples include skipped levels and direction reversals.
        for (a = 0; a < 4; a = a + 1)
            for (b = 0; b < 4; b = b + 1)
                for (c = 0; c < 4; c = c + 1) begin
                    sample(3, 1);
                    sample(a, 0);
                    sample(b, 0);
                    sample(b, 0);
                    sample(c, 0);
                    sample(c, 0);
                end
        // Reset from each level, with each valid sensor value present.
        for (a = 0; a < 4; a = a + 1)
            for (b = 0; b < 4; b = b + 1) begin
                sample(a, 0);
                sample(b, 1);
                sample(b, 0);
            end
        for (k = 0; k < 200; k = k + 1)
            sample($urandom_range(0, 3), 0);
        $display("PASS %0d reservoir output and synchronous timing checks", count);
        $finish;
    end
    initial begin
        #20000;
        $fatal(1, "Timeout");
    end
endmodule
