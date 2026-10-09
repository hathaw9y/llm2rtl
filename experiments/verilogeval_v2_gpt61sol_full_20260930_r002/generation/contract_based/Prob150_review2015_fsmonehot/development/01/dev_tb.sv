`timescale 1ns/1ps
module dev_tb;
    logic d, done_counting, ack;
    logic [9:0] state;
    wire B3_next, S_next, S1_next, Count_next, Wait_next;
    wire done, counting, shift_ena;
    logic [9:0] expected_next;
    logic [2:0] expected_outputs;
    integer vector_index, input_index, source_index, destination;
    integer checks = 0;

    TopModule dut (
        .d(d), .done_counting(done_counting), .ack(ack), .state(state),
        .B3_next(B3_next), .S_next(S_next), .S1_next(S1_next),
        .Count_next(Count_next), .Wait_next(Wait_next),
        .done(done), .counting(counting), .shift_ena(shift_ena)
    );

    task automatic check_current;
        begin
            expected_next = 10'b0;
            expected_outputs = 3'b0;
            // Traverse the original transition table, rather than copying DUT equations.
            for (source_index = 0; source_index < 10; source_index = source_index + 1) begin
                if (state[source_index]) begin
                    case (source_index)
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
                        default: $fatal(1, "Oracle source out of bounds");
                    endcase
                    expected_next[destination] = 1'b1;
                    case (source_index)
                        4, 5, 6, 7: expected_outputs[0] = 1'b1;
                        8: expected_outputs[1] = 1'b1;
                        9: expected_outputs[2] = 1'b1;
                        default: begin end
                    endcase
                end
            end
            #1;
            if ({B3_next, S_next, S1_next, Count_next, Wait_next} !==
                {expected_next[7], expected_next[0], expected_next[1], expected_next[8], expected_next[9]})
                $fatal(1, "Next-state mismatch state=%b d=%b dc=%b ack=%b actual=%b expected=%b",
                    state, d, done_counting, ack,
                    {B3_next, S_next, S1_next, Count_next, Wait_next},
                    {expected_next[7], expected_next[0], expected_next[1], expected_next[8], expected_next[9]});
            if ({done, counting, shift_ena} !== expected_outputs)
                $fatal(1, "Moore mismatch state=%b actual=%b expected=%b", state,
                    {done, counting, shift_ena}, expected_outputs);
            checks = checks + 1;
        end
    endtask

    initial begin
        // External reset state S: no DUT reset port or cycle exists.
        state = 10'b0000000001;
        {d, done_counting, ack} = 3'b000;
        check_current();
        // Legal one-hot states, including every irrelevant input combination.
        for (vector_index = 0; vector_index < 10; vector_index = vector_index + 1) begin
            state = 10'b1 << vector_index;
            for (input_index = 0; input_index < 8; input_index = input_index + 1) begin
                {d, done_counting, ack} = input_index[2:0];
                check_current();
            end
        end
        // Supplemental equation-superposition checks for all binary state vectors.
        for (vector_index = 0; vector_index < 1024; vector_index = vector_index + 1) begin
            state = vector_index[9:0];
            for (input_index = 0; input_index < 8; input_index = input_index + 1) begin
                {d, done_counting, ack} = input_index[2:0];
                check_current();
            end
        end
        $display("PASS dev_tb: %0d combinational checks", checks);
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
