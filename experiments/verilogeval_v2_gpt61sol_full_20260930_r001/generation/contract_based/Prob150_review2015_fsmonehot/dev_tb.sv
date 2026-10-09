module dev_tb;
    logic d, done_counting, ack;
    logic [9:0] state;
    wire B3_next, S_next, S1_next, Count_next, Wait_next;
    wire done, counting, shift_ena;
    integer current_state, inputs, next_state, checks;
    logic [7:0] expected;
    TopModule dut (.*);

    initial begin
        checks = 0;
        for (current_state = 0; current_state < 10; current_state = current_state + 1) begin
            for (inputs = 0; inputs < 8; inputs = inputs + 1) begin
                state = 10'b1 << current_state;
                {d, done_counting, ack} = inputs[2:0];
                case (current_state)
                    0: next_state = d ? 1 : 0;
                    1: next_state = d ? 2 : 0;
                    2: next_state = d ? 2 : 3;
                    3: next_state = d ? 4 : 0;
                    4: next_state = 5;
                    5: next_state = 6;
                    6: next_state = 7;
                    7: next_state = 8;
                    8: next_state = done_counting ? 9 : 8;
                    9: next_state = ack ? 0 : 9;
                    default: $fatal(1, "Invalid oracle state");
                endcase
                expected = {next_state == 7, next_state == 0,
                            next_state == 1, next_state == 8,
                            next_state == 9, current_state == 9,
                            current_state == 8,
                            (current_state >= 4 && current_state <= 7)};
                #1;
                if ({B3_next, S_next, S1_next, Count_next, Wait_next,
                     done, counting, shift_ena} !== expected)
                    $fatal(1, "FAIL state=%0d inputs=%03b expected=%08b actual=%08b",
                           current_state, inputs[2:0], expected,
                           {B3_next, S_next, S1_next, Count_next, Wait_next,
                            done, counting, shift_ena});
                checks = checks + 1;
            end
        end
        $display("PASS: %0d exhaustive legal-state/input checks", checks);
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "FAIL: development simulation timeout");
    end
endmodule
