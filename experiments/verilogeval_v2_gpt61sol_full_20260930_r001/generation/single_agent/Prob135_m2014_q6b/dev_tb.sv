module dev_tb;
    logic [2:0] y;
    logic w;
    wire Y1;
    logic [2:0] next_state;
    integer state_index, input_index, checks;
    TopModule dut (.y(y), .w(w), .Y1(Y1));
    initial begin
        checks = 0;
        for (state_index = 0; state_index < 6; state_index = state_index + 1) begin
            for (input_index = 0; input_index < 2; input_index = input_index + 1) begin
                y = state_index[2:0];
                w = input_index[0];
                case (y)
                    3'd0: next_state = w ? 3'd0 : 3'd1;
                    3'd1: next_state = w ? 3'd3 : 3'd2;
                    3'd2: next_state = w ? 3'd3 : 3'd4;
                    3'd3: next_state = w ? 3'd0 : 3'd5;
                    3'd4: next_state = w ? 3'd3 : 3'd4;
                    3'd5: next_state = w ? 3'd3 : 3'd2;
                    default: next_state = 3'd0;
                endcase
                #1;
                if (Y1 !== next_state[1])
                    $fatal(1, "FAIL y=%b w=%b Y1=%b expected=%b", y, w, Y1, next_state[1]);
                checks = checks + 1;
            end
        end
        $display("PASS: %0d valid state/input combinations", checks);
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: timeout");
    end
endmodule
