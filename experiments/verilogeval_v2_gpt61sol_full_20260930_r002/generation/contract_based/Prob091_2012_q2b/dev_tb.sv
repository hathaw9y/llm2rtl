`timescale 1ns/1ps
module dev_tb;
    logic [5:0] y;
    logic w;
    wire Y1, Y3;
    integer checks = 0;
    integer state_index, input_value, repeat_index;
    TopModule dut (.y(y), .w(w), .Y1(Y1), .Y3(Y3));

    // Original transition table, expressed as destination-state indices.
    function automatic integer destination(input integer current, input bit stimulus);
        case (current)
            0: if (stimulus) destination = 1; else destination = 0;
            1: if (stimulus) destination = 2; else destination = 3;
            2: if (stimulus) destination = 4; else destination = 3;
            3: if (stimulus) destination = 5; else destination = 0;
            4: if (stimulus) destination = 4; else destination = 3;
            5: if (stimulus) destination = 2; else destination = 3;
            default: destination = -1;
        endcase
    endfunction

    task automatic check_state(input integer current, input bit stimulus);
        integer next_state;
        bit expected_y1, expected_y3;
        begin
            y = 6'b000001 << current;
            w = stimulus;
            next_state = destination(current, stimulus);
            expected_y1 = (next_state == 1);
            expected_y3 = (next_state == 3);
            #1;
            if ({Y1,Y3} !== {expected_y1,expected_y3})
                $fatal(1, "State=%0d w=%b: got %b%b expected %b%b",
                       current, stimulus, Y1, Y3, expected_y1, expected_y3);
            checks = checks + 1;
        end
    endtask

    initial begin
        // No prescribed startup/reset behavior: drive legal states after startup.
        #1;
        for (repeat_index = 0; repeat_index < 3; repeat_index = repeat_index + 1)
            for (state_index = 0; state_index < 6; state_index = state_index + 1)
                for (input_value = 0; input_value < 2; input_value = input_value + 1)
                    check_state(state_index, input_value != 0);
        // Reverse order checks falling/rising input and state changes too.
        for (state_index = 5; state_index >= 0; state_index = state_index - 1) begin
            check_state(state_index, 1'b1);
            check_state(state_index, 1'b0);
        end
        $display("PASS %0d legal transition checks", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
