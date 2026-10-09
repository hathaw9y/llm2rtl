`timescale 1ns/1ps
module dev_tb;
    reg in;
    reg [9:0] state;
    wire [9:0] next_state;
    wire out1, out2;
    reg [9:0] expected_next;
    reg expected_out1, expected_out2;
    integer mask, stimulus, s, destination;
    integer checks;
    TopModule dut (.in(in), .state(state), .next_state(next_state), .out1(out1), .out2(out2));

    initial begin
        checks = 0;
        // Exhaust every combination, including zero-hot and multi-hot states.
        for (mask = 0; mask < 1024; mask = mask + 1) begin
            for (stimulus = 0; stimulus < 2; stimulus = stimulus + 1) begin
                state = mask;
                in = stimulus;
                expected_next = 10'b0;
                expected_out1 = 0;
                expected_out2 = 0;
                // Independently replay the listed transition for each active state.
                for (s = 0; s < 10; s = s + 1) begin
                    if (state[s]) begin
                        case (s)
                            0: if (stimulus == 0) destination = 0; else destination = 1;
                            1: if (stimulus == 0) destination = 0; else destination = 2;
                            2: if (stimulus == 0) destination = 0; else destination = 3;
                            3: if (stimulus == 0) destination = 0; else destination = 4;
                            4: if (stimulus == 0) destination = 0; else destination = 5;
                            5: if (stimulus == 0) destination = 8; else destination = 6;
                            6: if (stimulus == 0) destination = 9; else destination = 7;
                            7: if (stimulus == 0) destination = 0; else destination = 7;
                            8: if (stimulus == 0) destination = 0; else destination = 1;
                            9: if (stimulus == 0) destination = 0; else destination = 1;
                        endcase
                        expected_next[destination] = 1;
                        if (s == 8 || s == 9) expected_out1 = 1;
                        if (s == 7 || s == 9) expected_out2 = 1;
                    end
                end
                #1;
                if ({next_state, out1, out2} !== {expected_next, expected_out1, expected_out2})
                    $fatal(1, "state=%b in=%b got=%b/%b%b expected=%b/%b%b", state, in, next_state, out1, out2, expected_next, expected_out1, expected_out2);
                checks = checks + 1;
            end
        end
        $display("PASS exhaustive combinational checks: %0d", checks);
        $finish;
    end
    initial begin
        #3000;
        $fatal(1, "Timeout");
    end
endmodule
