`timescale 1ns/1ps
module dev_tb;
    reg [2:0] y;
    reg w;
    wire Y1;
    reg [2:0] expected_next;
    integer state_index, input_value;
    integer checked;
    TopModule dut (.y(y), .w(w), .Y1(Y1));

    // Full destination-state oracle transcribed from the original graph.
    function automatic [2:0] destination(input integer state_number, input integer stimulus);
        begin
            case (state_number)
                0: if (stimulus == 0) destination = 3'd1; else destination = 3'd0;
                1: if (stimulus == 0) destination = 3'd2; else destination = 3'd3;
                2: if (stimulus == 0) destination = 3'd4; else destination = 3'd3;
                3: if (stimulus == 0) destination = 3'd5; else destination = 3'd0;
                4: if (stimulus == 0) destination = 3'd4; else destination = 3'd3;
                5: if (stimulus == 0) destination = 3'd2; else destination = 3'd3;
                default: destination = 3'bxxx;
            endcase
        end
    endfunction

    initial begin
        checked = 0;
        // Sweep both directions to check input changes and state changes.
        for (state_index = 0; state_index < 6; state_index = state_index + 1) begin
            for (input_value = 0; input_value < 2; input_value = input_value + 1) begin
                y = state_index;
                w = input_value;
                expected_next = destination(state_index, input_value);
                #1;
                if (Y1 !== expected_next[1])
                    $fatal(1, "state=%0d w=%0d expected=%b actual=%b", state_index, input_value, expected_next[1], Y1);
                checked = checked + 1;
            end
        end
        for (state_index = 5; state_index >= 0; state_index = state_index - 1) begin
            for (input_value = 1; input_value >= 0; input_value = input_value - 1) begin
                y = state_index;
                w = input_value;
                expected_next = destination(state_index, input_value);
                #1;
                if (Y1 !== expected_next[1])
                    $fatal(1, "reverse state=%0d w=%0d expected=%b actual=%b", state_index, input_value, expected_next[1], Y1);
                checked = checked + 1;
            end
        end
        $display("PASS: %0d combinational next-state checks", checked);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
