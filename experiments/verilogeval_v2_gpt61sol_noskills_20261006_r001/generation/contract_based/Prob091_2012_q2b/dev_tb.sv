`timescale 1ns/1ps
module dev_tb;
    reg [5:0] y;
    reg w;
    wire Y1, Y3;
    integer state_index, input_value, checks;
    reg [5:0] destination;
    TopModule dut (.y(y), .w(w), .Y1(Y1), .Y3(Y3));

    // Destination states copied from the original transition table.
    function automatic [5:0] next_state(input integer state_id, input integer value);
        begin
            case (state_id)
                0: if (value == 1) next_state = 6'b000010; else next_state = 6'b000001;
                1: if (value == 1) next_state = 6'b000100; else next_state = 6'b001000;
                2: if (value == 1) next_state = 6'b010000; else next_state = 6'b001000;
                3: if (value == 1) next_state = 6'b100000; else next_state = 6'b000001;
                4: if (value == 1) next_state = 6'b010000; else next_state = 6'b001000;
                5: if (value == 1) next_state = 6'b000100; else next_state = 6'b001000;
                default: next_state = 6'bxxxxxx;
            endcase
        end
    endfunction

    task automatic check_pair(input integer state_id, input integer value);
        begin
            y = 6'b000001 << state_id;
            w = value;
            destination = next_state(state_id, value);
            #1;
            if ({Y3, Y1} !== {destination[3], destination[1]})
                $fatal(1, "state=%0d w=%0d expected Y3,Y1=%b%b actual=%b%b",
                       state_id, value, destination[3], destination[1], Y3, Y1);
            checks = checks + 1;
        end
    endtask

    initial begin
        checks = 0;
        for (state_index = 0; state_index < 6; state_index = state_index + 1)
            for (input_value = 0; input_value < 2; input_value = input_value + 1)
                check_pair(state_index, input_value);
        for (state_index = 5; state_index >= 0; state_index = state_index - 1)
            for (input_value = 1; input_value >= 0; input_value = input_value - 1)
                check_pair(state_index, input_value);
        $display("PASS: %0d transition-table checks", checks);
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
