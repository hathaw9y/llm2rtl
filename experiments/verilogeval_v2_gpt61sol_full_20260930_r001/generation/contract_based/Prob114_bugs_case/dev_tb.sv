`timescale 1ns/1ps
module dev_tb;
    logic [7:0] code;
    wire [3:0] out;
    wire valid;
    logic [7:0] scancodes [0:9];
    integer checks = 0;
    TopModule dut (.code(code), .out(out), .valid(valid));

    task automatic check_code(input integer value);
        logic [3:0] expected_out;
        logic expected_valid;
        begin
            expected_out = 4'd0;
            expected_valid = 1'b0;
            for (integer digit = 0; digit < 10; digit = digit + 1) begin
                if (value == scancodes[digit]) begin
                    expected_out = digit;
                    expected_valid = 1'b1;
                end
            end
            code = value;
            #1;
            if (out !== expected_out || valid !== expected_valid)
                $fatal(1, "FAIL code=%h out=%h valid=%b expected=%h,%b",
                       code, out, valid, expected_out, expected_valid);
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
        for (integer value = 0; value < 256; value = value + 1)
            check_code(value);
        for (integer value = 255; value >= 0; value = value - 1)
            check_code(value);
        $display("PASS: %0d checks covering all 256 binary codes twice", checks);
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
