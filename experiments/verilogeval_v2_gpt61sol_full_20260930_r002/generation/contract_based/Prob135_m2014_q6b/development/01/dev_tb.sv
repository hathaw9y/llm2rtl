`timescale 1ns/1ps
module dev_tb;
    logic [2:0] y;
    logic w;
    wire Y1;
    integer checks = 0;
    TopModule dut (.y(y), .w(w), .Y1(Y1));

    // Original transition table, returning the complete destination code.
    function automatic logic [2:0] destination(input integer state, input logic stimulus);
        case (state)
            0: if (stimulus) destination = 3'd0; else destination = 3'd1;
            1: if (stimulus) destination = 3'd3; else destination = 3'd2;
            2: if (stimulus) destination = 3'd3; else destination = 3'd4;
            3: if (stimulus) destination = 3'd0; else destination = 3'd5;
            4: if (stimulus) destination = 3'd3; else destination = 3'd4;
            5: if (stimulus) destination = 3'd3; else destination = 3'd2;
            default: destination = 3'bxxx;
        endcase
    endfunction

    task automatic check_pair(input integer state, input logic stimulus);
        logic [2:0] expected_state;
        begin
            expected_state = destination(state, stimulus);
            y = state[2:0];
            w = stimulus;
            #1;
            if (Y1 !== expected_state[1])
                $fatal(1, "state=%0d w=%b destination=%b expected Y1=%b actual=%b",
                       state, stimulus, expected_state, expected_state[1], Y1);
            checks = checks + 1;
        end
    endtask

    initial begin
        for (integer repeat_index = 0; repeat_index < 3; repeat_index = repeat_index + 1) begin
            for (integer state = 0; state < 6; state = state + 1) begin
                check_pair(state, 1'b0);
                check_pair(state, 1'b1);
            end
            for (integer state = 5; state >= 0; state = state - 1) begin
                check_pair(state, 1'b1);
                check_pair(state, 1'b0);
            end
        end
        $display("PASS: %0d legal combinational transition checks", checks);
        $finish;
    end
    initial begin
        #200;
        $fatal(1, "Timeout");
    end
endmodule
