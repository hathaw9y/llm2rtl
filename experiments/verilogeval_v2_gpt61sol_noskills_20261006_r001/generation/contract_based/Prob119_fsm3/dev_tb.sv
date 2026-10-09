`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg areset = 0;
    reg in = 0;
    wire out;
    integer reference_state;
    integer transitions [0:3][0:1];
    integer resets [0:3];
    integer sequence_id, bit_id, s, b;
    integer checks = 0;
    reg model_valid = 0;
    TopModule dut (.clk(clk), .areset(areset), .in(in), .out(out));

    task check_output;
        begin
            if (!model_valid) $fatal(1, "Oracle uninitialized");
            if (out !== (reference_state == 3))
                $fatal(1, "Output mismatch at %0t state=%0d out=%b", $time, reference_state, out);
            checks = checks + 1;
        end
    endtask

    task step(input reg value);
        integer old_state;
        begin
            clk = 0;
            in = value;
            #2;
            check_output();
            old_state = reference_state;
            transitions[old_state][value] = transitions[old_state][value] + 1;
            // Direct transcription of the original table using integer states.
            case (old_state)
                0: if (value == 0) reference_state = 0; else reference_state = 1;
                1: if (value == 0) reference_state = 2; else reference_state = 1;
                2: if (value == 0) reference_state = 0; else reference_state = 3;
                3: if (value == 0) reference_state = 2; else reference_state = 1;
                default: $fatal(1, "Bad oracle state");
            endcase
            clk = 1;
            #1;
            check_output();
            #1;
            clk = 0;
            #1;
            check_output();
        end
    endtask

    task reset_machine;
        begin
            clk = 0;
            areset = 0;
            #1;
            if (model_valid) resets[reference_state] = resets[reference_state] + 1;
            areset = 1;
            reference_state = 0;
            model_valid = 1;
            #1;
            check_output(); // No rising clock occurred: reset must be asynchronous.
            in = 1;
            #1;
            check_output();
            clk = 1;
            #1;
            check_output(); // Reset remains asserted at this rising clock edge.
            clk = 0;
            #1;
            areset = 0;
            #1;
            check_output(); // Deassertion does not clock a transition.
        end
    endtask

    initial begin
        for (s = 0; s < 4; s = s + 1) begin
            resets[s] = 0;
            for (b = 0; b < 2; b = b + 1) transitions[s][b] = 0;
        end
        reset_machine();
        for (sequence_id = 0; sequence_id < 256; sequence_id = sequence_id + 1) begin
            reset_machine();
            for (bit_id = 0; bit_id < 8; bit_id = bit_id + 1)
                step((sequence_id >> bit_id) & 1);
        end
        reset_machine();
        for (s = 0; s < 4; s = s + 1) begin
            if (resets[s] == 0) $fatal(1, "Missing reset coverage state %0d", s);
            for (b = 0; b < 2; b = b + 1)
                if (transitions[s][b] == 0) $fatal(1, "Missing transition coverage %0d/%0d", s, b);
        end
        $display("PASS exhaustive sequences, all transitions and reset states; %0d output checks", checks);
        $finish;
    end
    initial begin
        #20000;
        $fatal(1, "Bounded timeout expired");
    end
endmodule
