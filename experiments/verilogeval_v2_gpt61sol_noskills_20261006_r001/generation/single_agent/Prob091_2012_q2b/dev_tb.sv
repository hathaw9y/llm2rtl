`timescale 1ns/1ps
module dev_tb;
    reg [5:0] y;
    reg w;
    wire Y1, Y3;
    reg [5:0] expected_next;
    integer state_index, input_value, checks;
    TopModule dut (.y(y), .w(w), .Y1(Y1), .Y3(Y3));

    // Independent oracle: replay each row of the original transition table.
    task check_transition;
        begin
            case (y)
                6'b000001: begin
                    if (w) expected_next = 6'b000010;
                    else   expected_next = 6'b000001;
                end
                6'b000010: begin
                    if (w) expected_next = 6'b000100;
                    else   expected_next = 6'b001000;
                end
                6'b000100: begin
                    if (w) expected_next = 6'b010000;
                    else   expected_next = 6'b001000;
                end
                6'b001000: begin
                    if (w) expected_next = 6'b100000;
                    else   expected_next = 6'b000001;
                end
                6'b010000: begin
                    if (w) expected_next = 6'b010000;
                    else   expected_next = 6'b001000;
                end
                6'b100000: begin
                    if (w) expected_next = 6'b000100;
                    else   expected_next = 6'b001000;
                end
                default: $fatal(1, "Oracle requires a valid one-hot state");
            endcase
            #1;
            if ({Y1,Y3} !== {expected_next[1],expected_next[3]})
                $fatal(1, "y=%b w=%b got Y1,Y3=%b%b expected=%b%b",
                       y, w, Y1, Y3, expected_next[1], expected_next[3]);
            checks = checks + 1;
        end
    endtask

    initial begin
        checks = 0;
        // Check settled combinational outputs; no clock/reset is specified.
        for (state_index = 0; state_index < 6; state_index = state_index + 1)
            for (input_value = 0; input_value < 2; input_value = input_value + 1) begin
                y = 6'b000001 << state_index;
                w = input_value;
                check_transition;
            end
        $display("PASS: all %0d valid state/input transitions checked", checks);
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Development test timeout");
    end
endmodule
