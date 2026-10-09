`timescale 1ns/1ps
module dev_tb;
    logic clk, a, b;
    wire q, state;
    integer checks = 0;
    integer s, pair_index;
    logic expected_q;
    TopModule dut (.clk(clk), .a(a), .b(b), .q(q), .state(state));
    task automatic check(input logic es, input logic eq);
        begin
            if (state !== es || q !== eq)
                $fatal(1, "At %0t expected state/q=%b/%b got %b/%b", $time, es, eq, state, q);
            checks = checks + 1;
        end
    endtask
    // Inputs change after edge sampling, still at the original integer timestamp.
    task automatic row(input logic ck, av, bv, es, eq);
        begin
            clk = ck;
            #0.001;
            a = av; b = bv;
            #0.001;
            check(es, eq);
        end
    endtask
    initial begin
        clk = 0; a = 1; b = 1'bx;
        #0.002;
        check(1'bx, 1'bx);
        #4.998; row(1'b1, 1'b1, 1'bx, 1'bx, 1'bx); // 5ns
        #4.998; row(1'b0, 1'b0, 1'b0, 1'bx, 1'bx); // 10ns
        #4.998; row(1'b1, 1'b0, 1'b0, 1'b0, 1'b0); // 15ns
        #4.998; row(1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // 20ns
        #4.998; row(1'b1, 1'b0, 1'b0, 1'b0, 1'b0); // 25ns
        #4.998; row(1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // 30ns
        #4.998; row(1'b1, 1'b0, 1'b0, 1'b0, 1'b0); // 35ns
        #4.998; row(1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // 40ns
        #4.998; row(1'b1, 1'b0, 1'b1, 1'b0, 1'b1); // 45ns
        #4.998; row(1'b0, 1'b0, 1'b1, 1'b0, 1'b1); // 50ns
        #4.998; row(1'b1, 1'b1, 1'b0, 1'b0, 1'b1); // 55ns
        #4.998; row(1'b0, 1'b1, 1'b0, 1'b0, 1'b1); // 60ns
        #4.998; row(1'b1, 1'b1, 1'b1, 1'b0, 1'b0); // 65ns
        #4.998; row(1'b0, 1'b1, 1'b1, 1'b0, 1'b0); // 70ns
        #4.998; row(1'b1, 1'b0, 1'b0, 1'b1, 1'b1); // 75ns
        #4.998; row(1'b0, 1'b0, 1'b0, 1'b1, 1'b1); // 80ns
        #4.998; row(1'b1, 1'b1, 1'b1, 1'b0, 1'b0); // 85ns
        #4.998; row(1'b0, 1'b1, 1'b1, 1'b0, 1'b0); // 90ns
        #4.998; row(1'b1, 1'b1, 1'b1, 1'b1, 1'b1); // 95ns
        #4.998; row(1'b0, 1'b1, 1'b1, 1'b1, 1'b1); // 100ns
        #4.998; row(1'b1, 1'b1, 1'b1, 1'b1, 1'b1); // 105ns
        #4.998; row(1'b0, 1'b1, 1'b1, 1'b1, 1'b1); // 110ns
        #4.998; row(1'b1, 1'b1, 1'b0, 1'b1, 1'b0); // 115ns
        #4.998; row(1'b0, 1'b1, 1'b0, 1'b1, 1'b0); // 120ns
        #4.998; row(1'b1, 1'b0, 1'b1, 1'b1, 1'b0); // 125ns
        #4.998; row(1'b0, 1'b0, 1'b1, 1'b1, 1'b0); // 130ns
        #4.998; row(1'b1, 1'b0, 1'b0, 1'b1, 1'b1); // 135ns
        #4.998; row(1'b0, 1'b0, 1'b0, 1'b1, 1'b1); // 140ns
        #4.998; row(1'b1, 1'b0, 1'b0, 1'b0, 1'b0); // 145ns
        #4.998; row(1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // 150ns
        #4.998; row(1'b1, 1'b0, 1'b0, 1'b0, 1'b0); // 155ns
        #4.998; row(1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // 160ns
        #4.998; row(1'b1, 1'b0, 1'b0, 1'b0, 1'b0); // 165ns
        #4.998; row(1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // 170ns
        #4.998; row(1'b1, 1'b0, 1'b0, 1'b0, 1'b0); // 175ns
        #4.998; row(1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // 180ns
        #4.998; row(1'b1, 1'b0, 1'b0, 1'b0, 1'b0); // 185ns
        #4.998; row(1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // 190ns
        // Establish each state via an input held well before a rising edge.
        // Then check all input pairs while clock is low, proving combinational q
        // and state hold independently of the literal waveform replay.
        for (s = 0; s < 2; s = s + 1) begin
            clk = 0; a = s[0]; b = s[0];
            #2; clk = 1;
            #0.002; check(s[0], s[0]);
            #2; clk = 0;
            for (pair_index = 0; pair_index < 4; pair_index = pair_index + 1) begin
                a = pair_index[1]; b = pair_index[0];
                case (pair_index)
                    0, 3: expected_q = s[0];
                    1, 2: expected_q = ~s[0];
                endcase
                #1; check(s[0], expected_q);
            end
        end
        // Check every binary next-state input combination, stable before edge.
        for (pair_index = 0; pair_index < 4; pair_index = pair_index + 1) begin
            clk = 0; a = pair_index[1]; b = pair_index[0];
            #2; clk = 1;
            #0.002;
            case (pair_index)
                0: check(0, 0);
                1, 2: check(0, 1);
                3: check(1, 1);
            endcase
            #2; clk = 0;
        end
        $display("PASS original waveform and directed checks (%0d checks)", checks);
        $finish;
    end
    initial begin
        #500;
        $fatal(1, "Timeout");
    end
endmodule
