`timescale 1ns/1ps
module dev_tb;
    logic in;
    logic [9:0] state;
    wire [9:0] next_state;
    wire out1, out2;
    logic [9:0] expected_next;
    logic expected_out1, expected_out2;
    integer mask, input_value, source, destination;
    TopModule dut (.in(in), .state(state), .next_state(next_state),
                   .out1(out1), .out2(out2));
    initial begin
        for (mask = 0; mask < 1024; mask = mask + 1) begin
            for (input_value = 0; input_value < 2; input_value = input_value + 1) begin
                state = 10'(mask);
                in = 1'(input_value);
                expected_next = 10'b0;
                expected_out1 = 1'b0;
                expected_out2 = 1'b0;
                for (source = 0; source < 10; source = source + 1) begin
                    if (state[source]) begin
                        if (input_value == 0) begin
                            case (source)
                                5: destination = 8;
                                6: destination = 9;
                                default: destination = 0;
                            endcase
                        end else begin
                            case (source)
                                0, 8, 9: destination = 1;
                                7: destination = 7;
                                default: destination = source + 1;
                            endcase
                        end
                        expected_next[destination] = 1'b1;
                        if (source == 8 || source == 9) expected_out1 = 1'b1;
                        if (source == 7 || source == 9) expected_out2 = 1'b1;
                    end
                end
                #1;
                if ({next_state, out1, out2} !== {expected_next, expected_out1, expected_out2})
                    $fatal(1, "FAIL state=%b in=%b actual=%b expected=%b", state, in,
                           {next_state, out1, out2}, {expected_next, expected_out1, expected_out2});
            end
        end
        $display("PASS: all 2048 binary state/input combinations");
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "FAIL: simulation timeout");
    end
endmodule
