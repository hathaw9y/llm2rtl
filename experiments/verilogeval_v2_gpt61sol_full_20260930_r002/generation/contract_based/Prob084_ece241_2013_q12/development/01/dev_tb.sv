`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic enable = 0;
    logic S = 0;
    logic A = 0, B = 0, C = 0;
    wire Z;
    logic expected [0:7];
    integer checks = 0;
    integer pattern, bit_number, i;
    TopModule dut (.clk(clk), .enable(enable), .S(S),
                   .A(A), .B(B), .C(C), .Z(Z));

    task automatic check_addresses;
        integer address;
        begin
            for (address = 0; address < 8; address = address + 1) begin
                {A,B,C} = address[2:0];
                #1;
                if (Z !== expected[address])
                    $fatal(1, "Mismatch address=%0d expected=%b actual=%b time=%0t", address, expected[address], Z, $time);
                checks = checks + 1;
            end
        end
    endtask

    task automatic cycle(input logic shift_enable, input logic serial_bit);
        integer k;
        begin
            enable = shift_enable;
            S = serial_bit;
            check_addresses(); // No clock edge: neither S nor enable changes state.
            clk = 1;
            if (shift_enable) begin
                for (k = 7; k > 0; k = k - 1)
                    expected[k] = expected[k-1];
                expected[0] = serial_bit;
            end
            #1; // Observe after nonblocking updates.
            check_addresses();
            // A changed serial input during the high phase must not shift.
            S = ~serial_bit;
            #1;
            check_addresses();
            clk = 0;
            #1;
            check_addresses();
        end
    endtask

    initial begin
        for (i = 0; i < 8; i = i + 1) expected[i] = 1'bx;
        #1;
        check_addresses();
        cycle(0, 0);
        cycle(0, 1);
        // Exhaust all possible stored truth tables, MSB shifted first.
        for (pattern = 0; pattern < 256; pattern = pattern + 1) begin
            for (bit_number = 7; bit_number >= 0; bit_number = bit_number - 1) begin
                cycle(1, ((pattern >> bit_number) & 1) != 0);
                if ((bit_number % 3) == 0)
                    cycle(0, ((pattern >> bit_number) & 1) == 0);
            end
            // Independently check completed serial ordering against the pattern.
            for (i = 0; i < 8; i = i + 1) begin
                {A,B,C} = i[2:0];
                #1;
                if (Z !== (((pattern >> i) & 1) != 0))
                    $fatal(1, "Completed pattern=%0d address=%0d Z=%b", pattern, i, Z);
                checks = checks + 1;
            end
        end
        $display("PASS: %0d checks of shift, hold, edge timing and all addresses", checks);
        $finish;
    end
    initial begin
        #200000;
        $fatal(1, "Timeout");
    end
endmodule
