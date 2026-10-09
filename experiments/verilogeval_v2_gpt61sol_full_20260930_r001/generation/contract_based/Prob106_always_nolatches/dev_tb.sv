`timescale 1ns/1ps
module dev_tb;
    logic [15:0] scancode;
    wire left, down, right, up;
    integer checks = 0;
    TopModule dut (.scancode(scancode), .left(left), .down(down), .right(right), .up(up));
    task automatic check_code(input logic [15:0] code);
        logic [3:0] expected;
        begin
            scancode = code;
            expected = {code == 16'he06b, code == 16'he072,
                        code == 16'he074, code == 16'he075};
            #1;
            if ({left, down, right, up} !== expected)
                $fatal(1, "FAIL code=%h expected=%b actual=%b", code, expected, {left,down,right,up});
            checks = checks + 1;
        end
    endtask
    initial begin
        check_code(16'he06b);
        check_code(16'he072);
        check_code(16'he074);
        check_code(16'he075);
        check_code(16'h0000);
        check_code(16'he06b);
        check_code(16'hffff);
        for (integer value = 0; value < 65536; value = value + 1)
            check_code(value[15:0]);
        $display("PASS: %0d checks, exhaustive 65536 binary scancodes and directed transitions", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "FAIL simulation watchdog timeout");
    end
endmodule
