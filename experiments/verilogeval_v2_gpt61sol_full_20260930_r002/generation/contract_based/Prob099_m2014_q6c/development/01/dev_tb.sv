`timescale 1ns/1ps
module dev_tb;
    logic [5:0] y;
    logic w;
    wire Y1, Y3;
    integer state_idx, input_value, mask, bit_idx, dest, checks;
    logic [5:0] expected_next;
    TopModule dut (.y(y), .w(w), .Y1(Y1), .Y3(Y3));

    // Oracle directly enumerates the original transition table.
    function automatic integer destination(input integer state_number, input integer input_bit);
        case (state_number)
            0: if (input_bit == 0) destination = 1; else destination = 0;
            1: if (input_bit == 0) destination = 2; else destination = 3;
            2: if (input_bit == 0) destination = 4; else destination = 3;
            3: if (input_bit == 0) destination = 5; else destination = 0;
            4: if (input_bit == 0) destination = 4; else destination = 3;
            5: if (input_bit == 0) destination = 2; else destination = 3;
            default: destination = -1;
        endcase
    endfunction

    task automatic check_outputs(input logic expected_b, input logic expected_d);
        #1;
        if (Y1 !== expected_b || Y3 !== expected_d)
            $fatal(1, "Mismatch y=%b w=%b got=%b%b expected=%b%b",
                   y, w, Y1, Y3, expected_b, expected_d);
        checks = checks + 1;
    endtask

    initial begin
        checks = 0;
        // Includes externally supplied reset state A and every legal transition.
        for (state_idx = 0; state_idx < 6; state_idx = state_idx + 1) begin
            for (input_value = 0; input_value < 2; input_value = input_value + 1) begin
                y = 6'b000001 << state_idx;
                w = input_value == 1;
                dest = destination(state_idx, input_value);
                expected_next = 6'b000001 << dest;
                check_outputs(expected_next[1], expected_next[3]);
            end
        end
        // Additional gate-superposition coverage; not an illegal-state recovery claim.
        for (mask = 0; mask < 64; mask = mask + 1) begin
            for (input_value = 0; input_value < 2; input_value = input_value + 1) begin
                y = mask[5:0];
                w = input_value == 1;
                expected_next = 6'b000000;
                for (bit_idx = 0; bit_idx < 6; bit_idx = bit_idx + 1)
                    if (y[bit_idx]) begin
                        dest = destination(bit_idx, input_value);
                        expected_next[dest] = 1'b1;
                    end
                check_outputs(expected_next[1], expected_next[3]);
            end
        end
        $display("PASS: %0d combinational transition checks", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Development test timeout");
    end
endmodule
