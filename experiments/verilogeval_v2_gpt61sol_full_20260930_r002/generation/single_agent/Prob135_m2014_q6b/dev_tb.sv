`timescale 1ns/1ps
module dev_tb;
    logic [2:0] y;
    logic w;
    wire Y1;
    logic [2:0] expected_next;
    integer state_idx, input_idx, pass_idx;
    TopModule dut (.y(y), .w(w), .Y1(Y1));

    // Oracle is the complete original transition table, not a bit equation.
    function automatic [2:0] transition(input integer state_code, input logic input_w);
        case (state_code)
            0: if (input_w) transition = 3'd0; else transition = 3'd1;
            1: if (input_w) transition = 3'd3; else transition = 3'd2;
            2: if (input_w) transition = 3'd3; else transition = 3'd4;
            3: if (input_w) transition = 3'd0; else transition = 3'd5;
            4: if (input_w) transition = 3'd3; else transition = 3'd4;
            5: if (input_w) transition = 3'd3; else transition = 3'd2;
            default: transition = 3'bxxx;
        endcase
    endfunction

    initial begin
        // Repeated sweeps exercise both input edges and transitions between states.
        for (pass_idx = 0; pass_idx < 2; pass_idx = pass_idx + 1) begin
            for (state_idx = 0; state_idx < 6; state_idx = state_idx + 1) begin
                for (input_idx = 0; input_idx < 2; input_idx = input_idx + 1) begin
                    y = state_idx;
                    w = input_idx ^ pass_idx;
                    expected_next = transition(state_idx, w);
                    #1;
                    if (Y1 !== expected_next[1])
                        $fatal(1, "y=%b w=%b expected Y1=%b got=%b", y, w, expected_next[1], Y1);
                end
            end
        end
        $display("PASS all 12 specified state/input pairs checked twice");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
