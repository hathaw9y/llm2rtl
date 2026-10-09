module dev_tb;
    logic [5:0] y;
    logic w;
    wire Y1, Y3;
    integer state_index, input_value, pass_index, destination, checks;
    logic expected_y1, expected_y3;
    TopModule dut (.y(y), .w(w), .Y1(Y1), .Y3(Y3));

    // State indices: A=0, B=1, C=2, D=3, E=4, F=5.
    function automatic integer next_state(input integer state_id, input integer bit_value);
        case (state_id)
            0: next_state = bit_value ? 1 : 0;
            1: next_state = bit_value ? 2 : 3;
            2: next_state = bit_value ? 4 : 3;
            3: next_state = bit_value ? 5 : 0;
            4: next_state = bit_value ? 4 : 3;
            5: next_state = bit_value ? 2 : 3;
            default: next_state = -1;
        endcase
    endfunction

    initial begin
        checks = 0;
        for (pass_index = 0; pass_index < 2; pass_index = pass_index + 1) begin
            for (state_index = 0; state_index < 6; state_index = state_index + 1) begin
                for (input_value = 0; input_value < 2; input_value = input_value + 1) begin
                    y = 6'b000001 << (pass_index ? 5-state_index : state_index);
                    w = input_value[0];
                    destination = next_state(pass_index ? 5-state_index : state_index, input_value);
                    expected_y1 = (destination == 1);
                    expected_y3 = (destination == 3);
                    #1;
                    if ({Y1, Y3} !== {expected_y1, expected_y3})
                        $fatal(1, "FAIL y=%b w=%b actual=%b%b expected=%b%b", y, w, Y1, Y3, expected_y1, expected_y3);
                    checks = checks + 1;
                end
            end
        end
        $display("PASS: %0d checks, all 12 legal transitions covered twice", checks);
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: watchdog timeout");
    end
endmodule
