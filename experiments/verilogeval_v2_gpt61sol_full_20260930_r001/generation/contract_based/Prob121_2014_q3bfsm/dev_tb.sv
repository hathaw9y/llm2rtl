`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic x = 0;
    wire z;
    integer model_state = 0;
    integer transitions [0:4][0:1];
    integer resets [0:4][0:1];
    integer checks = 0;
    integer seq_id, step_id, a, b;
    TopModule dut (.clk(clk), .reset(reset), .x(x), .z(z));

    function automatic integer advance(input integer s, input bit v);
        case (s)
            0: advance = v ? 1 : 0;
            1: advance = v ? 4 : 1;
            2: advance = v ? 1 : 2;
            3: advance = v ? 2 : 1;
            4: advance = v ? 4 : 3;
            default: $fatal(1, "Oracle entered illegal state");
        endcase
    endfunction

    task automatic check_output;
        bit expected_z;
        begin
            expected_z = (model_state == 3 || model_state == 4);
            checks = checks + 1;
            if (z !== expected_z)
                $fatal(1, "Output mismatch: state=%0d x=%b reset=%b z=%b expected=%b", model_state, x, reset, z, expected_z);
        end
    endtask

    task automatic cycle(input bit r, input bit v);
        begin
            clk = 0;
            reset = r;
            x = v;
            #2;
            check_output(); // Neither input nor reset changes state off edge.
            if (r) begin
                resets[model_state][v] = resets[model_state][v] + 1;
                model_state = 0;
            end else begin
                transitions[model_state][v] = transitions[model_state][v] + 1;
                model_state = advance(model_state, v);
            end
            clk = 1;
            #2;
            check_output();
            clk = 0;
            #1;
        end
    endtask

    initial begin
        #1000000;
        $fatal(1, "Testbench watchdog timeout");
    end

    initial begin
        for (a = 0; a < 5; a = a + 1)
            for (b = 0; b < 2; b = b + 1) begin
                transitions[a][b] = 0;
                resets[a][b] = 0;
            end
        reset = 1;
        #1;
        clk = 1;
        #1;
        check_output();
        clk = 0;
        for (seq_id = 0; seq_id < 1024; seq_id = seq_id + 1) begin
            cycle(1, 0);
            for (step_id = 0; step_id < 10; step_id = step_id + 1)
                cycle(0, (seq_id >> step_id) & 1);
            cycle(1, 0);
            for (step_id = 0; step_id < 10; step_id = step_id + 1)
                cycle(0, (seq_id >> step_id) & 1);
            cycle(1, 1);
        end
        for (a = 0; a < 5; a = a + 1)
            for (b = 0; b < 2; b = b + 1) begin
                if (transitions[a][b] == 0 || resets[a][b] == 0)
                    $fatal(1, "Missing coverage state=%0d x=%0d", a, b);
                $display("COVER state=%0d x=%0d transitions=%0d resets=%0d", a, b, transitions[a][b], resets[a][b]);
            end
        $display("PASS: exhaustive length-10 sequences, all legal transitions and reset pairs, %0d output checks", checks);
        $finish;
    end
endmodule
