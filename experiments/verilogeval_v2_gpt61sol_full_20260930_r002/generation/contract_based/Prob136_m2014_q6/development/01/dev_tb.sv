`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic w = 0;
    wire z;
    integer model;
    integer transition_hits [0:5][0:1];
    integer reset_hits [0:5];
    integer seq, bit_idx, s, b;
    logic expected_z;
    TopModule dut (.clk(clk), .reset(reset), .w(w), .z(z));
    always #5 clk = ~clk;

    // Independently encoded original state graph: 0=A through 5=F.
    function automatic integer successor(input integer old_state, input bit input_w);
        case (old_state)
            0: successor = input_w ? 0 : 1;
            1: successor = input_w ? 3 : 2;
            2: successor = input_w ? 3 : 4;
            3: successor = input_w ? 0 : 5;
            4: successor = input_w ? 3 : 4;
            5: successor = input_w ? 3 : 2;
            default: $fatal(1, "Invalid oracle state");
        endcase
    endfunction

    task automatic compare_output;
        begin
            expected_z = (model == 4 || model == 5);
            if (z !== expected_z)
                $fatal(1, "Output mismatch t=%0t model=%0d w=%b reset=%b expected=%b actual=%b",
                       $time, model, w, reset, expected_z, z);
        end
    endtask

    task automatic step(input bit input_w, input bit input_reset);
        begin
            @(negedge clk);
            w = input_w;
            reset = input_reset;
            #1;
            // Neither changing w nor asserting reset between edges changes z.
            compare_output();
            if (input_reset) begin
                reset_hits[model] = reset_hits[model] + 1;
                model = 0;
            end else begin
                transition_hits[model][input_w] = transition_hits[model][input_w] + 1;
                model = successor(model, input_w);
            end
            @(posedge clk);
            #1;
            compare_output();
        end
    endtask

    initial begin
        for (s = 0; s < 6; s = s + 1) begin
            reset_hits[s] = 0;
            for (b = 0; b < 2; b = b + 1) transition_hits[s][b] = 0;
        end
        // No pre-reset comparison: original has no power-up-state requirement.
        reset = 1;
        @(posedge clk);
        #1;
        model = 0;
        compare_output();
        // Exhaustive length-eight input strings cover all graph transitions.
        // Reset from every reached endpoint, with alternating w during reset.
        for (seq = 0; seq < 256; seq = seq + 1) begin
            step(seq % 2, 1);
            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1)
                step((seq >> bit_idx) & 1, 0);
        end
        step(1, 1);
        step(0, 1);
        for (s = 0; s < 6; s = s + 1) begin
            if (reset_hits[s] == 0) $fatal(1, "Missing reset coverage for state %0d", s);
            for (b = 0; b < 2; b = b + 1)
                if (transition_hits[s][b] == 0)
                    $fatal(1, "Missing transition coverage state=%0d w=%0d", s, b);
        end
        $display("PASS exhaustive sequences, all transitions, synchronous reset, Moore output");
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "Timeout");
    end
endmodule
