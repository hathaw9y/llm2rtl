`timescale 1ns/1ps
module dev_tb;
    reg [7:0] code;
    wire [3:0] out;
    wire valid;
    reg [7:0] scancode [0:9];
    integer i;
    integer checks = 0;
    TopModule dut (.code(code), .out(out), .valid(valid));

    task check_code(input [7:0] stimulus);
        reg [3:0] expected_out;
        reg expected_valid;
        integer digit;
        begin
            expected_out = 0;
            expected_valid = 0;
            for (digit = 0; digit < 10; digit = digit + 1) begin
                if (stimulus == scancode[digit]) begin
                    expected_out = digit;
                    expected_valid = 1;
                end
            end
            code = stimulus;
            #1;
            if (out !== expected_out || valid !== expected_valid)
                $fatal(1, "code=%h expected out=%d valid=%b got out=%d valid=%b",
                       stimulus, expected_out, expected_valid, out, valid);
            checks = checks + 1;
        end
    endtask

    initial begin
        scancode[0] = 8'h45;
        scancode[1] = 8'h16;
        scancode[2] = 8'h1e;
        scancode[3] = 8'h26;
        scancode[4] = 8'h25;
        scancode[5] = 8'h2e;
        scancode[6] = 8'h36;
        scancode[7] = 8'h3d;
        scancode[8] = 8'h3e;
        scancode[9] = 8'h46;
        for (i = 0; i < 256; i = i + 1) check_code(i);
        for (i = 255; i >= 0; i = i - 1) check_code(i);
        for (i = 0; i < 10; i = i + 1) begin
            check_code(scancode[i]);
            check_code(8'h00);
            check_code(scancode[i]);
            check_code(8'hff);
        end
        $display("PASS: %0d decoder checks", checks);
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
