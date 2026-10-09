`timescale 1ns/1ps
module dev_tb;
    logic [7:0] code;
    wire [3:0] out;
    wire valid;
    logic [7:0] scancodes [0:9];
    integer checks = 0;
    integer n;
    TopModule dut (.code(code), .out(out), .valid(valid));

    task automatic check_code(input logic [7:0] value);
        logic [3:0] expected_out;
        logic expected_valid;
        integer digit;
        begin
            expected_out = 4'd0;
            expected_valid = 1'b0;
            for (digit = 0; digit < 10; digit = digit + 1) begin
                if (value == scancodes[digit]) begin
                    expected_out = digit[3:0];
                    expected_valid = 1'b1;
                end
            end
            code = value;
            #1;
            if (out !== expected_out || valid !== expected_valid)
                $fatal(1, "code=%h expected out=%d valid=%b got out=%h valid=%b", value, expected_out, expected_valid, out, valid);
            checks = checks + 1;
        end
    endtask

    initial begin
        scancodes[0] = 8'h45;
        scancodes[1] = 8'h16;
        scancodes[2] = 8'h1e;
        scancodes[3] = 8'h26;
        scancodes[4] = 8'h25;
        scancodes[5] = 8'h2e;
        scancodes[6] = 8'h36;
        scancodes[7] = 8'h3d;
        scancodes[8] = 8'h3e;
        scancodes[9] = 8'h46;
        // Exhaustive input-space coverage in both directions tests history independence.
        for (n = 0; n < 256; n = n + 1) check_code(n[7:0]);
        for (n = 255; n >= 0; n = n - 1) check_code(n[7:0]);
        for (n = 0; n < 10; n = n + 1) begin
            check_code(scancodes[n]);
            check_code(8'h00);
            check_code(scancodes[n]);
            check_code(8'hff);
        end
        $display("PASS exhaustive scancode decoder checks=%0d", checks);
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
