`timescale 1ns/1ps
module dev_tb;
    reg [5:0] y;
    reg w;
    wire Y1, Y3;
    integer state_index, input_value, repeat_index;
    reg [5:0] expected_next;
    TopModule dut (.y(y), .w(w), .Y1(Y1), .Y3(Y3));

    // Independent oracle: replay each arrow in the original state diagram.
    task check_transition;
        input integer state_number;
        input integer stimulus;
        begin
            y = 6'b000001 << state_number;
            w = stimulus;
            case (state_number)
                0: if (stimulus == 0) expected_next = 6'b000010;
                   else expected_next = 6'b000001;
                1: if (stimulus == 0) expected_next = 6'b000100;
                   else expected_next = 6'b001000;
                2: if (stimulus == 0) expected_next = 6'b010000;
                   else expected_next = 6'b001000;
                3: if (stimulus == 0) expected_next = 6'b100000;
                   else expected_next = 6'b000001;
                4: if (stimulus == 0) expected_next = 6'b010000;
                   else expected_next = 6'b001000;
                5: if (stimulus == 0) expected_next = 6'b000100;
                   else expected_next = 6'b001000;
                default: $fatal(1, "Invalid oracle state");
            endcase
            #1;
            if ({Y3,Y1} !== {expected_next[3],expected_next[1]})
                $fatal(1, "state=%0d w=%0d expected=%b actual=%b",
                    state_number, stimulus, {expected_next[3],expected_next[1]}, {Y3,Y1});
        end
    endtask

    initial begin
        // There is no clock or reset port: A is supplied as an input state.
        check_transition(0, 0);
        check_transition(0, 1);
        for (repeat_index = 0; repeat_index < 2; repeat_index = repeat_index + 1)
            for (state_index = 0; state_index < 6; state_index = state_index + 1)
                for (input_value = 0; input_value < 2; input_value = input_value + 1)
                    check_transition(state_index, input_value);
        $display("PASS: all 12 legal one-hot transitions verified");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
