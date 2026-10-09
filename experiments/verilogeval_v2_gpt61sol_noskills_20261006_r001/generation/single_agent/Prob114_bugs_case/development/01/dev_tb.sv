`timescale 1ns/1ps
module dev_tb;
    reg [7:0] code;
    wire [3:0] out;
    wire valid;
    reg [7:0] scancodes [0:9];
    integer i, j, expected_digit, checks;
    reg expected_valid;
    TopModule dut (.code(code), .out(out), .valid(valid));

    task check_code(input reg [7:0] stimulus);
        begin
            expected_digit = 0;
            expected_valid = 0;
            for (j = 0; j < 10; j = j + 1) begin
                if (stimulus === scancodes[j]) begin
                    expected_digit = j;
                    expected_valid = 1;
                end
            end
            code = stimulus;
            #1;
            if (valid !== expected_valid || out !== expected_digit[3:0])
                $fatal(1, "code=%h expected valid=%b out=%d got valid=%b out=%d",
                       stimulus, expected_valid, expected_digit, valid, out);
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
        checks = 0;
        for (i = 0; i < 256; i = i + 1)
            check_code(i[7:0]);
        // Alternate recognized keys and invalid boundaries to detect retained outputs.
        for (i = 9; i >= 0; i = i - 1) begin
            check_code(scancodes[i]);
            check_code(8'h00);
            check_code(scancodes[i]);
            check_code(8'hff);
        end
        $display("PASS: %0d scancode checks", checks);
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
