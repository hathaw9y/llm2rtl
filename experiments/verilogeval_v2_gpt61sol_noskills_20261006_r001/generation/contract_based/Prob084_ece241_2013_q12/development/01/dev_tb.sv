`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg enable = 0;
    reg S = 0;
    reg A = 0, B = 0, C = 0;
    wire Z;
    reg expected [0:7];
    reg [7:0] word_value;
    integer i, n;
    integer checks = 0;
    TopModule dut (.clk(clk), .enable(enable), .S(S), .A(A), .B(B), .C(C), .Z(Z));

    task check_addresses;
        integer address;
        begin
            for (address = 0; address < 8; address = address + 1) begin
                {A, B, C} = address[2:0];
                #1;
                if (Z !== expected[address])
                    $fatal(1, "address %0d expected %b observed %b time %0t", address, expected[address], Z, $time);
                checks = checks + 1;
            end
        end
    endtask

    task cycle(input reg shift_enable, input reg serial_bit);
        integer k;
        begin
            clk = 0;
            enable = shift_enable;
            S = serial_bit;
            check_addresses(); // Changes in S/enable cannot write asynchronously.
            #2;
            clk = 1;
            if (shift_enable) begin
                for (k = 7; k > 0; k = k - 1)
                    expected[k] = expected[k-1];
                expected[0] = serial_bit;
            end
            #1;
            check_addresses();
            #2;
            clk = 0;
            #1;
            check_addresses(); // Falling edge must preserve state.
        end
    endtask

    initial begin
        for (i = 0; i < 8; i = i + 1) expected[i] = 1'bx;
        #1;
        check_addresses();
        cycle(0, 1);
        // Partial filling checks both written bits and remaining unknown state.
        for (n = 0; n < 8; n = n + 1) cycle(1, (n % 3) == 0);
        cycle(0, 0);
        cycle(0, 1);
        // Load distinct words MSB first, then check against their indexed bits.
        for (n = 0; n < 256; n = n + 1) begin
            word_value = n[7:0];
            for (i = 7; i >= 0; i = i - 1) cycle(1, word_value[i]);
            for (i = 0; i < 8; i = i + 1) begin
                {A, B, C} = i[2:0];
                #1;
                if (Z !== word_value[i]) $fatal(1, "MSB-first load failed word %h index %0d", word_value, i);
                checks = checks + 1;
            end
            cycle(0, ~word_value[0]);
        end
        for (n = 0; n < 64; n = n + 1)
            cycle((n % 4) != 0, ((n * 7 + n / 3) % 2) != 0);
        $display("PASS: %0d checks completed", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Timeout");
    end
endmodule
