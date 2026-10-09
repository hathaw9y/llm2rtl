`timescale 1ns/1ps
module dev_tb;
    reg [5:0] y;
    reg w;
    wire Y1, Y3;
    integer mask, bit_w, state_index, destination;
    integer checks = 0;
    reg [5:0] next_state;
    TopModule dut (.y(y), .w(w), .Y1(Y1), .Y3(Y3));

    // Independent oracle: destinations transcribed from the original diagram.
    function integer transition(input integer state_id, input integer stimulus);
        begin
            case (state_id)
                0: if (stimulus == 0) transition = 1; else transition = 0;
                1: if (stimulus == 0) transition = 2; else transition = 3;
                2: if (stimulus == 0) transition = 4; else transition = 3;
                3: if (stimulus == 0) transition = 5; else transition = 0;
                4: if (stimulus == 0) transition = 4; else transition = 3;
                5: if (stimulus == 0) transition = 2; else transition = 3;
                default: transition = -1;
            endcase
        end
    endfunction

    task check_outputs(input reg expected1, input reg expected3);
        begin
            #1;
            if (Y1 !== expected1 || Y3 !== expected3)
                $fatal(1, "Mismatch y=%b w=%b actual=%b%b expected=%b%b", y,w,Y1,Y3,expected1,expected3);
            checks = checks + 1;
        end
    endtask

    initial begin
        // Every legal transition, plus all Boolean superpositions and zero state.
        // Invalid-state cases verify the equation extension, not reset recovery.
        for (mask = 0; mask < 64; mask = mask + 1) begin
            for (bit_w = 0; bit_w < 2; bit_w = bit_w + 1) begin
                y = mask;
                w = bit_w;
                next_state = 0;
                for (state_index = 0; state_index < 6; state_index = state_index + 1) begin
                    if (mask & (1 << state_index)) begin
                        destination = transition(state_index, bit_w);
                        next_state[destination] = 1'b1;
                    end
                end
                check_outputs(next_state[1], next_state[3]);
            end
        end
        // Four-state combinational behavior: controlling values and propagation.
        y = 6'b000001; w = 1'bx; check_outputs(1'bx, 1'b0);
        y = 6'b000010; w = 1'bx; check_outputs(1'b0, 1'bx);
        y = 6'b001000; w = 1'bx; check_outputs(1'b0, 1'b0);
        y = 6'bxxxxxx; w = 1'b0; check_outputs(1'bx, 1'b0);
        y = 6'bxxxxxx; w = 1'b1; check_outputs(1'b0, 1'bx);
        y = 6'bx00010; w = 1'b1; check_outputs(1'b0, 1'b1);
        $display("PASS: %0d next-state checks", checks);
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "Bounded timeout");
    end
endmodule
