`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic enable = 0;
    logic S = 0;
    logic A = 0, B = 0, C = 0;
    wire Z;
    logic expected [0:7];
    integer checks = 0;
    integer pattern, bit_index, cycle;
    TopModule dut (.clk(clk), .enable(enable), .S(S), .A(A), .B(B), .C(C), .Z(Z));

    task automatic check_addresses;
        integer address;
        begin
            for (address = 0; address < 8; address = address + 1) begin
                {A, B, C} = address[2:0];
                #1;
                if (Z !== expected[address])
                    $fatal(1, "address %0d: expected %b, got %b at %0t", address, expected[address], Z, $time);
                checks = checks + 1;
            end
        end
    endtask

    task automatic clock_step(input logic shift_enable, input logic serial_bit);
        integer index;
        begin
            // Drive away from the active edge and verify no asynchronous write.
            enable = shift_enable;
            S = serial_bit;
            check_addresses();
            clk = 1;
            if (shift_enable) begin
                for (index = 7; index > 0; index = index - 1)
                    expected[index] = expected[index-1];
                expected[0] = serial_bit;
            end
            #1; // Observe after nonblocking assignments settle.
            check_addresses();
            clk = 0;
            S = ~serial_bit;
            #1;
            check_addresses();
        end
    endtask

    initial begin
        // No reset or initialization is specified; untouched flops start unknown.
        for (cycle = 0; cycle < 8; cycle = cycle + 1)
            expected[cycle] = 1'bx;
        check_addresses();
        clock_step(0, 1);
        // Partial fills retain unknowns at positions not yet written.
        for (cycle = 0; cycle < 8; cycle = cycle + 1)
            clock_step(1, (cycle % 3) == 0);
        clock_step(0, 0);
        clock_step(0, 1);
        // Exhaustively load every truth table, MSB first, and read all taps.
        for (pattern = 0; pattern < 256; pattern = pattern + 1) begin
            for (bit_index = 7; bit_index >= 0; bit_index = bit_index - 1)
                clock_step(1, ((pattern >> bit_index) & 1) != 0);
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                {A, B, C} = bit_index[2:0];
                #1;
                if (Z !== (((pattern >> bit_index) & 1) != 0))
                    $fatal(1, "loaded pattern %0h read address %0d incorrectly", pattern, bit_index);
                checks = checks + 1;
            end
            clock_step(0, pattern[0]);
        end
        $display("PASS: %0d shift, hold, edge, and random-access checks", checks);
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "bounded timeout");
    end
endmodule
