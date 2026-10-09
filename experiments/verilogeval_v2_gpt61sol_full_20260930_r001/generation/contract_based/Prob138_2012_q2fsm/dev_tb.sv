`timescale 1ns/1ps
module dev_tb;
    logic clk = 0, reset = 0, w = 0;
    wire z;
    TopModule dut (.clk(clk), .reset(reset), .w(w), .z(z));
    integer model = 0;
    integer transitions [0:5][0:1];
    integer resets [0:5][0:1];
    integer seq, bitno, rst_w, s, b, checks = 0;
    bit initialized = 0;
    logic old_z;

    function automatic integer next_state(input integer current, input bit value);
        case (current)
            0: if (value) next_state = 1; else next_state = 0;
            1: if (value) next_state = 2; else next_state = 3;
            2: if (value) next_state = 4; else next_state = 3;
            3: if (value) next_state = 5; else next_state = 0;
            4: if (value) next_state = 4; else next_state = 3;
            5: if (value) next_state = 2; else next_state = 3;
            default: $fatal(1, "Invalid oracle state");
        endcase
    endfunction

    task automatic cycle(input bit r, input bit value);
        begin
            old_z = z;
            reset = r;
            w = value;
            #2;
            if (initialized && z !== old_z)
                $fatal(1, "Output changed between edges");
            if (r) begin
                if (initialized) resets[model][value] = resets[model][value] + 1;
                model = 0;
            end else begin
                transitions[model][value] = transitions[model][value] + 1;
                model = next_state(model, value);
            end
            clk = 1;
            #1;
            initialized = 1;
            checks = checks + 1;
            if (z !== ((model == 4) || (model == 5)))
                $fatal(1, "Mismatch sequence=%0d model=%0d z=%b", seq, model, z);
            clk = 0;
            #1;
        end
    endtask

    initial begin
        for (s = 0; s < 6; s = s + 1)
            for (b = 0; b < 2; b = b + 1) begin
                transitions[s][b] = 0;
                resets[s][b] = 0;
            end
        cycle(1, 0);
        for (rst_w = 0; rst_w < 2; rst_w = rst_w + 1)
            for (seq = 0; seq < 256; seq = seq + 1) begin
                cycle(1, 0);
                for (bitno = 0; bitno < 8; bitno = bitno + 1)
                    cycle(0, (seq >> bitno) & 1);
                cycle(1, rst_w);
            end
        for (s = 0; s < 6; s = s + 1)
            for (b = 0; b < 2; b = b + 1) begin
                if (transitions[s][b] == 0 || resets[s][b] == 0)
                    $fatal(1, "Missing coverage state=%0d w=%0d", s, b);
            end
        $display("PASS: %0d edge checks; all 12 transitions and all 12 state/reset-input combinations covered", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Testbench timeout");
    end
endmodule
