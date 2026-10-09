`timescale 1ns/1ps
module dev_tb;
    logic d, done_counting, ack;
    logic [9:0] state;
    wire B3_next, S_next, S1_next, Count_next, Wait_next;
    wire done, counting, shift_ena;
    integer s, inputs, next_index, checks;
    logic [7:0] expected;
    TopModule dut (.*);

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end

    initial begin
        checks = 0;
        for (s = 0; s < 10; s = s + 1) begin
            for (inputs = 0; inputs < 8; inputs = inputs + 1) begin
                state = 10'b0000000001 << s;
                {d, done_counting, ack} = inputs[2:0];
                // Independent oracle: execute the original transition table.
                case (s)
                    0: if (d) next_index = 1; else next_index = 0;
                    1: if (d) next_index = 2; else next_index = 0;
                    2: if (d) next_index = 2; else next_index = 3;
                    3: if (d) next_index = 4; else next_index = 0;
                    4: next_index = 5;
                    5: next_index = 6;
                    6: next_index = 7;
                    7: next_index = 8;
                    8: if (done_counting) next_index = 9; else next_index = 8;
                    9: if (ack) next_index = 0; else next_index = 9;
                    default: $fatal(1, "Invalid oracle state");
                endcase
                expected = {next_index == 7, next_index == 0,
                            next_index == 1, next_index == 8,
                            next_index == 9, s == 9, s == 8,
                            (s >= 4 && s <= 7)};
                #1;
                if ({B3_next, S_next, S1_next, Count_next, Wait_next,
                     done, counting, shift_ena} !== expected)
                    $fatal(1, "Mismatch state index=%0d inputs=%b expected=%b actual=%b",
                           s, {d, done_counting, ack}, expected,
                           {B3_next, S_next, S1_next, Count_next, Wait_next,
                            done, counting, shift_ena});
                checks = checks + 1;
            end
        end
        $display("PASS: %0d exhaustive one-hot state/input checks", checks);
        $finish;
    end
endmodule
