`timescale 1ns/1ps
module dev_tb;
    logic [15:0] scancode;
    wire left, down, right, up;
    integer code;
    integer checks = 0;
    TopModule dut (.scancode(scancode), .left(left), .down(down),
                   .right(right), .up(up));

    task automatic check_code(input logic [15:0] value);
        logic [3:0] expected;
        begin
            // Independent oracle: each output recognizes exactly its listed code.
            expected[3] = (value == 16'he06b);
            expected[2] = (value == 16'he072);
            expected[1] = (value == 16'he074);
            expected[0] = (value == 16'he075);
            scancode = value;
            #1;
            if ({left, down, right, up} !== expected)
                $fatal(1, "scancode=%h expected=%b actual=%b", value,
                       expected, {left, down, right, up});
            checks = checks + 1;
        end
    endtask

    initial begin
        check_code(16'he06b);
        check_code(16'h0000);
        check_code(16'he072);
        check_code(16'hffff);
        check_code(16'he074);
        check_code(16'he075);
        check_code(16'he06b);
        check_code(16'h006b);
        check_code(16'he072);
        check_code(16'h0072);
        check_code(16'he074);
        check_code(16'h0074);
        check_code(16'he075);
        check_code(16'h0075);
        for (code = 0; code < 65536; code = code + 1)
            check_code(code[15:0]);
        $display("PASS: %0d scancode checks", checks);
        $finish;
    end

    initial begin
        #70000;
        $fatal(1, "Timeout");
    end
endmodule
