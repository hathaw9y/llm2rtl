`timescale 1ns/1ps
module dev_tb;
    logic in;
    logic [9:0] state;
    wire [9:0] next_state;
    wire out1, out2;
    logic [9:0] expected_next;
    logic expected_out1, expected_out2;
    integer mask, input_value, s, destination;
    integer checks = 0;

    TopModule dut (.in(in), .state(state), .next_state(next_state),
                   .out1(out1), .out2(out2));

    initial begin
        #10000;
        $fatal(1, "Timeout");
    end

    initial begin
        // Enumerate every combination, including empty, one-hot and multi-hot.
        for (mask = 0; mask < 1024; mask = mask + 1) begin
            for (input_value = 0; input_value < 2; input_value = input_value + 1) begin
                state = mask[9:0];
                in = input_value[0];
                expected_next = 10'b0;
                expected_out1 = 1'b0;
                expected_out2 = 1'b0;
                // Oracle follows the original per-state transition table.
                for (s = 0; s < 10; s = s + 1) begin
                    if (state[s]) begin
                        case (s)
                            0: if (input_value == 0) destination = 0; else destination = 1;
                            1: if (input_value == 0) destination = 0; else destination = 2;
                            2: if (input_value == 0) destination = 0; else destination = 3;
                            3: if (input_value == 0) destination = 0; else destination = 4;
                            4: if (input_value == 0) destination = 0; else destination = 5;
                            5: if (input_value == 0) destination = 8; else destination = 6;
                            6: if (input_value == 0) destination = 9; else destination = 7;
                            7: if (input_value == 0) destination = 0; else destination = 7;
                            8: if (input_value == 0) destination = 0; else destination = 1;
                            9: if (input_value == 0) destination = 0; else destination = 1;
                            default: $fatal(1, "Invalid oracle state");
                        endcase
                        expected_next[destination] = 1'b1;
                        if (s == 8 || s == 9) expected_out1 = 1'b1;
                        if (s == 7 || s == 9) expected_out2 = 1'b1;
                    end
                end
                #1;
                if ({next_state, out1, out2} !== {expected_next, expected_out1, expected_out2})
                    $fatal(1, "Mismatch state=%b in=%b actual=%b,%b,%b expected=%b,%b,%b",
                           state, in, next_state, out1, out2,
                           expected_next, expected_out1, expected_out2);
                checks = checks + 1;
            end
        end
        $display("PASS exhaustive combinational FSM: %0d checks", checks);
        $finish;
    end
endmodule
