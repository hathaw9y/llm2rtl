`timescale 1ns/1ps
module dev_tb;
    logic [15:0] scancode;
    wire left, down, right, up;
    logic [3:0] expected;
    integer i;
    integer checks = 0;

    TopModule dut (.scancode(scancode), .left(left), .down(down),
                   .right(right), .up(up));

    // The original table defines each direction independently.
    task automatic check_code(input logic [15:0] value);
        begin
            scancode = value;
            #1;
            expected[3] = (value === 16'he06b);
            expected[2] = (value === 16'he072);
            expected[1] = (value === 16'he074);
            expected[0] = (value === 16'he075);
            if ({left, down, right, up} !== expected)
                $fatal(1, "scancode=%h expected=%b actual=%b", value,
                       expected, {left, down, right, up});
            checks = checks + 1;
        end
    endtask

    initial begin
        check_code(16'h0000);
        check_code(16'he06b);
        check_code(16'he072);
        check_code(16'he074);
        check_code(16'he075);
        check_code(16'hffff);
        check_code(16'he06b);
        check_code(16'h006b);
        check_code(16'he072);
        check_code(16'he073);
        check_code(16'he074);
        check_code(16'he076);
        check_code(16'he075);
        check_code(16'hf075);
        for (i = 0; i < 65536; i = i + 1)
            check_code(i[15:0]);
        // Supplemental X/Z cases: full exact case matching falls through.
        check_code(16'he06b);
        check_code(16'hxxxx);
        check_code(16'he072);
        check_code(16'hzzzz);
        check_code(16'he074);
        check_code(16'he07x);
        check_code(16'he075);
        check_code(16'he07z);
        $display("PASS all %0d combinational decoder checks", checks);
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "Timeout waiting for decoder checks");
    end
endmodule
