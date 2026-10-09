`timescale 1ns/1ps
module dev_tb;
    reg in;
    reg [9:0] state;
    wire [9:0] next_state;
    wire out1, out2;
    reg [9:0] expected_next;
    reg expected_out1, expected_out2;
    integer vector_index, input_value, source_index, destination, checks;
    TopModule dut(.in(in), .state(state), .next_state(next_state),
                  .out1(out1), .out2(out2));

    initial begin
        checks = 0;
        for (vector_index = 0; vector_index < 1024; vector_index = vector_index + 1) begin
            for (input_value = 0; input_value < 2; input_value = input_value + 1) begin
                state = vector_index;
                in = input_value;
                expected_next = 10'b0;
                expected_out1 = 0;
                expected_out2 = 0;
                for (source_index = 0; source_index < 10; source_index = source_index + 1) begin
                    if (state[source_index]) begin
                        // Each case is one row of the original transition table.
                        case (source_index)
                            0: begin if (in) destination = 1; else destination = 0; end
                            1: begin if (in) destination = 2; else destination = 0; end
                            2: begin if (in) destination = 3; else destination = 0; end
                            3: begin if (in) destination = 4; else destination = 0; end
                            4: begin if (in) destination = 5; else destination = 0; end
                            5: begin if (in) destination = 6; else destination = 8; end
                            6: begin if (in) destination = 7; else destination = 9; end
                            7: begin if (in) destination = 7; else destination = 0; end
                            8: begin if (in) destination = 1; else destination = 0; end
                            9: begin if (in) destination = 1; else destination = 0; end
                            default: $fatal(1, "Invalid oracle source");
                        endcase
                        expected_next[destination] = 1;
                        if (source_index == 8 || source_index == 9) expected_out1 = 1;
                        if (source_index == 7 || source_index == 9) expected_out2 = 1;
                    end
                end
                #1;
                if ({next_state, out1, out2} !== {expected_next, expected_out1, expected_out2})
                    $fatal(1, "state=%b in=%b got=%b,%b,%b expected=%b,%b,%b",
                           state, in, next_state, out1, out2,
                           expected_next, expected_out1, expected_out2);
                checks = checks + 1;
            end
        end
        $display("PASS: %0d exhaustive combinational cases", checks);
        $finish;
    end
    initial begin
        #3000;
        $fatal(1, "Timeout");
    end
endmodule
