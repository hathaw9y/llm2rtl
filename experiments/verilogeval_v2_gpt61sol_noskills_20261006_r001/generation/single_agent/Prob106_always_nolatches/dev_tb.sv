`timescale 1ns/1ps
module dev_tb;
    reg [15:0] scancode;
    wire left, down, right, up;
    integer value;
    integer checks = 0;
    TopModule dut(.scancode(scancode), .left(left), .down(down),
                  .right(right), .up(up));

    task check_code(input [15:0] code);
        reg [3:0] expected;
        begin
            // Independent oracle: each output recognizes its own exact code.
            expected[3] = (code == 16'he06b);
            expected[2] = (code == 16'he072);
            expected[1] = (code == 16'he074);
            expected[0] = (code == 16'he075);
            scancode = code;
            #1;
            if ({left, down, right, up} !== expected)
                $fatal(1, "code=%h expected=%b actual=%b", code,
                       expected, {left, down, right, up});
            checks = checks + 1;
        end
    endtask

    initial begin
        // Active-to-active and active-to-none transitions catch retained outputs.
        check_code(16'he06b);
        check_code(16'he072);
        check_code(16'he074);
        check_code(16'he075);
        check_code(16'h0000);
        check_code(16'he06b);
        check_code(16'hffff);
        check_code(16'he072);
        check_code(16'h0072);
        check_code(16'he074);
        check_code(16'hf074);
        check_code(16'he075);
        check_code(16'he076);
        // Exhaust every defined 16-bit input, including all neighboring codes.
        for (value = 0; value < 65536; value = value + 1)
            check_code(value[15:0]);
        $display("PASS: %0d scancode checks", checks);
        $finish;
    end
    initial begin
        #70000;
        $fatal(1, "Timeout");
    end
endmodule
