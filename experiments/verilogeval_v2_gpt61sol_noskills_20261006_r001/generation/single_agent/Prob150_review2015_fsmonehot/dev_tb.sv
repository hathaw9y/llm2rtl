`timescale 1ns/1ps
module dev_tb;
    reg d, done_counting, ack;
    reg [9:0] state;
    wire B3_next, S_next, S1_next, Count_next, Wait_next;
    wire done, counting, shift_ena;
    reg [9:0] expected_next;
    reg [2:0] expected_outputs;
    integer mask, inputs, s, destination, checks;
    TopModule dut (.d(d), .done_counting(done_counting), .ack(ack),
        .state(state), .B3_next(B3_next), .S_next(S_next),
        .S1_next(S1_next), .Count_next(Count_next), .Wait_next(Wait_next),
        .done(done), .counting(counting), .shift_ena(shift_ena));

    // Reference follows the transition table, collecting each active state's
    // contribution. All legal one-hot states and all input combinations are
    // covered; extra masks check the direct one-hot equation interpretation.
    initial begin
        checks = 0;
        for (mask = 0; mask < 1024; mask = mask + 1) begin
            for (inputs = 0; inputs < 8; inputs = inputs + 1) begin
                state = mask;
                {d, done_counting, ack} = inputs;
                expected_next = 0;
                expected_outputs = 0;
                for (s = 0; s < 10; s = s + 1) begin
                    if (state[s]) begin
                        destination = 0;
                        case (s)
                            0: if (d) destination = 1; else destination = 0;
                            1: if (d) destination = 2; else destination = 0;
                            2: if (d) destination = 2; else destination = 3;
                            3: if (d) destination = 4; else destination = 0;
                            4: destination = 5;
                            5: destination = 6;
                            6: destination = 7;
                            7: destination = 8;
                            8: if (done_counting) destination = 9; else destination = 8;
                            9: if (ack) destination = 0; else destination = 9;
                        endcase
                        expected_next[destination] = 1;
                        case (s)
                            4, 5, 6, 7: expected_outputs[0] = 1;
                            8: expected_outputs[1] = 1;
                            9: expected_outputs[2] = 1;
                        endcase
                    end
                end
                #1;
                if ({B3_next, S_next, S1_next, Count_next, Wait_next} !==
                    {expected_next[7], expected_next[0], expected_next[1],
                     expected_next[8], expected_next[9]})
                    $fatal(1, "Next-state mismatch state=%b inputs=%b", state, inputs[2:0]);
                if ({done, counting, shift_ena} !== expected_outputs)
                    $fatal(1, "Output mismatch state=%b inputs=%b", state, inputs[2:0]);
                checks = checks + 1;
            end
        end
        $display("PASS: %0d combinational transition/output checks", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
