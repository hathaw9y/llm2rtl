`timescale 1ns/1ps
module dev_tb;
    logic [5:0] y;
    logic w;
    wire Y1, Y3;
    logic [5:0] expected_next;
    integer state_index;
    integer input_value;
    integer check_count = 0;

    TopModule dut (.y(y), .w(w), .Y1(Y1), .Y3(Y3));

    // Oracle follows each original transition, independent of DUT equations.
    function automatic logic [5:0] next_state(
        input integer state_number,
        input logic input_w
    );
        case (state_number)
            0: if (input_w) next_state = 6'b000010;
               else         next_state = 6'b000001;
            1: if (input_w) next_state = 6'b000100;
               else         next_state = 6'b001000;
            2: if (input_w) next_state = 6'b010000;
               else         next_state = 6'b001000;
            3: if (input_w) next_state = 6'b100000;
               else         next_state = 6'b000001;
            4: if (input_w) next_state = 6'b010000;
               else         next_state = 6'b001000;
            5: if (input_w) next_state = 6'b000100;
               else         next_state = 6'b001000;
            default: next_state = 6'bxxxxxx;
        endcase
    endfunction

    initial begin
        // Combinational DUT: settle after each stimulus; no clock/reset exists.
        // Repeat in reverse order to check outputs do not retain prior values.
        for (integer sweep = 0; sweep < 2; sweep = sweep + 1) begin
            for (integer index = 0; index < 6; index = index + 1) begin
                if (sweep == 0) state_index = index;
                else state_index = 5 - index;
                for (input_value = 0; input_value < 2; input_value = input_value + 1) begin
                    y = 6'b000001 << state_index;
                    w = input_value[0];
                    expected_next = next_state(state_index, w);
                    #1;
                    if ({Y3, Y1} !== {expected_next[3], expected_next[1]})
                        $fatal(1, "Mismatch y=%b w=%b actual=%b expected=%b",
                               y, w, {Y3, Y1}, {expected_next[3], expected_next[1]});
                    check_count = check_count + 1;
                end
            end
        end
        $display("PASS: %0d one-hot transition checks", check_count);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
