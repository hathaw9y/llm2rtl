module dev_tb;
    logic [5:0] y;
    logic w;
    wire Y1, Y3;
    integer state_idx, input_idx, next_state;
    TopModule dut (.y(y), .w(w), .Y1(Y1), .Y3(Y3));
    initial begin
        for (state_idx = 0; state_idx < 6; state_idx = state_idx + 1) begin
            for (input_idx = 0; input_idx < 2; input_idx = input_idx + 1) begin
                y = 6'b000001 << state_idx;
                w = (input_idx == 1);
                case (state_idx)
                    0: next_state = w ? 1 : 0;
                    1: next_state = w ? 2 : 3;
                    2: next_state = w ? 4 : 3;
                    3: next_state = w ? 5 : 0;
                    4: next_state = w ? 4 : 3;
                    5: next_state = w ? 2 : 3;
                endcase
                #1;
                if (Y1 !== (next_state == 1) || Y3 !== (next_state == 3))
                    $fatal(1, "FAIL state=%0d w=%0b Y1=%0b Y3=%0b", state_idx, w, Y1, Y3);
            end
        end
        $display("PASS: all 12 legal one-hot state/input combinations");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL timeout");
    end
endmodule
