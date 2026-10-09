`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    reg in = 0;
    wire out;
    integer expected_state;
    integer checks = 0;
    integer seq, bit_index, target;
    integer transition_hits [0:3][0:1];
    integer s, b;
    TopModule dut (.clk(clk), .reset(reset), .in(in), .out(out));
    always #5 clk = ~clk;

    function integer next_ref(input integer old_state, input bit value);
        // Literal original table, independent of the DUT's enum encoding.
        case (old_state)
            0: next_ref = value ? 1 : 0;
            1: next_ref = value ? 1 : 2;
            2: next_ref = value ? 3 : 0;
            3: next_ref = value ? 1 : 2;
            default: begin $fatal(1, "Invalid oracle state"); next_ref = 0; end
        endcase
    endfunction

    task check_output;
        begin
            if (out !== (expected_state == 3))
                $fatal(1, "Output mismatch at %0t state=%0d out=%b", $time, expected_state, out);
            checks = checks + 1;
        end
    endtask

    task step(input bit rst_value, input bit input_value);
        begin
            @(negedge clk);
            reset = rst_value;
            in = input_value;
            #1;
            check_output(); // Neither reset nor input may asynchronously change output.
            @(posedge clk);
            if (rst_value) expected_state = 0;
            else begin
                transition_hits[expected_state][input_value] =
                    transition_hits[expected_state][input_value] + 1;
                expected_state = next_ref(expected_state, input_value);
            end
            #1;
            check_output();
        end
    endtask

    initial begin
        for (s = 0; s < 4; s = s + 1)
            for (b = 0; b < 2; b = b + 1) transition_hits[s][b] = 0;
        // No assertion about unspecified pre-reset output.
        reset = 1;
        @(posedge clk);
        expected_state = 0;
        #1;
        check_output();
        for (seq = 0; seq < 256; seq = seq + 1) begin
            step(1, seq[0]);
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
                step(0, (seq >> bit_index) & 1);
        end
        // Reach and reset each state, including reset while output is high.
        for (target = 0; target < 4; target = target + 1) begin
            step(1, 0);
            if (target >= 1) step(0, 1);
            if (target >= 2) step(0, 0);
            if (target >= 3) step(0, 1);
            if (expected_state != target) $fatal(1, "Directed reach failed");
            step(1, 1);
            step(1, 0);
        end
        // Reset pulse entirely between positive edges must not reset D.
        step(0, 1);
        step(0, 0);
        step(0, 1);
        @(negedge clk);
        reset = 1;
        in = 0;
        #1; check_output();
        reset = 0;
        in = 1;
        #1; check_output();
        in = 0;
        #1; check_output();
        @(posedge clk);
        expected_state = next_ref(expected_state, 0);
        #1; check_output();
        for (s = 0; s < 4; s = s + 1)
            for (b = 0; b < 2; b = b + 1)
                if (transition_hits[s][b] == 0) $fatal(1, "Missing transition %0d,%0d", s,b);
        $display("PASS: exhaustive sequences, all transitions, synchronous reset and Moore output; %0d comparisons", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Timeout");
    end
endmodule
