`timescale 1ns/1ps
module dev_tb;
    logic [7:0] code;
    wire [3:0] out;
    wire valid;
    logic [7:0] scancodes [0:9];
    integer checks = 0;
    TopModule dut (.code(code), .out(out), .valid(valid));

    task automatic check_code(input logic [7:0] stimulus);
        logic expected_valid;
        logic [3:0] expected_out;
        integer key;
        begin
            expected_valid = 1'b0;
            expected_out = 4'd0;
            for (key = 0; key < 10; key = key + 1) begin
                if (stimulus == scancodes[key]) begin
                    expected_valid = 1'b1;
                    expected_out = key;
                end
            end
            code = stimulus;
            #1;
            if (valid !== expected_valid || out !== expected_out)
                $fatal(1, "code=%h expected valid=%b out=%d got valid=%b out=%d",
                       stimulus, expected_valid, expected_out, valid, out);
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
        for (integer key = 0; key < 10; key = key + 1) begin
            check_code(scancodes[key]);
            check_code(8'h00);
            check_code(scancodes[key]);
            check_code(8'hff);
        end
        for (integer value = 0; value < 256; value = value + 1)
            check_code(value[7:0]);
        for (integer value = 255; value >= 0; value = value - 1)
            check_code(value[7:0]);
        $display("PASS: %0d scancode checks", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Testbench timeout");
    end
endmodule
