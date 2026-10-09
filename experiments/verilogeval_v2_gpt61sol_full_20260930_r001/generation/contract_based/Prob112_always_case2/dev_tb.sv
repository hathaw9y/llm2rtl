`timescale 1ns/1ps
module dev_tb;
    logic [3:0] in;
    wire [1:0] pos;
    logic [1:0] expected [0:15];
    integer source_pattern, destination_pattern;
    integer checks;
    TopModule dut (.in(in), .pos(pos));

    task automatic check_pattern(input integer pattern);
        in = pattern[3:0];
        #1;
        if (pos !== expected[pattern])
            $fatal(1, "FAIL input=%b expected=%d actual=%d", in, expected[pattern], pos);
        checks = checks + 1;
    endtask

    initial begin
        expected[0] = 0; expected[1] = 0;
        expected[2] = 1; expected[3] = 0;
        expected[4] = 2; expected[5] = 0;
        expected[6] = 1; expected[7] = 0;
        expected[8] = 3; expected[9] = 0;
        expected[10] = 1; expected[11] = 0;
        expected[12] = 2; expected[13] = 0;
        expected[14] = 1; expected[15] = 0;
        checks = 0;
        for (source_pattern = 0; source_pattern < 16; source_pattern = source_pattern + 1)
            for (destination_pattern = 0; destination_pattern < 16; destination_pattern = destination_pattern + 1) begin
                check_pattern(source_pattern);
                check_pattern(destination_pattern);
            end
        $display("PASS: all 16 binary patterns and 256 ordered transitions; %0d comparisons", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "FAIL watchdog timeout");
    end
endmodule
