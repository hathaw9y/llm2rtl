`timescale 1ns/1ps
module dev_tb;
    logic [5:0] y;
    logic w;
    wire Y1, Y3;
    integer state_index, input_value, next_index;
    logic [5:0] expected_next;
    integer checks = 0;

    TopModule dut (.y(y), .w(w), .Y1(Y1), .Y3(Y3));

    initial begin
        #100;
        $fatal(1, "Timeout");
    end

    initial begin
        // Oracle: enumerate destinations directly from the original diagram.
        // No clock or reset port exists: y is the externally supplied state.
        for (state_index = 0; state_index < 6; state_index = state_index + 1) begin
            for (input_value = 0; input_value < 2; input_value = input_value + 1) begin
                y = 6'b000001 << state_index;
                w = (input_value == 1);
                case (state_index)
                    0: if (input_value == 0) next_index = 1; else next_index = 0;
                    1: if (input_value == 0) next_index = 2; else next_index = 3;
                    2: if (input_value == 0) next_index = 4; else next_index = 3;
                    3: if (input_value == 0) next_index = 5; else next_index = 0;
                    4: if (input_value == 0) next_index = 4; else next_index = 3;
                    5: if (input_value == 0) next_index = 2; else next_index = 3;
                    default: $fatal(1, "Invalid oracle state");
                endcase
                expected_next = 6'b000001 << next_index;
                #1;
                if ({Y3, Y1} !== {expected_next[3], expected_next[1]})
                    $fatal(1, "State=%0d w=%0b expected=%b%b actual=%b%b", state_index, w,
                           expected_next[3], expected_next[1], Y3, Y1);
                checks = checks + 1;
            end
        end
        $display("PASS: all %0d legal one-hot transitions checked", checks);
        $finish;
    end
endmodule
