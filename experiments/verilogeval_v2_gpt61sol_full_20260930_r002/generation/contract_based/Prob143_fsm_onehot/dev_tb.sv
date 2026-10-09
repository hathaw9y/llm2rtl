`timescale 1ns/1ps
module dev_tb;
    logic in;
    logic [9:0] state;
    wire [9:0] next_state;
    wire out1, out2;
    integer pattern, input_value, source, target, checks;
    logic [9:0] expected_next;
    logic expected_out1, expected_out2;

    TopModule dut (.in(in), .state(state), .next_state(next_state),
                   .out1(out1), .out2(out2));

    // Table follows the original diagram by source, independently of DUT equations.
    function automatic integer destination(input integer s, input integer bit_in);
        begin
            case (s)
                0: if (bit_in == 0) destination = 0; else destination = 1;
                1: if (bit_in == 0) destination = 0; else destination = 2;
                2: if (bit_in == 0) destination = 0; else destination = 3;
                3: if (bit_in == 0) destination = 0; else destination = 4;
                4: if (bit_in == 0) destination = 0; else destination = 5;
                5: if (bit_in == 0) destination = 8; else destination = 6;
                6: if (bit_in == 0) destination = 9; else destination = 7;
                7: if (bit_in == 0) destination = 0; else destination = 7;
                8: if (bit_in == 0) destination = 0; else destination = 1;
                9: if (bit_in == 0) destination = 0; else destination = 1;
                default: destination = -1;
            endcase
        end
    endfunction

    initial begin
        checks = 0;
        for (pattern = 0; pattern < 1024; pattern = pattern + 1) begin
            for (input_value = 0; input_value < 2; input_value = input_value + 1) begin
                state = pattern[9:0];
                in = input_value[0];
                expected_next = 10'b0;
                expected_out1 = 1'b0;
                expected_out2 = 1'b0;
                for (source = 0; source < 10; source = source + 1) begin
                    if (state[source]) begin
                        target = destination(source, input_value);
                        expected_next[target] = 1'b1;
                        case (source)
                            7: expected_out2 = 1'b1;
                            8: expected_out1 = 1'b1;
                            9: begin
                                expected_out1 = 1'b1;
                                expected_out2 = 1'b1;
                            end
                            default: begin end
                        endcase
                    end
                end
                #1;
                if ({next_state, out1, out2} !==
                    {expected_next, expected_out1, expected_out2})
                    $fatal(1, "state=%b in=%b got=%b,%b,%b expected=%b,%b,%b",
                        state, in, next_state, out1, out2,
                        expected_next, expected_out1, expected_out2);
                checks = checks + 1;
            end
        end
        $display("PASS exhaustive binary transition/output checks: %0d", checks);
        $finish;
    end

    initial begin
        #3000;
        $fatal(1, "Timeout before exhaustive verification completed");
    end
endmodule
