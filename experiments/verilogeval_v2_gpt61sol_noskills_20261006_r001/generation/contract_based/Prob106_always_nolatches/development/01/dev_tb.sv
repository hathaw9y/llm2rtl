`timescale 1ns/1ps
module dev_tb;
    reg [15:0] scancode;
    wire left, down, right, up;
    integer value;
    integer checks = 0;

    TopModule dut (
        .scancode(scancode),
        .left(left), .down(down), .right(right), .up(up)
    );

    task check_code(input reg [15:0] code);
        reg [3:0] expected;
        begin
            // Independent equality-based oracle from the original table.
            expected = {
                (code === 16'he06b),
                (code === 16'he072),
                (code === 16'he074),
                (code === 16'he075)
            };
            scancode = code;
            #1;
            if ({left, down, right, up} !== expected)
                $fatal(1, "scancode=%h expected=%b actual=%b",
                       code, expected, {left, down, right, up});
            checks = checks + 1;
        end
    endtask

    initial begin
        check_code(16'h0000);
        check_code(16'he06b);
        check_code(16'he06a);
        check_code(16'he072);
        check_code(16'he073);
        check_code(16'he074);
        check_code(16'he075);
        check_code(16'he076);
        check_code(16'hffff);
        check_code(16'h006b);
        check_code(16'he06b);
        check_code(16'h0000);
        for (value = 0; value < 65536; value = value + 1)
            check_code(value[15:0]);
        $display("PASS: %0d scancode comparisons", checks);
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "Timeout");
    end
endmodule
