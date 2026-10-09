`timescale 1ns/1ps
module dev_tb;
    logic [15:0] scancode;
    wire left, down, right, up;
    logic [3:0] expected;
    integer i;
    TopModule dut (.scancode(scancode), .left(left), .down(down),
                   .right(right), .up(up));
    initial begin
        for (i = 0; i < 65536; i = i + 1) begin
            scancode = i[15:0];
            expected = {(i == 16'he06b), (i == 16'he072),
                        (i == 16'he074), (i == 16'he075)};
            #1;
            if ({left, down, right, up} !== expected)
                $fatal(1, "FAIL scancode=%h expected=%b actual=%b",
                       scancode, expected, {left, down, right, up});
        end
        $display("PASS: all 65536 scancodes checked");
        $finish;
    end
    initial begin
        #70000;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
