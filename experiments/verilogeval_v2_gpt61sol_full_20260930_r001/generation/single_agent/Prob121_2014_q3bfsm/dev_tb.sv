`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic x = 0;
    wire z;
    integer expected_state = 0;
    integer coverage [0:4][0:1];
    integer sequence_id, bit_id, s, b;
    integer steps = 0;
    TopModule dut (.clk(clk), .reset(reset), .x(x), .z(z));
    always #5 clk = ~clk;

    function automatic integer next_state(input integer current, input bit input_x);
        case (current)
            0: next_state = input_x ? 1 : 0;
            1: next_state = input_x ? 4 : 1;
            2: next_state = input_x ? 1 : 2;
            3: next_state = input_x ? 2 : 1;
            4: next_state = input_x ? 4 : 3;
            default: next_state = 0;
        endcase
    endfunction

    task automatic check_output;
        if (z !== ((expected_state == 3) || (expected_state == 4)))
            $fatal(1, "Output mismatch: step=%0d state=%0d z=%b", steps, expected_state, z);
    endtask

    task automatic step(input bit reset_value, input bit x_value);
        @(negedge clk);
        reset = reset_value;
        x = x_value;
        #1;
        if (steps != 0) check_output();
        @(posedge clk);
        if (reset_value) expected_state = 0;
        else begin
            coverage[expected_state][x_value] = coverage[expected_state][x_value] + 1;
            expected_state = next_state(expected_state, x_value);
        end
        #1;
        steps = steps + 1;
        check_output();
    endtask

    initial begin
        for (s = 0; s < 5; s = s + 1)
            for (b = 0; b < 2; b = b + 1) coverage[s][b] = 0;
        step(1, 0);
        step(0, 1);
        step(0, 1);
        step(1, 1); // Reset from a state with z=1; check no change before edge.
        step(1, 0);
        for (sequence_id = 0; sequence_id < 1024; sequence_id = sequence_id + 1) begin
            step(1, sequence_id[0]);
            for (bit_id = 0; bit_id < 10; bit_id = bit_id + 1)
                step(0, (sequence_id >> bit_id) & 1);
        end
        for (s = 0; s < 5; s = s + 1)
            for (b = 0; b < 2; b = b + 1)
                if (coverage[s][b] == 0) $fatal(1, "Missing transition state=%0d x=%0d", s, b);
        $display("PASS: %0d cycles, all 10 transitions, synchronous reset and Moore output", steps);
        $finish;
    end
    initial begin
        #200000;
        $fatal(1, "Testbench timeout");
    end
endmodule
