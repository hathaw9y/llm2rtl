`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic w = 0;
    wire z;
    integer model_state = 0;
    bit initialized = 0;
    integer hits [0:5][0:1];
    integer reset_hits [0:5];
    integer seq, n, s, b;
    TopModule dut (.clk(clk), .reset(reset), .w(w), .z(z));
    always #5 clk = ~clk;

    // Independent oracle: row numbers correspond to A,B,C,D,E,F.
    function automatic integer transition(input integer row, input bit value);
        case (row)
            0: transition = value ? 1 : 0;
            1: transition = value ? 2 : 3;
            2: transition = value ? 4 : 3;
            3: transition = value ? 5 : 0;
            4: transition = value ? 4 : 3;
            5: transition = value ? 2 : 3;
            default: $fatal(1, "Invalid oracle state");
        endcase
    endfunction

    task automatic check_output;
        bit expected_z;
        begin
            expected_z = (model_state == 4 || model_state == 5);
            if (z !== expected_z)
                $fatal(1, "Output mismatch at %0t: state=%0d expected=%b actual=%b", $time, model_state, expected_z, z);
        end
    endtask

    task automatic cycle(input bit value, input bit rst);
        begin
            @(negedge clk);
            w = value;
            reset = rst;
            #1;
            // Neither input changes nor reset assertion may change the Moore
            // output before the rising clock edge.
            if (initialized) check_output();
            @(posedge clk);
            if (rst) begin
                if (initialized) reset_hits[model_state] = reset_hits[model_state] + 1;
                model_state = 0;
            end else begin
                hits[model_state][value] = hits[model_state][value] + 1;
                model_state = transition(model_state, value);
            end
            initialized = 1;
            #1;
            check_output();
        end
    endtask

    initial begin
        for (s = 0; s < 6; s = s + 1) begin
            reset_hits[s] = 0;
            for (b = 0; b < 2; b = b + 1) hits[s][b] = 0;
        end
        cycle(1, 1);
        cycle(0, 1);
        for (seq = 0; seq < 1024; seq = seq + 1) begin
            cycle(1, 1);
            for (n = 0; n < 10; n = n + 1)
                cycle((seq >> n) & 1, 0);
        end
        cycle(0, 1);
        for (s = 0; s < 6; s = s + 1) begin
            if (reset_hits[s] == 0) $fatal(1, "Missing reset coverage for state %0d", s);
            for (b = 0; b < 2; b = b + 1)
                if (hits[s][b] == 0) $fatal(1, "Missing transition coverage state=%0d input=%0d", s, b);
        end
        $display("PASS: exhaustive sequences, all transitions, reset from all states, and edge sampling");
        $finish;
    end

    initial begin
        #200000;
        $fatal(1, "Timeout");
    end
endmodule
