`timescale 1ns/1ps
module dev_tb;
    logic d, done_counting, ack;
    logic [9:0] state;
    wire B3_next, S_next, S1_next, Count_next, Wait_next;
    wire done, counting, shift_ena;
    logic [7:0] expected;
    integer s, inputs, next_s, checked;
    TopModule dut (.*);
    initial begin
        checked = 0;
        for (s = 0; s < 10; s = s + 1) begin
            for (inputs = 0; inputs < 8; inputs = inputs + 1) begin
                state = 10'b1 << s;
                {d, done_counting, ack} = inputs[2:0];
                case (s)
                    0: next_s = d ? 1 : 0;
                    1: next_s = d ? 2 : 0;
                    2: next_s = d ? 2 : 3;
                    3: next_s = d ? 4 : 0;
                    4: next_s = 5;
                    5: next_s = 6;
                    6: next_s = 7;
                    7: next_s = 8;
                    8: next_s = done_counting ? 9 : 8;
                    9: next_s = ack ? 0 : 9;
                    default: next_s = 0;
                endcase
                expected = {next_s == 7, next_s == 0, next_s == 1,
                            next_s == 8, next_s == 9,
                            s == 9, s == 8, (s >= 4 && s <= 7)};
                #1;
                if ({B3_next, S_next, S1_next, Count_next, Wait_next,
                     done, counting, shift_ena} !== expected)
                    $fatal(1, "FAIL state=%0d inputs=%0d", s, inputs);
                checked = checked + 1;
            end
        end
        $display("PASS: %0d legal one-hot/input combinations", checked);
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "FAIL: timeout");
    end
endmodule
