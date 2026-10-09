module dev_tb;
    logic [5:0] y;
    logic w;
    wire Y1, Y3;
    integer state_index, input_value, next_state, checks;
    TopModule dut (.y(y), .w(w), .Y1(Y1), .Y3(Y3));
    initial begin
        checks = 0;
        for (state_index = 0; state_index < 6; state_index = state_index + 1) begin
            for (input_value = 0; input_value < 2; input_value = input_value + 1) begin
                y = 6'b000001 << state_index;
                w = (input_value == 1);
                case (state_index)
                    0: next_state = w ? 0 : 1;
                    1: next_state = w ? 3 : 2;
                    2: next_state = w ? 3 : 4;
                    3: next_state = w ? 0 : 5;
                    4: next_state = w ? 3 : 4;
                    5: next_state = w ? 3 : 2;
                    default: $fatal(1, "Invalid test state");
                endcase
                #1;
                if (Y1 !== (next_state == 1) || Y3 !== (next_state == 3))
                    $fatal(1, "FAIL state=%0d w=%b Y1=%b Y3=%b", state_index, w, Y1, Y3);
                checks = checks + 1;
            end
        end
        $display("PASS: %0d legal one-hot transitions", checks);
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
