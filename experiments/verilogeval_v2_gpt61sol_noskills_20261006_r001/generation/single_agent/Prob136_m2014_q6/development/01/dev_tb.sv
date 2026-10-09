`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    reg w = 0;
    wire z;
    integer expected_state;
    integer sequence_id, bit_id;
    integer coverage [0:5][0:1];
    integer i, j;
    reg expected_z;
    TopModule dut (.clk(clk), .reset(reset), .w(w), .z(z));
    always #5 clk = ~clk;

    // Independent transition table: row is current state, column is w.
    function integer transition(input integer s, input reg value);
        begin
            case (s)
                0: if (value) transition = 0; else transition = 1;
                1: if (value) transition = 3; else transition = 2;
                2: if (value) transition = 3; else transition = 4;
                3: if (value) transition = 0; else transition = 5;
                4: if (value) transition = 3; else transition = 4;
                5: if (value) transition = 3; else transition = 2;
                default: $fatal(1, "Invalid oracle state");
            endcase
        end
    endfunction

    task check_output;
        begin
            expected_z = (expected_state == 4 || expected_state == 5);
            if (z !== expected_z)
                $fatal(1, "z mismatch at %0t: state=%0d expected=%b actual=%b", $time, expected_state, expected_z, z);
        end
    endtask

    task step(input reg r, input reg value);
        begin
            @(negedge clk);
            reset = r;
            w = value;
            #1;
            check_output(); // Input changes must not change the Moore output.
            @(posedge clk);
            if (r) expected_state = 0;
            else begin
                coverage[expected_state][value] = coverage[expected_state][value] + 1;
                expected_state = transition(expected_state, value);
            end
            #1;
            check_output();
        end
    endtask

    initial begin
        for (i = 0; i < 6; i = i + 1)
            for (j = 0; j < 2; j = j + 1) coverage[i][j] = 0;
        // Establish state with a synchronous reset before checking outputs.
        reset = 1;
        @(posedge clk);
        expected_state = 0;
        #1;
        check_output();
        // Exhaustive nine-bit input sequences exercise every transition and
        // repeated runs, with reset asserted from all reachable states.
        for (sequence_id = 0; sequence_id < 512; sequence_id = sequence_id + 1) begin
            step(1, sequence_id[0]);
            for (bit_id = 0; bit_id < 9; bit_id = bit_id + 1)
                step(0, (sequence_id >> bit_id) & 1);
        end
        step(1, 1);
        step(1, 0);
        for (i = 0; i < 6; i = i + 1)
            for (j = 0; j < 2; j = j + 1)
                if (coverage[i][j] == 0) $fatal(1, "Missing transition %0d/%0d", i, j);
        $display("PASS: exhaustive sequences, all transitions, synchronous reset and Moore output timing");
        $finish;
    end

    initial begin
        #60000;
        $fatal(1, "Timeout");
    end
endmodule
