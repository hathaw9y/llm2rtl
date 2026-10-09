`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    reg in = 0;
    wire out;
    integer model;
    integer checks = 0;
    reg established = 0;
    integer s, b, r, pattern, k;
    integer coverage [0:7];

    TopModule dut(.clk(clk), .reset(reset), .in(in), .out(out));

    // Table entries follow the original A/B/C/D transition table.
    function integer transition(input integer old_state, input reg bit_in);
        begin
            case (2*old_state + bit_in)
                0: transition = 0;
                1: transition = 1;
                2: transition = 2;
                3: transition = 1;
                4: transition = 0;
                5: transition = 3;
                6: transition = 2;
                7: transition = 1;
                default: $fatal(1, "Invalid oracle state");
            endcase
        end
    endfunction

    task check_output;
        reg expected_out;
        begin
            expected_out = (model == 3);
            if (out !== expected_out)
                $fatal(1, "Output mismatch: state=%0d expected=%b actual=%b time=%0t", model, expected_out, out, $time);
            checks = checks + 1;
        end
    endtask

    task cycle(input reg rst, input reg bit_in);
        begin
            // Drive during low phase, then verify synchronous/Moore behavior.
            clk = 0;
            reset = rst;
            in = bit_in;
            #2;
            if (established) check_output();
            if (rst) model = 0;
            else begin
                coverage[2*model + bit_in] = coverage[2*model + bit_in] + 1;
                model = transition(model, bit_in);
            end
            clk = 1;
            #1;
            established = 1;
            check_output();
            #1;
            clk = 0;
            #1;
            check_output();
        end
    endtask

    task reach(input integer target_state);
        begin
            cycle(1, 0);
            if (target_state >= 1) cycle(0, 1); // A -> B
            if (target_state >= 2) cycle(0, 0); // B -> C
            if (target_state >= 3) cycle(0, 1); // C -> D
            if (model != target_state) $fatal(1, "Directed setup failure");
        end
    endtask

    initial begin
        for (k = 0; k < 8; k = k + 1) coverage[k] = 0;
        cycle(1, 1);
        for (s = 0; s < 4; s = s + 1) begin
            for (b = 0; b < 2; b = b + 1) begin
                reach(s);
                cycle(0, b != 0);
            end
            for (r = 0; r < 2; r = r + 1) begin
                reach(s);
                cycle(1, r != 0);
                cycle(1, r == 0); // Repeated reset remains A.
                cycle(0, 1);
            end
        end
        for (pattern = 0; pattern < 256; pattern = pattern + 1) begin
            cycle(1, 0);
            for (k = 7; k >= 0; k = k - 1)
                cycle(0, ((pattern >> k) & 1) != 0);
        end
        for (k = 0; k < 8; k = k + 1)
            if (coverage[k] == 0) $fatal(1, "Missing transition coverage %0d", k);
        $display("PASS: all transitions, synchronous resets, Moore output, and 256 input sequences; %0d output checks", checks);
        $finish;
    end

    initial begin
        #20000;
        $fatal(1, "Bounded timeout");
    end
endmodule
