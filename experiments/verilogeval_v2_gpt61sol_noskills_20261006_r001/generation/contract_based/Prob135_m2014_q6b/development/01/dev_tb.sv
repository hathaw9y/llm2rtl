`timescale 1ns/1ps
module dev_tb;
    reg [2:0] y;
    reg w;
    wire Y1;
    integer state_index, input_index, checks;
    reg [2:0] destination;
    TopModule dut(.y(y), .w(w), .Y1(Y1));

    // Full next-state oracle transcribed from the original state diagram.
    function automatic [2:0] next_state(input [2:0] current, input bit stimulus);
        case (current)
            3'd0: if (stimulus) next_state = 3'd0; else next_state = 3'd1;
            3'd1: if (stimulus) next_state = 3'd3; else next_state = 3'd2;
            3'd2: if (stimulus) next_state = 3'd3; else next_state = 3'd4;
            3'd3: if (stimulus) next_state = 3'd0; else next_state = 3'd5;
            3'd4: if (stimulus) next_state = 3'd3; else next_state = 3'd4;
            3'd5: if (stimulus) next_state = 3'd3; else next_state = 3'd2;
            default: next_state = 3'bxxx;
        endcase
    endfunction

    task automatic check(input [2:0] current, input bit stimulus);
        begin
            y = current;
            w = stimulus;
            destination = next_state(current, stimulus);
            #1;
            if (Y1 !== destination[1])
                $fatal(1, "y=%b w=%b expected Y1=%b actual=%b", y, w, destination[1], Y1);
            checks = checks + 1;
        end
    endtask

    initial begin
        checks = 0;
        for (state_index = 0; state_index < 6; state_index = state_index + 1)
            for (input_index = 0; input_index < 2; input_index = input_index + 1)
                check(state_index[2:0], input_index[0]);
        for (input_index = 1; input_index >= 0; input_index = input_index - 1)
            for (state_index = 5; state_index >= 0; state_index = state_index - 1)
                check(state_index[2:0], input_index[0]);
        $display("PASS: %0d legal state/input checks", checks);
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
