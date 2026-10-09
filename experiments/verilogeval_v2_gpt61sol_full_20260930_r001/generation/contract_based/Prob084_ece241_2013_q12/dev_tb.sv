`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic enable = 0;
    logic S = 0;
    logic A = 0, B = 0, C = 0;
    wire Z;
    bit expected [0:7];
    integer comparisons = 0;
    integer word_value, serial_index, hold_index;
    TopModule dut (.clk(clk), .enable(enable), .S(S),
                   .A(A), .B(B), .C(C), .Z(Z));

    task automatic check_reads;
        integer address;
        begin
            for (address = 0; address < 8; address = address + 1) begin
                {A,B,C} = address[2:0];
                #1;
                if (Z !== expected[address])
                    $fatal(1, "FAIL address=%0d expected=%b observed=%b", address, expected[address], Z);
                comparisons = comparisons + 1;
            end
        end
    endtask

    task automatic cycle(input bit en, input bit serial_bit, input bit check_known);
        integer stage;
        begin
            enable = en;
            S = serial_bit;
            if (check_known) check_reads();
            #1;
            clk = 1;
            if (en) begin
                for (stage = 7; stage > 0; stage = stage - 1)
                    expected[stage] = expected[stage-1];
                expected[0] = serial_bit;
            end
            #1;
            if (check_known) check_reads();
            clk = 0;
            #1;
            if (check_known) check_reads();
        end
    endtask

    initial begin
        // Fill all stages without assuming any power-up value.
        for (serial_index = 0; serial_index < 8; serial_index = serial_index + 1)
            cycle(1, 0, 0);
        check_reads();
        // Exhaustively load all truth tables, checking intermediate shifts too.
        for (word_value = 0; word_value < 256; word_value = word_value + 1) begin
            for (serial_index = 7; serial_index >= 0; serial_index = serial_index - 1)
                cycle(1, ((word_value >> serial_index) & 1) != 0, 1);
            for (hold_index = 0; hold_index < 8; hold_index = hold_index + 1) begin
                {A,B,C} = hold_index[2:0];
                #1;
                if (Z !== ((word_value >> hold_index) & 1))
                    $fatal(1, "FAIL serial loading word=%0d address=%0d", word_value, hold_index);
                comparisons = comparisons + 1;
            end
            cycle(0, 0, 1);
            cycle(0, 1, 1);
            // Changing enable/S between rising edges must not write storage.
            enable = 1;
            S = ~S;
            check_reads();
            enable = 0;
            check_reads();
        end
        $display("PASS: exhaustive 256-word loading, shift/hold and asynchronous reads; comparisons=%0d", comparisons);
        $finish;
    end

    initial begin
        #1000000;
        $fatal(1, "FAIL: development testbench timeout");
    end
endmodule
