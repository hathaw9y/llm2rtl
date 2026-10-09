`timescale 1ns/1ps
module dev_tb;
    logic [3:0] in;
    wire [3:0] out_both, out_any, out_different;
    integer count = 0;
    integer pattern, lane, code;
    TopModule dut (.in(in), .out_both(out_both), .out_any(out_any),
                   .out_different(out_different));

    task automatic check_neighbors;
        integer i;
        logic expected;
        begin
            #1;
            for (i = 0; i < 3; i = i + 1) begin
                expected = in[i] & in[i+1];
                if (out_both[i] !== expected)
                    $fatal(1, "both lane %0d input %b expected %b got %b", i, in, expected, out_both[i]);
            end
            for (i = 1; i < 4; i = i + 1) begin
                expected = in[i] | in[i-1];
                if (out_any[i] !== expected)
                    $fatal(1, "any lane %0d input %b expected %b got %b", i, in, expected, out_any[i]);
            end
            for (i = 0; i < 4; i = i + 1) begin
                expected = in[i] ^ in[(i+1)%4];
                if (out_different[i] !== expected)
                    $fatal(1, "different lane %0d input %b expected %b got %b", i, in, expected, out_different[i]);
            end
            count = count + 1;
        end
    endtask

    initial begin
        // Include the initial undriven X input, then all binary combinations.
        check_neighbors();
        for (pattern = 0; pattern < 16; pattern = pattern + 1) begin
            in = pattern[3:0];
            check_neighbors();
        end
        // Supplemental four-state gate checks; digits encode 0, 1, X, Z.
        for (pattern = 0; pattern < 256; pattern = pattern + 1) begin
            code = pattern;
            for (lane = 0; lane < 4; lane = lane + 1) begin
                case (code % 4)
                    0: in[lane] = 1'b0;
                    1: in[lane] = 1'b1;
                    2: in[lane] = 1'bx;
                    3: in[lane] = 1'bz;
                endcase
                code = code / 4;
            end
            check_neighbors();
        end
        for (pattern = 15; pattern >= 0; pattern = pattern - 1) begin
            in = pattern[3:0];
            check_neighbors();
        end
        $display("PASS neighbor relationships: %0d input checks", count);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
